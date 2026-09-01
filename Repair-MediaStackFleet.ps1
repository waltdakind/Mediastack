<#
.SYNOPSIS
    Repair-MediaStackFleet.ps1 - Master Orchestrator for Multi-Service Diagnostic & Auto-Remediation.

.DESCRIPTION
    Unified master repair engine dispatching specialized diagnostics and self-healing across the entire MediaStack fleet:
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
    [ValidateSet("All", "Jellyfin", "MusicBrainz", "Servarr", "Caddy", "Syncthing", "LiveTV", "Jellyseerr", "Transmission")]
    [string]$Service = "All",
    [switch]$All,
    [switch]$AutoFix,
    [switch]$DiagOnly
)

if ($All) { $Service = "All" }

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::InputEncoding  = [System.Text.Encoding]::UTF8

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$fileTag = Get-Date -Format "yyyyMMdd_HHmmss"
$BaseDir = $PSScriptRoot
$HandoffsDir = Join-Path $BaseDir "handoffs"

if (-not (Test-Path $HandoffsDir)) { New-Item -ItemType Directory -Force -Path $HandoffsDir | Out-Null }

Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host "   M E D I A S T A C K   M A S T E R   F L E E T   R E P A I R   H U B" -ForegroundColor DarkCyan
Write-Host ("   Target Service: {0} | Mode: {1} | Timestamp: {2}" -f $Service, $(if ($DiagOnly) { "Diagnostic Only" } else { "Active Auto-Remediation" }), $timestamp) -ForegroundColor White
Write-Host "================================================================================" -ForegroundColor Cyan

$shouldFix = ($AutoFix -or -not $DiagOnly)

# 1. Jellyfin
if ($Service -eq "All" -or $Service -eq "Jellyfin") {
    $script = Join-Path $BaseDir "Repair-JellyfinServer.ps1"
    if (Test-Path $script) {
        if ($shouldFix) { & $script -AutoFix } else { & $script -DiagOnly }
    }
}

# 2. MusicBrainz
if ($Service -eq "All" -or $Service -eq "MusicBrainz") {
    $script = Join-Path $BaseDir "Repair-MusicBrainzMirror.ps1"
    if (Test-Path $script) {
        if ($shouldFix) { & $script -AutoFix } else { & $script -DiagOnly }
    }
}

# 3. Servarr Fleet (Sonarr, Radarr, Prowlarr, Bazarr)
if ($Service -eq "All" -or $Service -eq "Servarr") {
    $script = Join-Path $BaseDir "Repair-ServarrFleet.ps1"
    if (Test-Path $script) {
        if ($shouldFix) { & $script -TargetService All -AutoFix } else { & $script -TargetService All -DiagOnly }
    }
}

# 4. Caddy Ingress Gateway
if ($Service -eq "All" -or $Service -eq "Caddy") {
    $script = Join-Path $BaseDir "Repair-CaddyGateway.ps1"
    if (Test-Path $script) {
        if ($shouldFix) { & $script -AutoFix } else { & $script -DiagOnly }
    }
}

# 5. Syncthing P2P Mesh
if ($Service -eq "All" -or $Service -eq "Syncthing") {
    $script = Join-Path $BaseDir "Repair-SyncthingCluster.ps1"
    if (Test-Path $script) {
        if ($shouldFix) { & $script -AutoFix } else { & $script -DiagOnly }
    }
}

# 6. Live TV & Hardware Tuner
if ($Service -eq "All" -or $Service -eq "LiveTV") {
    $script = Join-Path $BaseDir "Repair-LiveTvTuner.ps1"
    if (Test-Path $script) {
        if ($shouldFix) { & $script -AutoFix } else { & $script -DiagOnly }
    }
}

# 7. Jellyseerr Request Gateway
if ($Service -eq "All" -or $Service -eq "Jellyseerr") {
    $script = Join-Path $BaseDir "Repair-JellyseerrServer.ps1"
    if (Test-Path $script) {
        if ($shouldFix) { & $script -AutoFix } else { & $script -DiagOnly }
    }
}

# 8. Transmission BitTorrent Daemon
if ($Service -eq "All" -or $Service -eq "Transmission") {
    $script = Join-Path $BaseDir "Repair-TransmissionDaemon.ps1"
    if (Test-Path $script) {
        if ($shouldFix) { & $script -AutoFix } else { & $script -DiagOnly }
    }
}

Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host "   [SUCCESS] MediaStack Master Fleet Repair Cycle Completed." -ForegroundColor Green
Write-Host "================================================================================" -ForegroundColor Cyan

$reportFile = Join-Path $HandoffsDir "MediaStack_Master_Repair_Report_$fileTag.md"
$rep = @"
# MediaStack Master Fleet Repair Execution Report

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
Write-Host "  * Master report generated: $reportFile`n" -ForegroundColor Green
