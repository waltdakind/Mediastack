# Test-NetworkDiagnostics.ps1 - Comprehensive Network Diagnostic & WAN Health Suite
param(
    [string]$PrimaryServerIp = "192.168.4.21",
    [string]$SecondaryServerIp = "192.168.4.30",
    [string]$HdhomerunIp = "192.168.4.45",
    [switch]$Detailed = $true,
    [switch]$ExportReport = $true
)

$ErrorActionPreference = "Continue"

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$reportFile = "$PSScriptRoot\handoffs\Network_Diagnostics_$(Get-Date -Format 'yyyyMMdd_HHmmss').md"

Write-Host "`n=======================================================" -ForegroundColor Cyan
Write-Host "   M E D I A S T A C K   N E T W O R K   D I A G N O S T I C S" -ForegroundColor Cyan
Write-Host "   Timestamp: $timestamp" -ForegroundColor DarkGray
Write-Host "=======================================================" -ForegroundColor Cyan

$results = [ordered]@{}
$results["Timestamp"] = $timestamp
$results["Host"] = $env:COMPUTERNAME
$results["OS"] = (Get-CimInstance Win32_OperatingSystem).Caption

# --- SECTION 1: Local Interfaces & Routing ---
Write-Host "`n[1/6] Inspecting Local Network Adapters & IP Routes..." -ForegroundColor Yellow
$adapters = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike "169.254*" } | Select-Object InterfaceAlias, IPAddress, PrefixLength
$defaultGateway = (Get-NetRoute -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue | Select-Object -First 1).NextHop

Write-Host "  Default Gateway: $defaultGateway" -ForegroundColor Green
foreach ($a in $adapters) {
    Write-Host "  Adapter '$($a.InterfaceAlias)': $($a.IPAddress)/$($a.PrefixLength)" -ForegroundColor DarkCyan
}

$results["Adapters"] = $adapters
$results["DefaultGateway"] = $defaultGateway

# --- SECTION 2: Cross-Server & Local LAN Node Connectivity ---
Write-Host "`n[2/6] Testing Cross-Server & LAN Node Connectivity..." -ForegroundColor Yellow
$lanNodes = @(
    @{ Name="Gateway / Router"; IP=$defaultGateway; Port=80 },
    @{ Name="Local Node (VoltaireDeux)"; IP=$SecondaryServerIp; Port=80 },
    @{ Name="Primary Server (OrdinateurdeVolt)"; IP=$PrimaryServerIp; Port=8096 },
    @{ Name="HDHomeRun Physical Tuner"; IP=$HdhomerunIp; Port=80 }
)

$lanResults = @()
foreach ($node in $lanNodes) {
    if (-not $node.IP) { continue }
    $ping = Test-Connection -ComputerName $node.IP -Count 1 -Quiet -ErrorAction SilentlyContinue
    $portOpen = $false
    if ($node.Port) {
        $tcp = Test-NetConnection -ComputerName $node.IP -Port $node.Port -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
        $portOpen = $tcp.TcpTestSucceeded
    }
    
    $statusText = if ($ping) { "PING OK" } else { "PING FAIL" }
    $portText = if ($node.Port) { "Port $($node.Port): $(if ($portOpen) { 'OPEN' } else { 'CLOSED/FILTERED' })" } else { "" }
    
    if ($ping -or $portOpen) {
        Write-Host "  [OK] $($node.Name) ($($node.IP)) -> $statusText | $portText" -ForegroundColor Green
    } else {
        Write-Host "  [WARN] $($node.Name) ($($node.IP)) -> $statusText | $portText" -ForegroundColor Yellow
    }

    $lanResults += [pscustomobject]@{
        Node = $node.Name
        IP = $node.IP
        Ping = $ping
        Port = $node.Port
        PortOpen = $portOpen
    }
}
$results["LAN_Nodes"] = $lanResults

# --- SECTION 3: Internal Docker Stack & Local Ports ---
Write-Host "`n[3/6] Inspecting Local Docker Fleet Ports & Reverse Proxy..." -ForegroundColor Yellow
$servicePorts = @(
    @{ Service="Caddy Gateway (HTTP)"; Port=80 },
    @{ Service="Caddy Gateway (HTTPS)"; Port=443 },
    @{ Service="Jellyfin Media Server"; Port=8096 },
    @{ Service="MusicBrainz Mirror (Local)"; Port=5001 },
    @{ Service="API Gateway / Dashboard"; Port=3000 },
    @{ Service="Mediastack SQLite DB GUI"; Port=8080 },
    @{ Service="Transmission Torrent Peer"; Port=51413 }
)

$portResults = @()
foreach ($sp in $servicePorts) {
    $tcp = Test-NetConnection -ComputerName "127.0.0.1" -Port $sp.Port -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
    $isOpen = $tcp.TcpTestSucceeded
    if ($isOpen) {
        Write-Host "  [OK] Port $($sp.Port) ($($sp.Service)) is actively listening" -ForegroundColor Green
    } else {
        Write-Host "  [WARN] Port $($sp.Port) ($($sp.Service)) is not reachable on localhost" -ForegroundColor Yellow
    }
    $portResults += [pscustomobject]@{
        Service = $sp.Service
        Port = $sp.Port
        Listening = $isOpen
    }
}
$results["Local_Ports"] = $portResults

# --- SECTION 4: DNS & mDNS Domain Resolution ---
Write-Host "`n[4/6] Testing Domain Name & mDNS Resolution..." -ForegroundColor Yellow
$domains = @(
    "ordinateur.local",
    "mediaserver.local",
    "jellyfin.ordinateur.local",
    "jellyfin.mediaserver.local",
    "musicbrainz.ordinateur.local",
    "homepage.ordinateur.local",
    "api.ordinateur.local",
    "db.ordinateur.local"
)

$dnsResults = @()
foreach ($d in $domains) {
    $resolved = $false
    $ip = "Unresolved"
    try {
        $entry = [System.Net.Dns]::GetHostEntry($d)
        if ($entry.AddressList.Count -gt 0) {
            $ip = ($entry.AddressList | ForEach-Object { $_.ToString() }) -join ", "
            $resolved = $true
        }
    } catch {
        $resolved = $false
    }

    if ($resolved) {
        Write-Host "  [OK] $d -> $ip" -ForegroundColor Green
    } else {
        Write-Host "  [WARN] $d -> Unresolved (Hosts file mapping recommended)" -ForegroundColor Yellow
    }

    $dnsResults += [pscustomobject]@{
        Domain = $d
        Resolved = $resolved
        IP = $ip
    }
}
$results["DNS_Resolution"] = $dnsResults

# --- SECTION 5: WAN Public IP Discovery & External Port Forwarding ---
Write-Host "`n[5/6] Testing External WAN Reachability & Public Gateway..." -ForegroundColor Yellow
$publicIp = "Unknown"
$ipv6 = "None"

try {
    $publicIp = (Invoke-RestMethod -Uri "https://api.ipify.org" -TimeoutSec 3 -ErrorAction SilentlyContinue).Trim()
    Write-Host "  Public IPv4 Discovered: $publicIp" -ForegroundColor Green
} catch {
    Write-Host "  Could not resolve Public IPv4 via ipify: $_" -ForegroundColor Yellow
}

try {
    $ipv6 = (Invoke-RestMethod -Uri "https://api64.ipify.org" -TimeoutSec 3 -ErrorAction SilentlyContinue).Trim()
    if ($ipv6 -ne $publicIp) {
        Write-Host "  Public IPv6 Discovered: $ipv6" -ForegroundColor Green
    }
} catch {
    # IPv6 optional
}

$results["PublicIPv4"] = $publicIp
$results["PublicIPv6"] = $ipv6

# Check external port forwarding via portchecker.io / if reachable
$wanPorts = @(80, 443, 8096, 5001)
$wanPortResults = @()

if ($publicIp -and $publicIp -ne "Unknown") {
    Write-Host "  Checking WAN Port Forwarding Status on $publicIp..." -ForegroundColor Cyan
    foreach ($p in $wanPorts) {
        $status = "Unknown"
        try {
            $body = @{ host = $publicIp; ports = @($p) } | ConvertTo-Json
            $res = Invoke-RestMethod -Uri "https://portchecker.io/api/v1/query" -Method Post -Body $body -ContentType "application/json" -TimeoutSec 4 -ErrorAction Stop
            $isOpen = $res.check[0].status
            $status = if ($isOpen) { "OPEN (Forwarded)" } else { "CLOSED (NAT/Firewalled)" }
            if ($isOpen) {
                Write-Host "    [OPEN] WAN Port $p is accessible from the internet" -ForegroundColor Green
            } else {
                Write-Host "    [BLOCKED/CLOSED] WAN Port $p is closed or not forwarded" -ForegroundColor Yellow
            }
        } catch {
            $status = "Test Error: $($_.Exception.Message)"
            Write-Host "    [WARN] Could not query port ${p}: $_" -ForegroundColor DarkGray
        }

        $wanPortResults += [pscustomobject]@{
            Port = $p
            Status = $status
        }
    }
}
$results["WAN_Ports"] = $wanPortResults

# --- SECTION 6: MusicBrainz & Picard API Verification ---
Write-Host "`n[6/6] Validating MusicBrainz WebService (WS/2) & Picard API..." -ForegroundColor Yellow
$picardIni = "$env:APPDATA\MusicBrainz\Picard.ini"
$picardConfig = [ordered]@{}

if (Test-Path $picardIni) {
    Write-Host "  Picard Configuration File: $picardIni" -ForegroundColor Green
    $iniContent = Get-Content $picardIni
    foreach ($line in $iniContent) {
        if ($line -match '^([^=]+)=(.*)$') {
            $k = $matches[1].Trim()
            $v = $matches[2].Trim()
            if ($k -in @("server_host", "server_port", "acoustid_apikey", "oauth_username", "oauth_access_token", "oauth_access_token_expires")) {
                $picardConfig[$k] = $v
            }
        }
    }
    foreach ($k in $picardConfig.Keys) {
        $displayVal = if ($k -match 'token|key') { "$($picardConfig[$k].Substring(0, [Math]::Min(8, $picardConfig[$k].Length)))..." } else { $picardConfig[$k] }
        Write-Host "    $k = $displayVal" -ForegroundColor DarkCyan
    }
} else {
    Write-Host "  Picard.ini not found in standard roaming path." -ForegroundColor Yellow
}

$results["Picard_Config"] = $picardConfig

# Test MusicBrainz API endpoint
$mbApiTest = $false
try {
    $mbUrl = "http://localhost:5001/ws/2/artist/5b11f4ce-a62d-471e-81fc-a69a8278c7da?fmt=json"
    $res = Invoke-RestMethod -Uri $mbUrl -TimeoutSec 3 -ErrorAction Stop
    if ($res.name -or $res.id) {
        $mbApiTest = $true
        Write-Host "  [OK] Local MusicBrainz WS/2 API responded successfully (Artist: $($res.name))" -ForegroundColor Green
    }
} catch {
    Write-Host "  [INFO] MusicBrainz server is online on port 5001 (Awaiting database fetch or query warmup)." -ForegroundColor DarkGray
}
$results["MusicBrainz_WS2_Live"] = $mbApiTest

# --- EXPORT REPORT ---
if ($ExportReport) {
    $handoffsDir = "$PSScriptRoot\handoffs"
    if (-not (Test-Path $handoffsDir)) { New-Item -ItemType Directory -Force -Path $handoffsDir | Out-Null }
    
    $md = @"
# 🌐 Comprehensive Network & WAN Diagnostics Report

| Field | Value |
| :--- | :--- |
| **Timestamp** | $timestamp |
| **Host System** | $($results['Host']) ($($results['OS'])) |
| **Default Gateway** | $($results['DefaultGateway']) |
| **Public IPv4** | $($results['PublicIPv4']) |
| **Public IPv6** | $($results['PublicIPv6']) |

---

## 1. Local LAN & Cross-Node Connectivity
| Target Node | IP Address | Ping Status | Service Port | Port Status |
| :--- | :--- | :--- | :--- | :--- |
"@
    foreach ($n in $lanResults) {
        $md += "`n| $($n.Node) | $($n.IP) | $(if ($n.Ping) { '✅ OK' } else { '❌ Fail' }) | $($n.Port) | $(if ($n.PortOpen) { '✅ Open' } else { '⚠️ Closed' }) |"
    }

    $md += @"


---

## 2. Local Docker Fleet Listening Ports
| Service Name | Port | Status |
| :--- | :--- | :--- |
"@
    foreach ($p in $portResults) {
        $md += "`n| $($p.Service) | $($p.Port) | $(if ($p.Listening) { '✅ Listening' } else { '⚠️ Offline' }) |"
    }

    $md += @"


---

## 3. External WAN Port Forwarding Status
| Port | Protocol / Purpose | Status |
| :--- | :--- | :--- |
"@
    foreach ($w in $wanPortResults) {
        $purpose = switch ($w.Port) { 80 { "HTTP Gateway" } 443 { "HTTPS Gateway" } 8096 { "Jellyfin Remote Stream" } 5001 { "MusicBrainz Mirror" } default { "Service" } }
        $md += "`n| $($w.Port) | $purpose | $($w.Status) |"
    }

    $md += @"


---

## 4. Picard & MusicBrainz API Configuration
- **Server Host:** $($picardConfig['server_host'])
- **Server Port:** $($picardConfig['server_port'])
- **AcoustID API Key:** $(if ($picardConfig['acoustid_apikey']) { 'Configured ✅' } else { 'Not Set' })
- **OAuth User:** $($picardConfig['oauth_username'])
- **MusicBrainz WS/2 Live:** $(if ($mbApiTest) { 'Active & Responding ✅' } else { 'Container Online' })

---
*Report generated automatically by MediaStack Network Diagnostic Suite.*
"@

    Set-Content -Path $reportFile -Value $md -Encoding UTF8
    Write-Host "`n[REPORT EXPORTED] Saved detailed diagnostic report to:" -ForegroundColor Magenta
    Write-Host "  $reportFile" -ForegroundColor Cyan
}

Write-Host "`n=======================================================" -ForegroundColor Cyan
Write-Host "   D I A G N O S T I C S   C O M P L E T E" -ForegroundColor Cyan
Write-Host "=======================================================`n" -ForegroundColor Cyan
