<#
.SYNOPSIS
    Invoke-MediaStackRepairSuite.ps1 - Master Orchestrator & Interactive Repair Suite for MediaStack.

.DESCRIPTION
    Unified master repair suite providing interactive menus, categorized sweeps, and individual
    diagnostic and auto-remediation across all 20 MediaStack services and subsystems:
    - Media Core: Jellyfin, Seerr (succeeding Jellyseerr)
    - Servarr Fleet: Sonarr, Radarr, Prowlarr, Bazarr
    - Ingress & Routing: Caddy Gateway, API Gateway
    - Metadata & Tagging: MusicBrainz Local Mirror, Picard Tagger
    - Management & Operations: Homepage Dashboard, Portainer CE, MediaStack-DB (sqlite-web), Diun Notifier
    - Storage & Sync: Transmission Daemon, Syncthing Mesh, Media Libraries / Mounts
    - Live TV & Hardware: Tvheadend, HDHomeRun Network Tuner

.PARAMETER Category
    Target category to repair: "All", "MediaCore", "Servarr", "Ingress", "Metadata", "Management", "Storage", "LiveTV".

.PARAMETER Service
    Target specific individual service to repair:
    "Caddy", "Jellyfin", "Seerr", "Jellyseerr", "Sonarr", "Radarr", "Prowlarr", "Bazarr",
    "Transmission", "MusicBrainz", "Picard", "Syncthing", "LiveTV", "Homepage",
    "Portainer", "ApiGateway", "MediaStackDb", "Diun", "MediaLibraries".

.PARAMETER AutoFix
    Automatically executes fixes. Default: $true unless -DiagOnly is specified.

.PARAMETER DiagOnly
    Executes diagnostics in read-only / simulation mode.

.PARAMETER All
    Executes complete fleet-wide diagnostic and repair sweep.

.EXAMPLE
    .\Invoke-MediaStackRepairSuite.ps1 -All -AutoFix
    .\Invoke-MediaStackRepairSuite.ps1 -Category MediaCore
    .\Invoke-MediaStackRepairSuite.ps1 -Service Seerr
    .\Invoke-MediaStackRepairSuite.ps1 -DiagOnly
#>

[CmdletBinding(DefaultParameterSetName="Default")]
param(
    [Parameter(ParameterSetName="Category")]
    [ValidateSet("All", "MediaCore", "Servarr", "Ingress", "Metadata", "Management", "Storage", "LiveTV")]
    [string]$Category,

    [Parameter(ParameterSetName="Service")]
    [ValidateSet("Caddy", "Jellyfin", "Seerr", "Jellyseerr", "Sonarr", "Radarr", "Prowlarr", "Bazarr",
                 "Transmission", "MusicBrainz", "Picard", "Syncthing", "LiveTV", "Homepage",
                 "Portainer", "ApiGateway", "MediaStackDb", "Diun", "MediaLibraries")]
    [string]$Service,

    [Parameter(ParameterSetName="All")]
    [switch]$All,

    [switch]$AutoFix,
    [switch]$DiagOnly,
    [switch]$NonInteractive
)

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::InputEncoding  = [System.Text.Encoding]::UTF8

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$fileTag = Get-Date -Format "yyyyMMdd_HHmmss"
$BaseDir = $PSScriptRoot
$RepairDir = Join-Path $BaseDir "repair-files"
$HandoffsDir = Join-Path $BaseDir "handoffs"

if (-not (Test-Path $HandoffsDir)) { New-Item -ItemType Directory -Force -Path $HandoffsDir | Out-Null }

$shouldFix = ($AutoFix -or -not $DiagOnly)
$modeStr = if ($DiagOnly) { "Diagnostic Only (Read-Only)" } else { "Active Auto-Remediation" }

# Service definitions catalog
$ServiceCatalog = [ordered]@{
    "Caddy"          = @{ Script="Repair-CaddyGateway.ps1";       Category="Ingress";    Description="Caddy Reverse Proxy & TLS Gateway" }
    "ApiGateway"     = @{ Script="Repair-ApiGateway.ps1";         Category="Ingress";    Description="MediaStack Node.js REST API Gateway" }
    "Jellyfin"       = @{ Script="Repair-JellyfinServer.ps1";     Category="MediaCore";  Description="Jellyfin Primary Media Server" }
    "Seerr"          = @{ Script="Repair-SeerrServer.ps1";        Category="MediaCore";  Description="Seerr Media Discovery & Requests Portal" }
    "Sonarr"         = @{ Script="Repair-SonarrServer.ps1";       Category="Servarr";    Description="Sonarr TV Series Automation" }
    "Radarr"         = @{ Script="Repair-RadarrServer.ps1";       Category="Servarr";    Description="Radarr Movie Automation" }
    "Prowlarr"       = @{ Script="Repair-ProwlarrServer.ps1";     Category="Servarr";    Description="Prowlarr Indexer Manager" }
    "Bazarr"         = @{ Script="Repair-BazarrServer.ps1";       Category="Servarr";    Description="Bazarr Subtitle Automation" }
    "Transmission"   = @{ Script="Repair-TransmissionDaemon.ps1"; Category="Storage";    Description="Transmission BitTorrent Daemon" }
    "Syncthing"      = @{ Script="Repair-SyncthingCluster.ps1";   Category="Storage";    Description="Syncthing P2P File Mesh" }
    "MediaLibraries" = @{ Script="Repair-MediaLibraries.ps1";     Category="Storage";    Description="Media Directory Structure & Mounts" }
    "LiveTV"         = @{ Script="Repair-LiveTvTuner.ps1";        Category="LiveTV";     Description="Tvheadend & HDHomeRun Tuner Gateway" }
    "MusicBrainz"    = @{ Script="Repair-MusicBrainzMirror.ps1";  Category="Metadata";   Description="MusicBrainz Server, DB & Solr Search" }
    "Picard"         = @{ Script="Repair-PicardConfiguration.ps1";Category="Metadata";   Description="Picard Audio Tagger Integration" }
    "Homepage"       = @{ Script="Repair-HomepageServer.ps1";     Category="Management"; Description="Homepage Unified Dashboard" }
    "Portainer"      = @{ Script="Repair-PortainerServer.ps1";    Category="Management"; Description="Portainer CE Container Management" }
    "MediaStackDb"   = @{ Script="Repair-MediaStackDb.ps1";       Category="Management"; Description="MediaStack SQLite Web Database GUI" }
    "Diun"           = @{ Script="Repair-DiunNotifier.ps1";       Category="Management"; Description="Diun Container Image Update Notifier" }
}

# Aliases
if ($Service -eq "Jellyseerr") { $Service = "Seerr" }

# Interactive menu if no parameters supplied
if (-not $All -and -not $Category -and -not $Service -and -not $NonInteractive) {
    Clear-Host
    Write-Host "`n================================================================================" -ForegroundColor DarkCyan
    Write-Host "   M E D I A S T A C K   U N I F I E D   R E P A I R   S U I T E" -ForegroundColor Cyan
    Write-Host "   Autonomous Diagnostic, Health Audit & Self-Healing Platform" -ForegroundColor DarkGray
    Write-Host "================================================================================" -ForegroundColor DarkCyan
    Write-Host "   Remediation Mode: $modeStr" -ForegroundColor White
    Write-Host "--------------------------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "   [1] Full Fleet Repair Sweep (All 20 Services)" -ForegroundColor Green
    Write-Host "   [2] Media Core Suite (Jellyfin, Seerr)" -ForegroundColor Yellow
    Write-Host "   [3] Servarr Automation Fleet (Sonarr, Radarr, Prowlarr, Bazarr)" -ForegroundColor Yellow
    Write-Host "   [4] Ingress & Gateway Suite (Caddy, API Gateway)" -ForegroundColor Yellow
    Write-Host "   [5] Metadata & Audio Suite (MusicBrainz Mirror, Picard)" -ForegroundColor Yellow
    Write-Host "   [6] Management & Telemetry (Homepage, Portainer, MediaStack-DB, Diun)" -ForegroundColor Yellow
    Write-Host "   [7] Storage & Sync (Transmission, Syncthing, Media Libraries)" -ForegroundColor Yellow
    Write-Host "   [8] Live TV & Hardware Tuner (Tvheadend, HDHomeRun)" -ForegroundColor Yellow
    Write-Host "   [9] Select Individual Service to Repair" -ForegroundColor Cyan
    Write-Host "   [0] Exit" -ForegroundColor DarkGray
    Write-Host "--------------------------------------------------------------------------------" -ForegroundColor DarkGray
    $choice = Read-Host "   Enter selection [1-9, 0]"

    switch ($choice) {
        "1" { $All = $true }
        "2" { $Category = "MediaCore" }
        "3" { $Category = "Servarr" }
        "4" { $Category = "Ingress" }
        "5" { $Category = "Metadata" }
        "6" { $Category = "Management" }
        "7" { $Category = "Storage" }
        "8" { $Category = "LiveTV" }
        "9" {
            Write-Host "`n   Select target service:" -ForegroundColor Cyan
            $svcList = @($ServiceCatalog.Keys)
            for ($i = 0; $i -lt $svcList.Count; $i++) {
                Write-Host ("   [{0,2}] {1,-15} - {2}" -f ($i + 1), $svcList[$i], $ServiceCatalog[$svcList[$i]].Description) -ForegroundColor DarkCyan
            }
            $sChoice = Read-Host "`n   Enter service number"
            $idx = [int]$sChoice - 1
            if ($idx -ge 0 -and $idx -lt $svcList.Count) {
                $Service = $svcList[$idx]
            } else {
                Write-Host "   Invalid selection. Defaulting to full fleet sweep." -ForegroundColor Red
                $All = $true
            }
        }
        default {
            Write-Host "`nExiting MediaStack Repair Suite.`n" -ForegroundColor DarkGray
            return
        }
    }
}

if ($All) { $Category = "All" }
if (-not $Category -and -not $Service) { $Category = "All" }

# Determine which services to run
$targets = @()
if ($Service) {
    if ($ServiceCatalog.Contains($Service)) {
        $targets += $Service
    } else {
        Write-Error "Unknown service '$Service'."
        return
    }
} elseif ($Category -eq "All") {
    $targets = @($ServiceCatalog.Keys)
} else {
    foreach ($k in $ServiceCatalog.Keys) {
        if ($ServiceCatalog[$k].Category -eq $Category) {
            $targets += $k
        }
    }
}

Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host "   E X E C U T I N G   M E D I A S T A C K   R E P A I R   S U I T E" -ForegroundColor DarkCyan
Write-Host ("   Scope: {0} ({1} target services) | Mode: {2}" -f $(if ($Service) { "Service: $Service" } else { "Category: $Category" }), $targets.Count, $modeStr) -ForegroundColor White
Write-Host ("   Timestamp: {0}" -f $timestamp) -ForegroundColor DarkGray
Write-Host "================================================================================" -ForegroundColor Cyan

$results = @()

foreach ($tgt in $targets) {
    $meta = $ServiceCatalog[$tgt]
    $scriptPath = if (Test-Path (Join-Path $RepairDir $meta.Script)) {
        Join-Path $RepairDir $meta.Script
    } else {
        Join-Path $BaseDir $meta.Script
    }

    Write-Host "`n--------------------------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host ("[*] Launching Repair: {0} ({1})" -f $tgt, $meta.Description) -ForegroundColor Cyan
    Write-Host ("    Script: {0}" -f $meta.Script) -ForegroundColor DarkGray
    Write-Host "--------------------------------------------------------------------------------" -ForegroundColor DarkGray

    if (-not (Test-Path $scriptPath)) {
        Write-Host ("  [ERROR] Script not found: {0}" -f $scriptPath) -ForegroundColor Red
        $results += [PSCustomObject]@{
            Service = $tgt
            Status = "SCRIPT_NOT_FOUND"
            Details = "Script file missing: $($meta.Script)"
        }
        continue
    }

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $params = @{}
        if ($shouldFix) { $params["AutoFix"] = $true } else { $params["DiagOnly"] = $true }
        
        $res = & $scriptPath @params
        $sw.Stop()

        $results += [PSCustomObject]@{
            Service  = $tgt
            Category = $meta.Category
            Status   = if ($res -and $res.Status) { $res.Status } else { "COMPLETED" }
            Elapsed  = ("{0:N1}s" -f $sw.Elapsed.TotalSeconds)
            Details  = if ($res -and $res.Remediations) { ($res.Remediations -join "; ") } else { "Sweep finished" }
        }
    } catch {
        $sw.Stop()
        Write-Host ("  [FAIL] Unhandled error during {0} repair: $_" -f $tgt) -ForegroundColor Red
        $results += [PSCustomObject]@{
            Service  = $tgt
            Category = $meta.Category
            Status   = "ERROR"
            Elapsed  = ("{0:N1}s" -f $sw.Elapsed.TotalSeconds)
            Details  = $_.ToString()
        }
    }
}

# Print Summary Dashboard
Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host "   M E D I A S T A C K   R E P A I R   S U I T E   R E S U L T S" -ForegroundColor DarkCyan
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host ("{0,-16} | {1,-12} | {2,-12} | {3,-8} | {4}" -f "SERVICE", "CATEGORY", "STATUS", "ELAPSED", "DETAILS") -ForegroundColor White
Write-Host "--------------------------------------------------------------------------------" -ForegroundColor DarkGray

foreach ($r in $results) {
    $color = switch -wildcard ($r.Status) {
        "*HEALTHY*"   { "Green" }
        "*COMPLETED*" { "Green" }
        "*DEGRADED*"  { "Yellow" }
        "*RECOVERED*" { "Cyan" }
        default       { "Red" }
    }
    Write-Host ("{0,-16} | {1,-12} | {2,-12} | {3,-8} | {4}" -f $r.Service, $r.Category, $r.Status, $r.Elapsed, ($r.Details -replace "`r`n"," ")) -ForegroundColor $color
}

# Generate Consolidated Report
$reportFile = Join-Path $HandoffsDir "MediaStack_Repair_Suite_Report_$fileTag.md"
$tableRows = $results | ForEach-Object {
    "| **$($_.Service)** | $($_.Category) | $($_.Status) | $($_.Elapsed) | $($_.Details) |"
}

$rep = @"
# MediaStack Unified Fleet Repair Suite Execution Report

| Parameter | Value |
| :--- | :--- |
| **Execution Host** | $($env:COMPUTERNAME) |
| **Execution Scope** | $(if ($Service) { "Single Service: $Service" } else { "Category: $Category ($($targets.Count) services)" }) |
| **Execution Mode** | $modeStr |
| **Timestamp** | $timestamp |
| **Total Services Inspected** | $($results.Count) |

## Fleet Diagnostic & Remediation Matrix

| Service | Category | Status | Elapsed | Details |
| :--- | :--- | :--- | :--- | :--- |
$($tableRows -join "`n")

---
*Generated autonomously by Invoke-MediaStackRepairSuite.ps1.*
"@

Set-Content -Path $reportFile -Value $rep -Encoding UTF8

Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host ("   [COMPLETE] Suite Execution Finished. Full Report: {0}" -f $reportFile) -ForegroundColor Green
Write-Host "================================================================================`n" -ForegroundColor Cyan
