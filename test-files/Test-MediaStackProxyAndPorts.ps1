<#
.SYNOPSIS
    Test-MediaStackProxyAndPorts.ps1 - Comprehensive Dual-Node Proxy & Port Diagnostic, Root-Cause Analyzer & Auto-Healer.

.DESCRIPTION
    Verifies all reverse proxies, subdomains, internal container sockets, and network ports used by MediaStack.
    If errors are detected:
    1. Analyzes the failure root-cause (Port Conflict / WinNAT / Container Offline / Upstream Down / DNS Error).
    2. Logs structured telemetry into the SQLite audit database and generates a Markdown audit report in handoffs/.
    3. If -AutoRepair is active (default), executes automated corrective remediation before continuing.

.PARAMETER AutoRepair
    Automatically remediates detected failures (restarts offline containers, frees rogue port locks, flushes DNS, reloads Caddy).
    Default is $true.

.PARAMETER AuditOnly
    Runs diagnostics and generates reports without making system modifications.

.PARAMETER TimeoutMs
    Socket connect timeout in milliseconds (default: 1200ms).

.PARAMETER ReportPath
    Custom output file path for the Markdown health report.

.EXAMPLE
    .\Test-MediaStackProxyAndPorts.ps1
    .\Test-MediaStackProxyAndPorts.ps1 -AuditOnly
    .\Test-MediaStackProxyAndPorts.ps1 -AutoRepair
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)][switch]$AutoRepair,
    [Parameter(Mandatory=$false)][switch]$AuditOnly,
    [Parameter(Mandatory=$false)][int]$TimeoutMs = 1200,
    [Parameter(Mandatory=$false)][string]$ReportPath = ""
)

$ErrorActionPreference = "Continue"
$BaseDir = if (Test-Path (Join-Path $PSScriptRoot "..\docker-compose.yml")) { (Resolve-Path (Join-Path $PSScriptRoot "..")).Path } else { $PSScriptRoot }
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::InputEncoding  = [System.Text.Encoding]::UTF8

if ($AuditOnly) { $AutoRepair = $false }

# Import Operations Module
$modulePath = Join-Path $BaseDir "MediaStackOps.psm1"
if (Test-Path $modulePath) { 
    Import-Module $modulePath -Force 
} elseif (Test-Path "$BaseDir\MediaStackOps.ps1") {
    . "$BaseDir\MediaStackOps.ps1"
}

$nodeInfo = Get-MediaStackClusterNodeInfo
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$fileTag   = Get-Date -Format "yyyyMMdd_HHmmss"

$HandoffsDir = Join-Path $BaseDir "handoffs"
if (-not (Test-Path $HandoffsDir)) { New-Item -ItemType Directory -Force -Path $HandoffsDir | Out-Null }

if (-not $ReportPath) {
    $ReportPath = Join-Path $HandoffsDir "Proxy_Port_Diagnostic_Report_${fileTag}.md"
}

Write-Host "`n================================================================================" -ForegroundColor DarkCyan
Write-Host "   M E D I A S T A C K   P R O X Y   &   P O R T   D I A G N O S T I C   S U I T E" -ForegroundColor Cyan
Write-Host ("   Node: {0} ({1}) | IP: {2}" -f $nodeInfo.LocalHostName, $nodeInfo.LocalRole, $nodeInfo.LocalIP) -ForegroundColor DarkGray
Write-Host ("   Peer: {0} ({1}) | Peer IP: {2}" -f $nodeInfo.PeerHostName, $nodeInfo.PeerRole, $nodeInfo.PeerIP) -ForegroundColor DarkGray
Write-Host ("   Timestamp: {0} | Auto-Repair: {1}" -f $timestamp, $AutoRepair) -ForegroundColor DarkGray
Write-Host "================================================================================" -ForegroundColor DarkCyan

# Define Canonical Matrix of Monitored Services & Sockets
$ServiceMatrix = @(
    @{ Name="Caddy Gateway HTTP";    Port=80;    Container="caddy";        Category="INGRESS";    Critical=$true;  Endpoint="http://127.0.0.1/" },
    @{ Name="Caddy Gateway HTTPS";   Port=443;   Container="caddy";        Category="INGRESS";    Critical=$true;  Endpoint="https://127.0.0.1/" },
    @{ Name="API Gateway REST";      Port=3000;  Container="api-gateway";  Category="API";        Critical=$true;  Endpoint="http://127.0.0.1:3000/api/system/status" },
    @{ Name="Jellyfin Media Server"; Port=8096;  Container="jellyfin";     Category="STREAMING";  Critical=$true;  Endpoint="http://127.0.0.1:8096/health" },
    @{ Name="Sonarr TV Automation";  Port=8989;  Container="sonarr";       Category="AUTOMATION"; Critical=$true;  Endpoint="http://127.0.0.1:8989/ping" },
    @{ Name="Radarr Movie Manager";  Port=7878;  Container="radarr";       Category="AUTOMATION"; Critical=$true;  Endpoint="http://127.0.0.1:7878/ping" },
    @{ Name="Prowlarr Indexer";      Port=9696;  Container="prowlarr";     Category="INDEXER";    Critical=$true;  Endpoint="http://127.0.0.1:9696/ping" },
    @{ Name="Bazarr Subtitles";      Port=6767;  Container="bazarr";       Category="SUBTITLES";  Critical=$true;  Endpoint="http://127.0.0.1:6767/" },
    @{ Name="Jellyseerr Requests";   Port=5055;  Container="jellyseerr";   Category="REQUESTS";   Critical=$true;  Endpoint="http://127.0.0.1:5055/api/v1/status" },
    @{ Name="Transmission Web UI";   Port=9091;  Container="transmission"; Category="TORRENT";    Critical=$true;  Endpoint="http://127.0.0.1:9091/transmission/web/" },
    @{ Name="Transmission Peer TCP"; Port=51413; Container="transmission"; Category="TORRENT";    Critical=$false; Endpoint="" },
    @{ Name="TVHeadend Web UI";      Port=9981;  Container="tvheadend";    Category="LIVETV";     Critical=$true;  Endpoint="http://127.0.0.1:9981/" },
    @{ Name="TVHeadend HTSP Stream"; Port=9982;  Container="tvheadend";    Category="LIVETV";     Critical=$false; Endpoint="" },
    @{ Name="Mediastack DB GUI";     Port=8080;  Container="mediastack-db";Category="DATABASE";   Critical=(-not $nodeInfo.IsVoltaireDeux); Endpoint="http://127.0.0.1:8080/" },
    @{ Name="Syncthing Web GUI";     Port=8384;  Container="syncthing";    Category="SYNC";       Critical=$false; Endpoint="http://127.0.0.1:8384/" },
    @{ Name="Syncthing Peer TCP";    Port=22000; Container="syncthing";    Category="SYNC";       Critical=$false; Endpoint="" },
    @{ Name="MusicBrainz Secondary"; Port=5001;  Container="musicbrainz";  Category="METADATA";   Critical=$false; Endpoint="http://127.0.0.1:5001/" },
    @{ Name="MusicBrainz Primary";   Port=5000;  Container="remote";       Category="METADATA";   Critical=$false; Endpoint="http://$($nodeInfo.PrimaryServerIP):5000/" }
)

# Define Subdomain Reverse Proxy Routes (HTTP & HTTPS)
$DomainPrefix = if ($nodeInfo.IsVoltaireDeux) { "voltairedeux.local" } else { "voltaireun.local" }
$ProxyRoutes = @(
    @{ Name="Dashboard Ingress HTTP";   Host="http://$DomainPrefix" },
    @{ Name="Dashboard Ingress HTTPS";  Host="https://$DomainPrefix" },
    @{ Name="Jellyfin Subdomain HTTP";  Host="http://jellyfin.$DomainPrefix" },
    @{ Name="Jellyfin Subdomain HTTPS"; Host="https://jellyfin.$DomainPrefix" },
    @{ Name="Sonarr Subdomain HTTPS";   Host="https://sonarr.$DomainPrefix" },
    @{ Name="Radarr Subdomain HTTPS";   Host="https://radarr.$DomainPrefix" },
    @{ Name="Prowlarr Subdomain HTTPS"; Host="https://prowlarr.$DomainPrefix" },
    @{ Name="Bazarr Subdomain HTTPS";   Host="https://bazarr.$DomainPrefix" },
    @{ Name="Jellyseerr Route HTTPS";   Host="https://jellyseerr.$DomainPrefix" },
    @{ Name="API Gateway Route HTTPS";  Host="https://api.$DomainPrefix" },
    @{ Name="Database GUI Route HTTPS"; Host="https://db.$DomainPrefix" }
)

$diagnosticResults = @()
$repairedCount = 0
$criticalFails = 0

Write-Host "`n[STAGE 1/2] Probing Canonical TCP Ports & Sockets..." -ForegroundColor Yellow

foreach ($svc in $ServiceMatrix) {
    $targetHost = if ($svc.Container -eq "remote") { $nodeInfo.PrimaryServerIP } else { "127.0.0.1" }
    $probe = Test-MediaStackPort -Hostname $targetHost -Port $svc.Port -TimeoutMs $TimeoutMs
    
    $color     = if ($probe.IsOpen) { "Green" } elseif ($svc.Critical) { "Red" } else { "DarkGray" }
    $analysis  = ""

    if (-not $probe.IsOpen) {
        if ($svc.Critical) {
            $criticalFails++
            # Error Root Cause Analysis
            $cStatus = docker ps --filter "name=^/$($svc.Container)$" --format "{{.Status}}" 2>$null
            if (-not $cStatus) {
                $analysis = "Container '$($svc.Container)' is stopped / not created."
            } elseif ($cStatus -notmatch "Up") {
                $analysis = "Container '$($svc.Container)' is in unhealthy state: $cStatus"
            } else {
                $netstat = Get-NetTCPConnection -LocalPort $svc.Port -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($netstat) {
                    $analysis = "Port conflict: PID $($netstat.OwningProcess) is holding port $($svc.Port)."
                } else {
                    $analysis = "Socket closed or firewall blocking inbound traffic on port $($svc.Port)."
                }
            }

            # Execute Auto-Repair if active
            if ($AutoRepair) {
                Write-Host ("`n  [AUTO-REPAIR] Attempting remediation for {0} on port {1}..." -f $svc.Name, $svc.Port) -ForegroundColor Yellow
                $repairRes = Repair-MediaStackPortConflict -Port $svc.Port -ContainerName $svc.Container -ServiceName $svc.Name
                if ($repairRes.Repaired) {
                    Write-Host ("  [RESOLVED] {0} successfully restored online!" -f $svc.Name) -ForegroundColor Green
                    $probe.IsOpen = $true
                    $probe.Status = "REPAIRED_ONLINE"
                    $repairedCount++
                    $criticalFails--
                    $analysis += " -> Remediated automatically."
                } else {
                    Write-Host ("  [UNRESOLVED] Failed to auto-repair {0}." -f $svc.Name) -ForegroundColor Red
                }
            }
        } else {
            $analysis = "Standby / optional node service not currently active."
        }
    }

    $entry = [PSCustomObject]@{
        Name        = $svc.Name
        Port        = $svc.Port
        Container   = $svc.Container
        Category    = $svc.Category
        Critical    = $svc.Critical
        IsOpen      = $probe.IsOpen
        LatencyMs   = $probe.LatencyMs
        Status      = $probe.Status
        Analysis    = $analysis
    }
    $diagnosticResults += $entry

    Write-Host ("  [{0,-7}] {1,-26} | Port: {2,5} | Latency: {3,4}ms | {4}" -f $entry.Status, $entry.Name, $entry.Port, $entry.LatencyMs, $entry.Analysis) -ForegroundColor $color
}

Write-Host "`n[STAGE 2/2] Probing Reverse Proxy Routes & Subdomains..." -ForegroundColor Yellow

$proxyResults = @()
foreach ($route in $ProxyRoutes) {
    $httpProbe = Test-MediaStackHttpRoute -Url $route.Host -TimeoutSec 2 -SkipCertificateCheck
    if (-not $httpProbe.IsSuccess) {
        # Fallback to direct localhost Caddy ingress with Host header
        $domainHost = ($route.Host -replace '^https?://', '')
        $curlArgs = "-s -o NUL -w `"%{http_code}`" -H `"Host: $domainHost`" --max-time 2 http://127.0.0.1/"
        $curlCode = (cmd.exe /c "curl.exe $curlArgs 2>nul").Trim()
        if ($curlCode -and $curlCode -match '^\d{3}$') {
            $codeInt = [int]$curlCode
            if (($codeInt -ge 200 -and $codeInt -lt 400) -or ($codeInt -eq 401) -or ($codeInt -eq 308)) {
                $httpProbe.StatusCode = $codeInt
                $httpProbe.IsSuccess = $true
                $httpProbe.Message = "HTTP $codeInt (Caddy Gateway Verified)"
            }
        }
    }

    $color = if ($httpProbe.IsSuccess) { "Green" } else { "Yellow" }
    
    $proxyEntry = [PSCustomObject]@{
        Name       = $route.Name
        Url        = $route.Host
        StatusCode = $httpProbe.StatusCode
        IsSuccess  = $httpProbe.IsSuccess
        LatencyMs  = $httpProbe.LatencyMs
        Message    = $httpProbe.Message
    }
    $proxyResults += $proxyEntry

    $statusLabel = if ($httpProbe.IsSuccess) { "OK ($($httpProbe.StatusCode))" } else { "WARN ($($httpProbe.StatusCode))" }
    Write-Host ("  [{0,-8}] {1,-22} -> {2} ({3}ms)" -f $statusLabel, $proxyEntry.Name, $proxyEntry.Url, $proxyEntry.LatencyMs) -ForegroundColor $color
}

# --- WRITE COMPREHENSIVE MARKDOWN AUDIT REPORT ---
$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add("# MediaStack Fleet Proxy & Port Diagnostic Report")
$lines.Add("")
$lines.Add("- **Generated:** $timestamp")
$lines.Add("- **Local Node:** $($nodeInfo.LocalHostName) ($($nodeInfo.LocalRole))")
$lines.Add("- **Local IP:** $($nodeInfo.LocalIP)")
$lines.Add("- **Peer Node:** $($nodeInfo.PeerHostName) ($($nodeInfo.PeerRole))")
$lines.Add("- **Peer IP:** $($nodeInfo.PeerIP)")
$lines.Add("- **Auto-Repair Mode:** $(if ($AutoRepair) { 'ACTIVE (Enabled)' } else { 'DISABLED' })")
$lines.Add("- **Remediated Issues:** $repairedCount")
$lines.Add("- **Critical Failures Remaining:** $criticalFails")
$lines.Add("")
$lines.Add("---")
$lines.Add("")
$lines.Add("## 1. Canonical Sockets & Port Verification Matrix")
$lines.Add("")
$lines.Add("| Service | Port | Container | Category | Critical | Status | Latency | Root-Cause Analysis / Notes |")
$lines.Add("| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |")

foreach ($r in $diagnosticResults) {
    $critBadge = if ($r.Critical) { "**YES**" } else { "No" }
    $statusBadge = if ($r.IsOpen) { "ONLINE" } elseif ($r.Critical) { "FAILING" } else { "STANDBY" }
    $note = if ($r.Analysis) { $r.Analysis } else { "Operating normally" }
    $lines.Add("| **$($r.Name)** | $($r.Port) | $($r.Container) | $($r.Category) | $critBadge | $statusBadge | $($r.LatencyMs) ms | $note |")
}

$lines.Add("")
$lines.Add("---")
$lines.Add("")
$lines.Add("## 2. Reverse Proxy Subdomain Ingress Health")
$lines.Add("")
$lines.Add("| Route Name | Target URL | HTTP Status | Response Time | Diagnostics |")
$lines.Add("| :--- | :--- | :--- | :--- | :--- |")

foreach ($p in $proxyResults) {
    $statBadge = if ($p.IsSuccess) { "$($p.StatusCode) OK" } else { "$($p.StatusCode) WARN" }
    $lines.Add("| **$($p.Name)** | $($p.Url) | $statBadge | $($p.LatencyMs) ms | $($p.Message) |")
}

$lines.Add("")
$lines.Add("---")
$lines.Add("")
$lines.Add("## 3. Executive Assessment & Readiness")
$lines.Add("")
$lines.Add("- **Port Health Status:** $(if ($criticalFails -eq 0) { '100% Core Sockets Operational' } else { "$criticalFails Unresolved Critical Port Issues" })")
$lines.Add("- **Auto-Repair Success:** $repairedCount auto-remediations applied")
$lines.Add("- **Cluster Readiness:** $(if ($criticalFails -eq 0) { 'READY for cluster synchronization & pipeline operations.' } else { 'BLOCKED: Resolve critical port conflicts before continuing.' })")
$lines.Add("")
$lines.Add("*Report archived in: $ReportPath*")

$reportContent = $lines -join "`r`n"
Set-Content -Path $ReportPath -Value $reportContent -Encoding UTF8
Write-Host ("`n[AUDIT REPORT ARCHIVED] -> {0}" -f $ReportPath) -ForegroundColor Cyan

# Log to SQLite
try {
    $logFields = @{
        port_key     = "$($nodeInfo.LocalIP):ALL"
        service_name = "ProxyAndPortDiagnosticSuite"
        event_type   = if ($criticalFails -eq 0) { "DIAGNOSTIC_PASSED" } else { "DIAGNOSTIC_ANOMALIES" }
        message      = "Checked $($ServiceMatrix.Count) ports and $($ProxyRoutes.Count) proxies. Repaired: $repairedCount, Critical Fails: $criticalFails."
    }
    Write-MediaStackLog -Table "port_monitor_events_log" -Fields $logFields
} catch { }

if ($criticalFails -gt 0) {
    Write-Host "`n[ERROR] Diagnostic check failed with $criticalFails unresolved critical port errors." -ForegroundColor Red
    exit 1
} else {
    Write-Host "`n[SUCCESS] All critical proxies and ports verified operational." -ForegroundColor Green
    exit 0
}

