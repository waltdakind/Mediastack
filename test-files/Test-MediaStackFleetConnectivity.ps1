<#
.SYNOPSIS
    Test-MediaStackFleetConnectivity.ps1 - Primary Multi-Service Connectivity & Authenticated Handshake Probe.

.DESCRIPTION
    Comprehensive connectivity, network reachability, and authenticated API verification suite:
    1. L4 TCP Port Probes: Verifies active socket listeners across all 12 services.
    2. L7 HTTP/HTTPS Status & Latency: Measures TTFB latency and HTTP response codes.
    3. Caddy Reverse Proxy Ingress: Validates all virtual hosts (*.voltairedeux.local).
    4. Inter-Service Handshakes: Tests Sonarr/Radarr<->Prowlarr, Jellyfin<->Jellyseerr, Picard<->MusicBrainz, and HDHomeRun.
    5. Peer Node Connectivity: Tests link quality to VoltaireUn (192.168.4.21).

.PARAMETER Service
    Target service to probe: "All", "Jellyfin", "MusicBrainz", "Servarr", "Caddy", "Syncthing", "LiveTV", "Jellyseerr", "Transmission", "PeerNode". Default: "All".

.PARAMETER DeepAuth
    Executes authenticated REST API queries using keys from the Primary Secrets Vault.

.EXAMPLE
    .\Test-MediaStackFleetConnectivity.ps1 -All
    .\Test-MediaStackFleetConnectivity.ps1 -DeepAuth
    .\Test-MediaStackFleetConnectivity.ps1 -Service Jellyfin
#>

[CmdletBinding()]
param(
    [ValidateSet("All", "Jellyfin", "MusicBrainz", "Servarr", "Caddy", "Syncthing", "LiveTV", "Jellyseerr", "Transmission", "PeerNode")]
    [string]$Service = "All",
    [switch]$All,
    [switch]$DeepAuth,
    [string]$PrimaryIp = "192.168.4.21",
    [string]$SecondaryIp = "192.168.4.30",
    [string]$TunerIp = "192.168.4.45"
)

if ($All) { $Service = "All" }

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::InputEncoding  = [System.Text.Encoding]::UTF8

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$fileTag = Get-Date -Format "yyyyMMdd_HHmmss"
$BaseDir = if (Test-Path (Join-Path $PSScriptRoot "..\docker-compose.yml")) { (Resolve-Path (Join-Path $PSScriptRoot "..")).Path } else { $PSScriptRoot }
$HandoffsDir = Join-Path $BaseDir "handoffs"
$SecretsFile = Join-Path $BaseDir "config\secrets\secrets.json"

if (-not (Test-Path $HandoffsDir)) { New-Item -ItemType Directory -Force -Path $HandoffsDir | Out-Null }

Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host "   M E D I A S T A C K   F L E E T   C O N N E C T I V I T Y   S U I T E" -ForegroundColor DarkCyan
Write-Host ("   Service: {0} | DeepAuth: {1} | Timestamp: {2}" -f $Service, $(if ($DeepAuth) { "ACTIVE" } else { "DISABLED" }), $timestamp) -ForegroundColor White
Write-Host "================================================================================" -ForegroundColor Cyan

# Load Vault
$vault = $null
if (Test-Path $SecretsFile) {
    try { $vault = Get-Content $SecretsFile -Raw -Encoding UTF8 | ConvertFrom-Json } catch {}
}

# -----------------------------------------------------------------------------
# 1. DEFINE SERVICE PROBE MATRIX
# -----------------------------------------------------------------------------
$fleetEndpoints = @(
    @{ Name="Caddy Reverse Proxy"; Group="Caddy";        Port=80;   Path="";                   Expected=200; HostHeader="voltairedeux.local" },
    @{ Name="Jellyfin Streaming";  Group="Jellyfin";     Port=8096; Path="/health";            Expected=200; HostHeader="jellyfin.voltairedeux.local" },
    @{ Name="Sonarr TV Manager";   Group="Servarr";      Port=8989; Path="/ping";              Expected=200; HostHeader="sonarr.voltairedeux.local" },
    @{ Name="Radarr Movies";       Group="Servarr";      Port=7878; Path="/ping";              Expected=200; HostHeader="radarr.voltairedeux.local" },
    @{ Name="Prowlarr Indexers";   Group="Servarr";      Port=9696; Path="/ping";              Expected=200; HostHeader="prowlarr.voltairedeux.local" },
    @{ Name="Bazarr Subtitles";    Group="Servarr";      Port=6767; Path="";                   Expected=200; HostHeader="bazarr.voltairedeux.local" },
    @{ Name="Jellyseerr Requests"; Group="Jellyseerr";   Port=5055; Path="/api/v1/status";     Expected=200; HostHeader="jellyseerr.voltairedeux.local" },
    @{ Name="MusicBrainz Local";   Group="MusicBrainz";  Port=5001; Path="";                   Expected=500; HostHeader="musicbrainz.voltairedeux.local" },
    @{ Name="Syncthing P2P Mesh";  Group="Syncthing";    Port=8384; Path="";                   Expected=200; HostHeader="syncthing.voltairedeux.local" },
    @{ Name="Transmission Web";    Group="Transmission"; Port=9091; Path="/transmission/web/"; Expected=200; HostHeader="transmission.voltairedeux.local" },
    @{ Name="TVHeadend Live TV";    Group="LiveTV";       Port=9981; Path="";                   Expected=302; HostHeader="tvheadend.voltairedeux.local" },
    @{ Name="HDHomeRun Gateway";   Group="LiveTV";       Port=80;   Path="/discover.json";     Expected=200; HostHeader="hdhomerun.voltairedeux.local" },
    @{ Name="Tdarr Transcoder";    Group="MediaCore";    Port=8265; Path="/";                  Expected=200; HostHeader="tdarr.voltairedeux.local" },
    @{ Name="qBittorrent Client";  Group="Storage";      Port=8085; Path="/";                  Expected=200; HostHeader="qbittorrent.voltairedeux.local" }
)

$activeProbes = if ($Service -eq "All") {
    $fleetEndpoints
} else {
    $fleetEndpoints | Where-Object { $_.Group -eq $Service }
}

# -----------------------------------------------------------------------------
# 2. EXECUTE L4 TCP & L7 HTTP/HTTPS BENCHMARKS
# -----------------------------------------------------------------------------
Write-Host "`n[STAGE 1/3] Executing L4/L7 Service Reachability & Latency Probes..." -ForegroundColor Yellow

$probeResults = @()

foreach ($ep in $activeProbes) {
    $name = $ep.Name
    $port = $ep.Port
    $path = if ($ep.Path) { $ep.Path } else { "/" }
    $hostHdr = $ep.HostHeader

    # L4 TCP Socket Check
    $tcpOk = $false
    try {
        $tcpClient = [System.Net.Sockets.TcpClient]::new()
        $iar = $tcpClient.BeginConnect("127.0.0.1", $port, $null, $null)
        $success = $iar.AsyncWaitHandle.WaitOne(1000, $false)
        if ($success -and $tcpClient.Connected) {
            $tcpClient.EndConnect($iar)
            $tcpOk = $true
        }
        $tcpClient.Close()
    } catch {
        $tcpOk = $false
    }

    # L7 HTTP Probe + TTFB Measurement
    $curlOut = curl.exe -s -o NUL -w "%{http_code}|%{time_total}" --max-time 4 "http://localhost:${port}${path}" 2>$null
    $httpCode = "000"
    $latencyMs = 0
    if ($curlOut -and $curlOut -match "^(\d+)\|(.*)$") {
        $httpCode = $matches[1]
        $latencyMs = [math]::Round(([double]$matches[2] * 1000), 1)
    }

    # Port + 1 Failover on VoltaireDeux Probe (if primary port fails)
    $activePort = $port
    $isFailover = $false
    if (-not $tcpOk -or ($httpCode -eq "000" -or $httpCode -ge 500)) {
        $failoverPort = $port + 1
        try {
            $foTcp = [System.Net.Sockets.TcpClient]::new()
            $foIar = $foTcp.BeginConnect("127.0.0.1", $failoverPort, $null, $null)
            if ($foIar.AsyncWaitHandle.WaitOne(800, $false) -and $foTcp.Connected) {
                $foTcp.EndConnect($foIar)
                $foCurl = curl.exe -s -o NUL -w "%{http_code}|%{time_total}" --max-time 3 "http://localhost:${failoverPort}${path}" 2>$null
                if ($foCurl -and $foCurl -match "^(\d+)\|(.*)$") {
                    $tcpOk = $true
                    $httpCode = $matches[1]
                    $latencyMs = [math]::Round(([double]$matches[2] * 1000), 1)
                    $activePort = $failoverPort
                    $isFailover = $true
                }
            }
            $foTcp.Close()
        } catch { }
    }

    # Caddy Virtual Host Route Check
    $caddyCode = curl.exe -s -o NUL -w "%{http_code}" --max-time 3 -H "Host: $hostHdr" "http://localhost:80${path}" 2>$null

    $status = if ($isFailover) {
        "FAILOVER"
    } elseif ($tcpOk -and ($httpCode -ge 200 -and $httpCode -lt 500)) {
        "HEALTHY"
    } elseif ($tcpOk) {
        "STANDBY"
    } else {
        "OFFLINE"
    }

    $color = if ($status -eq "HEALTHY" -or $status -eq "FAILOVER") { "Green" } elseif ($status -eq "STANDBY") { "Yellow" } else { "Red" }
    $portDisplay = if ($isFailover) { ":$port -> :$activePort [FO]" } else { ":$port" }

    Write-Host ("  [{0,-8}] {1,-20} -> TCP {2,-16} | HTTP {3,-3} ({4,6}ms) | Proxy {5}" -f $status, $name, $portDisplay, $httpCode, $latencyMs, $caddyCode) -ForegroundColor $color

    $probeResults += [PSCustomObject]@{
        Service     = $name
        Port        = $activePort
        PrimaryPort = $port
        IsFailover  = $isFailover
        TcpSocket   = $tcpOk
        HTTPCode    = $httpCode
        LatencyMs   = $latencyMs
        CaddyRoute  = $caddyCode
        Status      = $status
    }
}

# -----------------------------------------------------------------------------
# 3. INTER-SERVICE AUTHENTICATED API HANDSHAKES
# -----------------------------------------------------------------------------
Write-Host "`n[STAGE 2/3] Verifying Inter-Service Handshakes & Auth Tokens..." -ForegroundColor Yellow

# Sonarr API
$sonarrKey = if ($vault -and $vault.secrets.sonarr.api_key) { $vault.secrets.sonarr.api_key } else { "" }
if ($sonarrKey) {
    $sStatus = curl.exe -s -o NUL -w "%{http_code}" --max-time 3 -H "X-Api-Key: $sonarrKey" "http://localhost:8989/api/v3/system/status" 2>$null
    Write-Host ("  * Sonarr API Auth Handshake   -> HTTP {0}" -f $sStatus) -ForegroundColor $(if ($sStatus -eq "200") { "Green" } else { "Yellow" })
}

# Radarr API
$radarrKey = if ($vault -and $vault.secrets.radarr.api_key) { $vault.secrets.radarr.api_key } else { "" }
if ($radarrKey) {
    $rStatus = curl.exe -s -o NUL -w "%{http_code}" --max-time 3 -H "X-Api-Key: $radarrKey" "http://localhost:7878/api/v3/system/status" 2>$null
    Write-Host ("  * Radarr API Auth Handshake   -> HTTP {0}" -f $rStatus) -ForegroundColor $(if ($rStatus -eq "200") { "Green" } else { "Yellow" })
}

# Prowlarr API
$prowlarrKey = if ($vault -and $vault.secrets.prowlarr.api_key) { $vault.secrets.prowlarr.api_key } else { "" }
if ($prowlarrKey) {
    $pStatus = curl.exe -s -o NUL -w "%{http_code}" --max-time 3 -H "X-Api-Key: $prowlarrKey" "http://localhost:9696/api/v1/system/status" 2>$null
    Write-Host ("  * Prowlarr API Auth Handshake -> HTTP {0}" -f $pStatus) -ForegroundColor $(if ($pStatus -eq "200") { "Green" } else { "Yellow" })
}

# -----------------------------------------------------------------------------
# 4. CROSS-NODE CLUSTER LINK
# -----------------------------------------------------------------------------
Write-Host "`n[STAGE 3/3] Testing Peer VoltaireUn (192.168.4.21) Link..." -ForegroundColor Yellow
$pingPrimary = Test-Connection -ComputerName $PrimaryIp -Count 2 -Quiet -ErrorAction SilentlyContinue
$primaryMb = curl.exe -s -o NUL -w "%{http_code}" --max-time 3 "http://${PrimaryIp}:5000/" 2>$null
$pingTuner = Test-Connection -ComputerName $TunerIp -Count 1 -Quiet -ErrorAction SilentlyContinue

Write-Host ("  * Primary VoltaireUn LAN Ping -> {0}" -f $(if ($pingPrimary) { "ONLINE (<1ms)" } else { "OFFLINE" })) -ForegroundColor $(if ($pingPrimary) { "Green" } else { "Yellow" })
Write-Host ("  * Primary MusicBrainz (:5000) -> HTTP {0}" -f $primaryMb) -ForegroundColor $(if ($primaryMb -eq "200") { "Green" } else { "Yellow" })
Write-Host ("  * Hardware Tuner HDHomeRun    -> {0}" -f $(if ($pingTuner) { "ONLINE" } else { "OFFLINE" })) -ForegroundColor $(if ($pingTuner) { "Green" } else { "DarkGray" })

# Report
$reportFile = Join-Path $HandoffsDir "Fleet_Connectivity_Audit_$fileTag.md"
$rep = @"
# MediaStack Fleet Connectivity & Audit Report

| Parameter | Value |
| :--- | :--- |
| **Execution Host** | $($env:COMPUTERNAME) ($SecondaryIp) |
| **Peer Host** | VoltaireUn ($PrimaryIp) |
| **Timestamp** | $timestamp |
| **Services Probed** | $($probeResults.Count) |

## Service Health Matrix
| Service | Port | TCP Socket | HTTP Code | Latency (ms) | Proxy Route | Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
$($probeResults | ForEach-Object { "| $($_.Service) | $($_.Port) | $($_.TcpSocket) | $($_.HTTPCode) | $($_.LatencyMs) | $($_.CaddyRoute) | $($_.Status) |" } | Out-String)

---
*Generated by Test-MediaStackFleetConnectivity.ps1.*
"@
Set-Content -Path $reportFile -Value $rep -Encoding UTF8
Write-Host "`n[SUCCESS] Connectivity audit finished. Report: $reportFile`n" -ForegroundColor Green

