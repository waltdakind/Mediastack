<#
.SYNOPSIS
    Repair-MediaStackFleet.ps1 - Primary Orchestrator for Multi-Service Diagnostic & Auto-Remediation.

.DESCRIPTION
    Unified primary repair engine dispatching specialized diagnostics and self-healing across the entire MediaStack fleet:
    1. Jellyfin (Kestrel, transcode cache, locks, ports)
    2. MusicBrainz (PostgreSQL, MetaBrainz token, replication lag, Picard.ini)
    3. Servarr Fleet (Sonarr, Radarr, Prowlarr, Bazarr SQLite locks, XML repair, API keys)
    4. Ingress & Reverse Proxy (Caddyfile validation, zero-downtime reload, ports 80/443)
    5. Syncthing (P2P mesh, .stfolder markers, API key sync)
    6. Live TV & Tuner (HDHomeRun 192.168.4.45 discovery, NextPVR tuner locks)
    7. Jellyseerr (Request gateway, auth handshake, SQLite lock purge)
    8. Transmission (BitTorrent daemon, RPC web UI, resume descriptors)

.PARAMETER Service
    Target service to repair ("All", "Jellyfin", "MusicBrainz", "Servarr", "Caddy", "Syncthing", "LiveTV", "Jellyseerr", "Transmission"). Default: "All".

.PARAMETER AutoFix
    Automatically executes remediation steps. Default is true unless -DiagOnly is specified.

.PARAMETER DiagOnly
    Executes all diagnostics in read-only / simulation mode.

.EXAMPLE
    .\Repair-MediaStackFleet.ps1 -All
    .\Repair-MediaStackFleet.ps1 -Service Jellyfin -AutoFix
    .\Repair-MediaStackFleet.ps1 -Service MusicBrainz
#>

[CmdletBinding()]
param(
    [ValidateSet("All", "Jellyfin", "MusicBrainz", "Servarr", "Caddy", "Syncthing", "LiveTV", "Seerr", "Jellyseerr", "Transmission", "Homepage", "Portainer", "ApiGateway", "MediaStackDb", "Diun")]
    [string]$Service = "All",
    [switch]$All,
    [switch]$AutoFix,
    [switch]$DiagOnly
)

if ($All) { $Service = "All" }
if ($Service -eq "Jellyseerr") { $Service = "Seerr" }

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::InputEncoding  = [System.Text.Encoding]::UTF8

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$fileTag = Get-Date -Format "yyyyMMdd_HHmmss"
$BaseDir = if (Test-Path (Join-Path $PSScriptRoot "..\docker-compose.yml")) { (Resolve-Path (Join-Path $PSScriptRoot "..")).Path } else { $PSScriptRoot }
$HandoffsDir = Join-Path $BaseDir "handoffs"

if (-not (Test-Path $HandoffsDir)) { New-Item -ItemType Directory -Force -Path $HandoffsDir | Out-Null }

Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host "   M E D I A S T A C K   M A S T E R   F L E E T   R E P A I R   H U B" -ForegroundColor DarkCyan
Write-Host ("   Target Service: {0} | Mode: {1} | Timestamp: {2}" -f $Service, $(if ($DiagOnly) { "Diagnostic Only" } else { "Active Auto-Remediation" }), $timestamp) -ForegroundColor White
Write-Host "================================================================================" -ForegroundColor Cyan

$shouldFix = ($AutoFix -or -not $DiagOnly)

# 1. Jellyfin
if ($Service -eq "All" -or $Service -eq "Jellyfin") {
    $script = Join-Path $PSScriptRoot "Repair-JellyfinServer.ps1"
    if (Test-Path $script) {
        if ($shouldFix) { & $script -AutoFix } else { & $script -DiagOnly }
    }
}

# 2. MusicBrainz
if ($Service -eq "All" -or $Service -eq "MusicBrainz") {
    $script = Join-Path $PSScriptRoot "Repair-MusicBrainzMirror.ps1"
    if (Test-Path $script) {
        if ($shouldFix) { & $script -AutoFix } else { & $script -DiagOnly }
    }
}

# 3. Servarr Fleet (Sonarr, Radarr, Prowlarr, Bazarr)
if ($Service -eq "All" -or $Service -eq "Servarr") {
    $script = Join-Path $PSScriptRoot "Repair-ServarrFleet.ps1"
    if (Test-Path $script) {
        if ($shouldFix) { & $script -TargetService All -AutoFix } else { & $script -TargetService All -DiagOnly }
    }
}

# 4. Caddy Ingress Gateway
if ($Service -eq "All" -or $Service -eq "Caddy") {
    $script = Join-Path $PSScriptRoot "Repair-CaddyGateway.ps1"
    if (Test-Path $script) {
        if ($shouldFix) { & $script -AutoFix } else { & $script -DiagOnly }
    }
}

# 5. Syncthing P2P Mesh
if ($Service -eq "All" -or $Service -eq "Syncthing") {
    $script = Join-Path $PSScriptRoot "Repair-SyncthingCluster.ps1"
    if (Test-Path $script) {
        if ($shouldFix) { & $script -AutoFix } else { & $script -DiagOnly }
    }
}

# 6. Live TV & Hardware Tuner
if ($Service -eq "All" -or $Service -eq "LiveTV") {
    $script = Join-Path $PSScriptRoot "Repair-LiveTvTuner.ps1"
    if (Test-Path $script) {
        if ($shouldFix) { & $script -AutoFix } else { & $script -DiagOnly }
    }
}

# 7. Seerr Request Gateway (succeeding Jellyseerr)
if ($Service -eq "All" -or $Service -eq "Seerr") {
    $script = Join-Path $PSScriptRoot "Repair-SeerrServer.ps1"
    if (Test-Path $script) {
        if ($shouldFix) { & $script -AutoFix } else { & $script -DiagOnly }
    }
}

# 8. Transmission BitTorrent Daemon
if ($Service -eq "All" -or $Service -eq "Transmission") {
    $script = Join-Path $PSScriptRoot "Repair-TransmissionDaemon.ps1"
    if (Test-Path $script) {
        if ($shouldFix) { & $script -AutoFix } else { & $script -DiagOnly }
    }
}

# 9. Homepage Dashboard
if ($Service -eq "All" -or $Service -eq "Homepage") {
    $script = Join-Path $PSScriptRoot "Repair-HomepageServer.ps1"
    if (Test-Path $script) {
        if ($shouldFix) { & $script -AutoFix } else { & $script -DiagOnly }
    }
}

# 10. Portainer CE Management
if ($Service -eq "All" -or $Service -eq "Portainer") {
    $script = Join-Path $PSScriptRoot "Repair-PortainerServer.ps1"
    if (Test-Path $script) {
        if ($shouldFix) { & $script -AutoFix } else { & $script -DiagOnly }
    }
}

# 11. MediaStack API Gateway
if ($Service -eq "All" -or $Service -eq "ApiGateway") {
    $script = Join-Path $PSScriptRoot "Repair-ApiGateway.ps1"
    if (Test-Path $script) {
        if ($shouldFix) { & $script -AutoFix } else { & $script -DiagOnly }
    }
}

# 12. MediaStack DB (sqlite-web)
if ($Service -eq "All" -or $Service -eq "MediaStackDb") {
    $script = Join-Path $PSScriptRoot "Repair-MediaStackDb.ps1"
    if (Test-Path $script) {
        if ($shouldFix) { & $script -AutoFix } else { & $script -DiagOnly }
    }
}

# 13. Diun Notifier
if ($Service -eq "All" -or $Service -eq "Diun") {
    $script = Join-Path $PSScriptRoot "Repair-DiunNotifier.ps1"
    if (Test-Path $script) {
        if ($shouldFix) { & $script -AutoFix } else { & $script -DiagOnly }
    }
}

Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host "   [SUCCESS] MediaStack Primary Fleet Repair Cycle Completed." -ForegroundColor Green
Write-Host "================================================================================" -ForegroundColor Cyan

$reportFile = Join-Path $HandoffsDir "MediaStack_Master_Repair_Report_$fileTag.md"
$rep = @"
# MediaStack Primary Fleet Repair Execution Report

| Parameter | Value |
| :--- | :--- |
| **Execution Host** | $($env:COMPUTERNAME) |
| **Target Service** | $Service |
| **Timestamp** | $timestamp |
| **Remediation Mode** | $(if ($DiagOnly) { 'Diagnostic Only' } else { 'Active Auto-Remediation' }) |

---
*Generated by Repair-MediaStackFleet.ps1.*
"@
Set-Content -Path $reportFile -Value $rep -Encoding UTF8
Write-Host "  * Primary report generated: $reportFile`n" -ForegroundColor Green


