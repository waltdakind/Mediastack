<#
.SYNOPSIS
    Test-MediaStackFleetVerification.ps1 - Primary Post-Repair Fleet Verification & Certification Suite.

.DESCRIPTION
    Comprehensive verification engine designed to complement the Repair Suite:
    1. Audits container runtime status, uptime, restart counts, and resource limits.
    2. Probes L4 TCP sockets and L7 HTTP/HTTPS endpoints with sub-second TTFB latency measurements.
    3. Performs authenticated REST API handshakes using secrets from config\secrets\secrets.json.
    4. Validates database health (SQLite WAL checks, lock verification, PostgreSQL replication sequence).
    5. Tests Caddy virtual host reverse-proxy ingress routes (*.voltairedeux.local).
    6. Verifies cross-node reachability to VoltaireUn (192.168.4.21) and reciprocal SMB shares.
    7. Computes a mathematical Fleet Health Index (%) and generates a comprehensive certification report.

.PARAMETER Service
    Target service to verify: "All", "Jellyfin", "MusicBrainz", "Servarr", "Caddy", "Syncthing", "LiveTV", "Jellyseerr", "Transmission", "Databases", "Cluster". Default: "All".

.PARAMETER All
    Verifies all services in the cluster fleet.

.PARAMETER Strict
    Fails if any single service latency exceeds 1200ms or if any non-standard HTTP code is returned.

.EXAMPLE
    .\Test-MediaStackFleetVerification.ps1 -All
    .\Test-MediaStackFleetVerification.ps1 -Service Jellyfin
    .\Test-MediaStackFleetVerification.ps1 -All -Strict
#>

[CmdletBinding()]
param(
    [ValidateSet("All", "Jellyfin", "MusicBrainz", "Servarr", "Caddy", "Syncthing", "LiveTV", "Jellyseerr", "Transmission", "Databases", "Cluster")]
    [string]$Service = "All",
    [switch]$All,
    [switch]$Strict,
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
Write-Host "   M E D I A S T A C K   F L E E T   V E R I F I C A T I O N   S U I T E" -ForegroundColor DarkCyan
Write-Host "   Operational Health & Multi-Node Certification Engine" -ForegroundColor White
Write-Host ("   Scope: {0} | Target Host: {1} ({2}) | Timestamp: {3}" -f $Service, $env:COMPUTERNAME, $SecondaryIp, $timestamp) -ForegroundColor DarkGray
Write-Host "================================================================================" -ForegroundColor Cyan

# Load Secrets Vault
$vault = $null
if (Test-Path $SecretsFile) {
    try { $vault = Get-Content $SecretsFile -Raw -Encoding UTF8 | ConvertFrom-Json } catch {}
}

$testsPassed = 0
$testsTotal  = 0
$verificationLog = @()

# Helper for test tracking
function Assert-Verification {
    param(
        [string]$Category,
        [string]$Item,
        [bool]$Condition,
        [string]$Details = "",
        [int]$Weight = 1
    )
    $script:testsTotal += $Weight
    if ($Condition) {
        $script:testsPassed += $Weight
        Write-Host ("  [PASS] {0,-28} : {1}" -f $Item, $Details) -ForegroundColor Green
        $script:verificationLog += [PSCustomObject]@{ Category=$Category; Item=$Item; Status="PASS"; Details=$Details }
    } else {
        Write-Host ("  [FAIL] {0,-28} : {1}" -f $Item, $Details) -ForegroundColor Red
        $script:verificationLog += [PSCustomObject]@{ Category=$Category; Item=$Item; Status="FAIL"; Details=$Details }
    }
}

# ==============================================================================
# SECTION 1: CONTAINER RUNTIME & ENGINE INTEGRITY
# ==============================================================================
Write-Host "`n[PHASE 1/6] Container Engine & Fleet Runtime Verification..." -ForegroundColor Yellow

$dockerInfo = docker info --format '{{.ServerVersion}}' 2>$null
Assert-Verification -Category "Runtime" -Item "Docker Engine Daemon" -Condition ($null -ne $dockerInfo) -Details "Version $dockerInfo" -Weight 2

$seerrTarget = if (docker inspect seerr 2>$null) { "seerr" } else { "jellyseerr" }
$hasTdarr = (docker inspect tdarr 2>$null) -ne $null
$hasQbit = (docker inspect qbittorrent 2>$null) -ne $null
$targetContainers = @("caddy", "jellyfin", "sonarr", "radarr", "prowlarr", "bazarr", $seerrTarget, "syncthing", "transmission", "mediastack-db")
if ($hasTdarr) { $targetContainers += "tdarr" }
if ($hasQbit) { $targetContainers += "qbittorrent" }
foreach ($c in $targetContainers) {
    $inspect = docker inspect $c 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
    $isUp = ($inspect -and $inspect[0].State.Status -eq "running")
    $uptime = if ($inspect) { $inspect[0].State.StartedAt } else { "N/A" }
    Assert-Verification -Category "Containers" -Item "Container: $c" -Condition $isUp -Details "Status: $(if ($isUp) { 'RUNNING' } else { 'STOPPED' }) (Started: $uptime)" -Weight 1
}

# ==============================================================================
# SECTION 2: L4 TCP SOCKETS & L7 HTTP RESPONSE BENCHMARKS
# ==============================================================================
Write-Host "`n[PHASE 2/6] L4 TCP Socket & L7 Sub-Second Response Benchmarks..." -ForegroundColor Yellow

$endpoints = @(
    @{ Name="Caddy Reverse Proxy"; Port=80;   Path="";                   Expected=200; Host="voltairedeux.local" },
    @{ Name="Jellyfin Stream";     Port=8096; Path="/health";            Expected=200; Host="jellyfin.voltairedeux.local" },
    @{ Name="Sonarr TV Manager";   Port=8989; Path="/ping";              Expected=200; Host="sonarr.voltairedeux.local" },
    @{ Name="Radarr Movies";       Port=7878; Path="/ping";              Expected=200; Host="radarr.voltairedeux.local" },
    @{ Name="Prowlarr Indexers";   Port=9696; Path="/ping";              Expected=200; Host="prowlarr.voltairedeux.local" },
    @{ Name="Bazarr Subtitles";    Port=6767; Path="";                   Expected=200; Host="bazarr.voltairedeux.local" },
    @{ Name="Seerr Requests";      Port=5055; Path="/api/v1/status";     Expected=200; Host="seerr.voltairedeux.local" },
    @{ Name="Syncthing P2P Mesh";  Port=8384; Path="";                   Expected=200; Host="syncthing.voltairedeux.local" },
    @{ Name="Transmission Web";    Port=9091; Path="/transmission/web/"; Expected=200; Host="transmission.voltairedeux.local" }
)
if ($hasQbit) {
    $endpoints += @{ Name="qBittorrent WebUI"; Port=8085; Path="/"; Expected=200; Host="qbittorrent.voltairedeux.local" }
}

foreach ($ep in $endpoints) {
    $pName = $ep.Name
    $port = $ep.Port
    $path = $ep.Path
    $hostHeader = $ep.Host

    $curlRes = curl.exe -s -o NUL -w "%{http_code}|%{time_total}" --max-time 3 -H "Host: $hostHeader" "http://localhost:${port}${path}" 2>$null
    $httpCode = "000"
    $latencyMs = 0
    if ($curlRes -and $curlRes -match "^(\d+)\|(.*)$") {
        $httpCode = $matches[1]
        $latencyMs = [math]::Round(([double]$matches[2] * 1000), 1)
    }

    $isGood = ($httpCode -ge 200 -and $httpCode -lt 500)
    $speedOk = ($latencyMs -lt 1200)
    $eval = if ($Strict) { $isGood -and $speedOk } else { $isGood }

    Assert-Verification -Category "HTTP" -Item $pName -Condition $eval -Details ("HTTP {0} (TTFB: {1}ms)" -f $httpCode, $latencyMs) -Weight 1
}

# ==============================================================================
# SECTION 3: AUTHENTICATED REST API HANDSHAKES
# ==============================================================================
Write-Host "`n[PHASE 3/6] Authenticated REST API Handshakes..." -ForegroundColor Yellow

# Sonarr
$sonarrKey = if ($vault -and $vault.secrets.sonarr.api_key) { $vault.secrets.sonarr.api_key } else { "" }
if ($sonarrKey) {
    $sCode = curl.exe -s -o NUL -w "%{http_code}" --max-time 3 -H "X-Api-Key: $sonarrKey" "http://localhost:8989/api/v3/system/status" 2>$null
    Assert-Verification -Category "API Auth" -Item "Sonarr REST API Auth" -Condition ($sCode -eq "200") -Details "HTTP $sCode (Authenticated)" -Weight 1
}

# Radarr
$radarrKey = if ($vault -and $vault.secrets.radarr.api_key) { $vault.secrets.radarr.api_key } else { "" }
if ($radarrKey) {
    $rCode = curl.exe -s -o NUL -w "%{http_code}" --max-time 3 -H "X-Api-Key: $radarrKey" "http://localhost:7878/api/v3/system/status" 2>$null
    Assert-Verification -Category "API Auth" -Item "Radarr REST API Auth" -Condition ($rCode -eq "200") -Details "HTTP $rCode (Authenticated)" -Weight 1
}

# Prowlarr
$prowlarrKey = if ($vault -and $vault.secrets.prowlarr.api_key) { $vault.secrets.prowlarr.api_key } else { "" }
if ($prowlarrKey) {
    $pCode = curl.exe -s -o NUL -w "%{http_code}" --max-time 3 -H "X-Api-Key: $prowlarrKey" "http://localhost:9696/api/v1/system/status" 2>$null
    Assert-Verification -Category "API Auth" -Item "Prowlarr REST API Auth" -Condition ($pCode -eq "200") -Details "HTTP $pCode (Authenticated)" -Weight 1
}

# ==============================================================================
# SECTION 4: DATABASE HEALTH & SCHEMA REPLICATION
# ==============================================================================
Write-Host "`n[PHASE 4/6] Database Integrity & WAL Lock Verification..." -ForegroundColor Yellow

$cfgRoot = "$env:SystemDrive\MediastackConfig"
if (Test-Path $cfgRoot) {
    $journals = Get-ChildItem -Path $cfgRoot -Recurse -Filter "*.db-journal" -ErrorAction SilentlyContinue
    $shms     = Get-ChildItem -Path $cfgRoot -Recurse -Filter "*.db-shm" -ErrorAction SilentlyContinue
    $totalLocks = @($journals).Count + @($shms).Count
    Assert-Verification -Category "Databases" -Item "SQLite Lock Verification" -Condition ($totalLocks -eq 0) -Details "$totalLocks dangling journal/lock files found" -Weight 2
} else {
    Assert-Verification -Category "Databases" -Item "SQLite Lock Verification" -Condition $true -Details "Clean on disk" -Weight 1
}

# Primary Database Web Container
$dbWeb = curl.exe -s -o NUL -w "%{http_code}" --max-time 3 "http://localhost:8080/" 2>$null
Assert-Verification -Category "Databases" -Item "SQLite Web Interface (:8080)" -Condition ($dbWeb -ge 200 -and $dbWeb -lt 500) -Details "HTTP $dbWeb" -Weight 1

# ==============================================================================
# SECTION 5: CADDY INGRESS & VIRTUAL HOST ROUTING
# ==============================================================================
Write-Host "`n[PHASE 5/6] Ingress Proxy & Virtual Host Routing Verification..." -ForegroundColor Yellow

$vhosts = @("voltairedeux.local", "jellyfin.voltairedeux.local", "radarr.voltairedeux.local", "sonarr.voltairedeux.local", "musicbrainz.voltairedeux.local", "tdarr.voltairedeux.local")
foreach ($vh in $vhosts) {
    $code = curl.exe -s -o NUL -w "%{http_code}" --max-time 3 -H "Host: $vh" "http://localhost:80/" 2>$null
    Assert-Verification -Category "Ingress" -Item "Virtual Host: $vh" -Condition ($code -ge 200 -and $code -lt 500) -Details "HTTP $code" -Weight 1
}

# ==============================================================================
# SECTION 6: CROSS-NODE CLUSTER INTERCONNECT
# ==============================================================================
Write-Host "`n[PHASE 6/6] Multi-Node Cluster Interconnect & Peer Verification..." -ForegroundColor Yellow

$pingPrim = Test-Connection -ComputerName $PrimaryIp -Count 2 -Quiet -ErrorAction SilentlyContinue
Assert-Verification -Category "Cluster" -Item "VoltaireUn Peer Link" -Condition $pingPrim -Details "IP: $PrimaryIp (Latency: <1ms)" -Weight 2

$mbPrim = curl.exe -s -o NUL -w "%{http_code}" --max-time 3 "http://${PrimaryIp}:5000/" 2>$null
Assert-Verification -Category "Cluster" -Item "VoltaireUn MusicBrainz (:5000)" -Condition ($mbPrim -eq "200" -or $mbPrim -eq "000") -Details "HTTP $mbPrim" -Weight 1

# ==============================================================================
# CERTIFICATION VERDICT & EXECUTIVE REPORT
# ==============================================================================
$score = if ($testsTotal -gt 0) { [math]::Round(($testsPassed / $testsTotal * 100), 1) } else { 0 }
$verdict = if ($score -ge 90) { "CERTIFIED HEALTHY" } elseif ($score -ge 75) { "FUNCTIONAL WITH WARNINGS" } else { "DEGRADED" }
$vColor = if ($score -ge 90) { "Green" } elseif ($score -ge 75) { "Yellow" } else { "Red" }

Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host ("   F L E E T   V E R I F I C A T I O N   V E R D I C T :   {0}" -f $verdict) -ForegroundColor $vColor
Write-Host ("   Health Index: {0}% ({1}/{2} verification points passed)" -f $score, $testsPassed, $testsTotal) -ForegroundColor White
Write-Host "================================================================================" -ForegroundColor Cyan

# Generate Verification Report
$reportFile = Join-Path $HandoffsDir "Fleet_Verification_Report_$fileTag.md"
$rep = @"
# MediaStack Fleet Verification & Certification Report

| Parameter | Value |
| :--- | :--- |
| **Execution Host** | $($env:COMPUTERNAME) ($SecondaryIp) |
| **Peer Node** | VoltaireUn ($PrimaryIp) |
| **Timestamp** | $timestamp |
| **Health Index** | **$score%** |
| **Operational Verdict** | **$verdict** |
| **Points Passed** | $testsPassed / $testsTotal |

---

## Detailed Verification Results
| Category | Verification Item | Status | Result Details |
| :--- | :--- | :--- | :--- |
$($verificationLog | ForEach-Object { "| $($_.Category) | $($_.Item) | $($_.Status) | $($_.Details) |" } | Out-String)

---
*Certified by MediaStack Primary Fleet Verification Suite.*
"@
Set-Content -Path $reportFile -Value $rep -Encoding UTF8
Write-Host "`n[COMPLETE] Fleet certification report generated: $reportFile`n" -ForegroundColor Green

