<#
.SYNOPSIS
    Invoke-MediaStackUpdateSuite.ps1 - Master Launcher & Orchestrator for MediaStack Update Suite.

.DESCRIPTION
    Unified master launcher for cluster distribution, metadata update, and environment synchronization engines located in update-files/:
    1. Local DNS Virtual Host Synchronization (Update-MediaStackHostsFile.ps1, update-hosts.ps1)
    2. MusicBrainz Server Database & Change Stream Replication (Update-MusicBrainz.ps1)
    3. Music Artwork, Canonical Artist & Metadata Synchronization (Update-MusicArtwork.ps1)
    4. MediaStack Distribution Package Installer & Node Bootstrap (Install-MediaStackUpdate.ps1)
    5. VoltaireDeux Update Publisher, Pre-Push Checkpoints & Cluster Manifest Engine (Publish-VoltaireDeuxUpdates.ps1)

.PARAMETER All
    Executes standard operational updates (Hosts, Metadata, MusicBrainz).

.PARAMETER Task
    Executes a specific update task: Hosts, MusicBrainz, Artwork, InstallPackage, Publish.

.PARAMETER Force
    Applies updates without confirmation prompts.

.PARAMETER NonInteractive
    Runs unattended without interactive menus.

.EXAMPLE
    .\Invoke-MediaStackUpdateSuite.ps1 -All
    .\Invoke-MediaStackUpdateSuite.ps1 -Task Hosts
    .\Invoke-MediaStackUpdateSuite.ps1 -Task InstallPackage -Force
    .\Invoke-MediaStackUpdateSuite.ps1 -Task Publish
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)][switch]$All,
    [Parameter(Mandatory = $false)][string]$Task = "",
    [Parameter(Mandatory = $false)][switch]$Force,
    [Parameter(Mandatory = $false)][switch]$NonInteractive
)

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::InputEncoding  = [System.Text.Encoding]::UTF8

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$fileTag = Get-Date -Format "yyyyMMdd_HHmmss"
$BaseDir = $PSScriptRoot
$UpdateDir = Join-Path $BaseDir "update-files"
$HandoffsDir = Join-Path $BaseDir "handoffs"

if (-not (Test-Path $HandoffsDir)) { New-Item -ItemType Directory -Force -Path $HandoffsDir | Out-Null }

$UpdateCatalog = [ordered]@{}
$UpdateCatalog["Hosts"]          = @{ Script="Update-MediaStackHostsFile.ps1"; Name="Local DNS Virtual Hosts Synchronization" }
$UpdateCatalog["MusicBrainz"]    = @{ Script="Update-MusicBrainz.ps1";          Name="MusicBrainz Daily Change Packets Update" }
$UpdateCatalog["Artwork"]        = @{ Script="Update-MusicArtwork.ps1";         Name="Audio Artwork & Artist Metadata Enrichment" }
$UpdateCatalog["InstallPackage"] = @{ Script="Install-MediaStackUpdate.ps1";   Name="MediaStack Cluster Package Installer" }
$UpdateCatalog["Publish"]        = @{ Script="Publish-VoltaireDeuxUpdates.ps1"; Name="VoltaireDeux Update Staging & Push Engine" }

# Interactive Menu
if (-not $All -and -not $Task -and -not $NonInteractive) {
    Clear-Host
    Write-Host "`n================================================================================" -ForegroundColor DarkCyan
    Write-Host "   M E D I A S T A C K   U P D A T E   &   D E P L O Y M E N T   S U I T E" -ForegroundColor Cyan
    Write-Host "   Master Launcher for Hosts, Package Upgrades, Metadata & Cluster Releases" -ForegroundColor DarkGray
    Write-Host "================================================================================" -ForegroundColor DarkCyan
    Write-Host ("   Host: {0} | Timestamp: {1} | Subdirectory: update-files/" -f $env:COMPUTERNAME, $timestamp) -ForegroundColor White
    Write-Host "--------------------------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "   [1] Synchronize Local DNS Virtual Hosts (Update-MediaStackHostsFile.ps1)" -ForegroundColor Green
    Write-Host "   [2] Ingest MusicBrainz Daily Dump & Replication Packets (Update-MusicBrainz.ps1)" -ForegroundColor Yellow
    Write-Host "   [3] Enrich Audio Collection Artwork & Artist Metadata (Update-MusicArtwork.ps1)" -ForegroundColor Yellow
    Write-Host "   [4] Install MediaStack Cluster Update Distribution Package (Install-MediaStackUpdate.ps1)" -ForegroundColor Cyan
    Write-Host "   [5] Publish VoltaireDeux Staged Updates & Manifest (Publish-VoltaireDeuxUpdates.ps1)" -ForegroundColor Cyan
    Write-Host "   [A] Run All Standard Maintenance Updates (Hosts, Metadata, MusicBrainz)" -ForegroundColor Magenta
    Write-Host "   [0] Exit" -ForegroundColor DarkGray
    Write-Host "--------------------------------------------------------------------------------" -ForegroundColor DarkGray
    $choice = Read-Host "   Enter selection [1-5, A, 0]"

    switch ($choice.ToString().ToUpper()) {
        "1" { $Task = "Hosts" }
        "2" { $Task = "MusicBrainz" }
        "3" { $Task = "Artwork" }
        "4" { $Task = "InstallPackage" }
        "5" { $Task = "Publish" }
        "A" { $All = $true }
        default {
            Write-Host "`nExiting Update Suite.`n" -ForegroundColor DarkGray
            return
        }
    }
}

$tasksToRun = [ordered]@{}

if ($Task) {
    if ($UpdateCatalog.Contains($Task)) {
        $tasksToRun[$Task] = $UpdateCatalog[$Task]
    } else {
        $match = $UpdateCatalog.Keys | Where-Object { $_ -like "*$Task*" -or $UpdateCatalog[$_].Script -like "*$Task*" } | Select-Object -First 1
        if ($match) {
            $tasksToRun[$match] = $UpdateCatalog[$match]
        } else {
            Write-Error "Task '$Task' not recognized."
            return
        }
    }
} elseif ($All) {
    $tasksToRun["Hosts"] = $UpdateCatalog["Hosts"]
    $tasksToRun["Artwork"] = $UpdateCatalog["Artwork"]
} else {
    $tasksToRun["Hosts"] = $UpdateCatalog["Hosts"]
}

Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host "   E X E C U T I N G   U P D A T E   S U I T E" -ForegroundColor DarkCyan
Write-Host ("   Tasks Selected: {0}" -f $tasksToRun.Count) -ForegroundColor White
Write-Host "================================================================================" -ForegroundColor Cyan

$results = @()

foreach ($tKey in $tasksToRun.Keys) {
    $info = $tasksToRun[$tKey]
    $scriptPath = Join-Path $UpdateDir $info.Script

    if (-not (Test-Path $scriptPath)) {
        Write-Host ("`n[-] Script not found: {0}" -f $info.Script) -ForegroundColor Red
        $results += [PSCustomObject]@{ Task=$tKey; Name=$info.Name; Status="MISSING"; Elapsed="0.0s" }
        continue
    }

    Write-Host ("`n--------------------------------------------------------------------------------") -ForegroundColor DarkGray
    Write-Host ("[*] Launching: {0} ({1})" -f $info.Name, $info.Script) -ForegroundColor Yellow
    Write-Host ("--------------------------------------------------------------------------------") -ForegroundColor DarkGray

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $status = "SUCCESS"
    try {
        $targetCmd = Get-Command $scriptPath -ErrorAction SilentlyContinue
        $acceptedParams = if ($targetCmd) { $targetCmd.Parameters.Keys } else { @() }
        $params = @{}
        if ($Force -and $acceptedParams -contains "Force") { $params["Force"] = $true }
        if ($NonInteractive -and $acceptedParams -contains "NonInteractive") { $params["NonInteractive"] = $true }
        & $scriptPath @params
        $sw.Stop()
    } catch {
        $sw.Stop()
        $status = "ERROR"
        Write-Host ("  [ERROR] Execution failed: $_") -ForegroundColor Red
    }

    $results += [PSCustomObject]@{
        Task    = $tKey
        Name    = $info.Name
        Status  = $status
        Elapsed = ("{0:N1}s" -f $sw.Elapsed.TotalSeconds)
    }
}

# Display Results
Write-Host "`n================================================================================" -ForegroundColor DarkCyan
Write-Host "   U P D A T E   S U I T E   R E S U L T S" -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor DarkCyan
Write-Host "TASK               | STATUS     | ELAPSED  | NAME" -ForegroundColor White
Write-Host "--------------------------------------------------------------------------------" -ForegroundColor DarkGray

foreach ($r in $results) {
    $c = if ($r.Status -eq "SUCCESS") { "Green" } else { "Red" }
    Write-Host ("{0,-18} | " -f $r.Task) -NoNewline -ForegroundColor White
    Write-Host ("{0,-10}" -f $r.Status) -NoNewline -ForegroundColor $c
    Write-Host (" | {0,-8} | {1}" -f $r.Elapsed, $r.Name) -ForegroundColor White
}

# Export Markdown Report
$reportFile = Join-Path $HandoffsDir "MediaStack_Update_Suite_Report_$fileTag.md"
$rep = @"
# MediaStack Master Update Suite Execution Report

| Parameter | Value |
| :--- | :--- |
| **Execution Host** | $($env:COMPUTERNAME) |
| **Timestamp** | $timestamp |
| **Subdirectory** | \update-files |
| **Tasks Run** | $($results.Count) |

## Update Execution Breakdown

| Task | Status | Elapsed | Description |
| :--- | :--- | :--- | :--- |
$($results | ForEach-Object { "| **$($_.Task)** | **$($_.Status)** | $($_.Elapsed) | $($_.Name) |" } | Out-String)

---
*Generated by Invoke-MediaStackUpdateSuite.ps1.*
"@

Set-Content -Path $reportFile -Value $rep -Encoding UTF8
Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host ("   [COMPLETE] Update Suite Finished. Full Report: {0}" -f $reportFile) -ForegroundColor Green
Write-Host "================================================================================`n" -ForegroundColor Cyan
