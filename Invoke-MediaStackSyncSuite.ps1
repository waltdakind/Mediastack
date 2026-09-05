<#
.SYNOPSIS
    Invoke-MediaStackSyncSuite.ps1 - Master Launcher for MediaStack Synchronization, Reconciliation & Database Merge Engines.

.DESCRIPTION
    Unified master launcher for all cluster synchronization, secrets distribution, database reconciliation,
    and MusicBrainz multi-server hourly merger engines located in the \sync-files subdirectory.

.PARAMETER All
    Executes all synchronization tasks across the fleet sequentially.

.PARAMETER Task
    Specific task to execute:
    - PriorityHandoffs       : Cluster AI handoffs, code updates, and sentinel telemetry.
    - Databases              : Zero-downtime SQLite replication & pre-sync atomic snapshots.
    - Secrets                : Secrets vault and service API credentials sync.
    - MusicBrainzReplication : Live MusicBrainz hourly change packet replication.
    - MusicBrainzMerge       : Merge primary and alternate local MusicBrainz databases.
    - OneDriveMerge          : OneDrive and local host directory reconciliation.
    - VoltaireUnParity       : VoltaireUn feature parity and provisioner.

.PARAMETER RunOnce
    Executes a single synchronization pass and exits.

.PARAMETER Force
    Bypasses prompts and forces execution.

.PARAMETER NonInteractive
    Runs unattended without interactive prompts.

.EXAMPLE
    .\Invoke-MediaStackSyncSuite.ps1
    .\Invoke-MediaStackSyncSuite.ps1 -All -NonInteractive
    .\Invoke-MediaStackSyncSuite.ps1 -Task MusicBrainzMerge -NonInteractive
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)][switch]$All,
    [Parameter(Mandatory = $false)][string]$Task = "",
    [Parameter(Mandatory = $false)][switch]$RunOnce,
    [Parameter(Mandatory = $false)][switch]$Force,
    [Parameter(Mandatory = $false)][switch]$NonInteractive
)

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::InputEncoding  = [System.Text.Encoding]::UTF8

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$fileTag = Get-Date -Format "yyyyMMdd_HHmmss"
$BaseDir = $PSScriptRoot
$SyncDir = Join-Path $BaseDir "sync-files"
$HandoffsDir = Join-Path $BaseDir "handoffs"

if (-not (Test-Path $HandoffsDir)) { New-Item -ItemType Directory -Force -Path $HandoffsDir | Out-Null }

# Sync Tasks Catalog
$SyncCatalog = [ordered]@{}
$SyncCatalog["PriorityHandoffs"]       = @{ Script="Sync-MediaStackPriorityHandoffs.ps1"; Name="Priority Cluster Reconciliation & AI Handoffs" }
$SyncCatalog["Databases"]              = @{ Script="Sync-MediaStackDatabases.ps1";         Name="Zero-Downtime SQLite Databases & Snapshots" }
$SyncCatalog["Secrets"]                = @{ Script="Sync-MediaStackSecrets.ps1";           Name="Central Secrets Vault & API Credentials Sync" }
$SyncCatalog["MusicBrainzReplication"] = @{ Script="Sync-MusicBrainzReplication.ps1";     Name="MusicBrainz Live Replication Sequence & Stream" }
$SyncCatalog["MusicBrainzMerge"]       = @{ Script="Merge-MusicBrainzDatabases.ps1";       Name="Primary & Alternate MusicBrainz Database Merger" }
$SyncCatalog["OneDriveMerge"]          = @{ Script="Merge-OneDriveMediaStack.ps1";         Name="OneDrive & Local Host Config Reconciliation" }
$SyncCatalog["VoltaireUnParity"]       = @{ Script="Sync-VoltaireUnFeatureParity.ps1";    Name="VoltaireUn Feature Parity & Network Provisioner" }

# Interactive Menu
if (-not $All -and -not $Task -and -not $NonInteractive) {
    Clear-Host
    Write-Host "================================================================================" -ForegroundColor DarkCyan
    Write-Host "   M E D I A S T A C K   S Y N C   &   R E C O N C I L I A T I O N   S U I T E" -ForegroundColor Cyan
    Write-Host "   Master Launcher for Distributed Cluster Synchronization & State Engines" -ForegroundColor DarkGray
    Write-Host "================================================================================" -ForegroundColor DarkCyan
    Write-Host ("   Host: {0} | Timestamp: {1} | Subdirectory: sync-files/" -f $env:COMPUTERNAME, $timestamp) -ForegroundColor White
    Write-Host "--------------------------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "   [1] Reconcile Priority Handoffs (AI Advice, Staged Updates & Telemetry)" -ForegroundColor Green
    Write-Host "   [2] Synchronize MediaStack Databases (SQLite Snapshots & Integrity)" -ForegroundColor Yellow
    Write-Host "   [3] Synchronize Secrets Vault & API Credentials Across Cluster" -ForegroundColor Yellow
    Write-Host "   [4] Synchronize MusicBrainz Live Replication Packets" -ForegroundColor Yellow
    Write-Host "   [5] Merge Primary & Alternate Local MusicBrainz Databases" -ForegroundColor Cyan
    Write-Host "   [6] Merge OneDrive & Local MediaStack Directory Configurations" -ForegroundColor Yellow
    Write-Host "   [7] Provision VoltaireUn Cluster Feature Parity" -ForegroundColor Yellow
    Write-Host "   [A] Execute Complete Master Sync Sweep (All Engines)" -ForegroundColor Magenta
    Write-Host "   [0] Exit" -ForegroundColor DarkGray
    Write-Host "--------------------------------------------------------------------------------" -ForegroundColor DarkGray
    $choice = Read-Host "   Enter selection [1-7, A, 0]"

    switch ($choice.ToString().ToUpper()) {
        "1" { $Task = "PriorityHandoffs" }
        "2" { $Task = "Databases" }
        "3" { $Task = "Secrets" }
        "4" { $Task = "MusicBrainzReplication" }
        "5" { $Task = "MusicBrainzMerge" }
        "6" { $Task = "OneDriveMerge" }
        "7" { $Task = "VoltaireUnParity" }
        "A" { $All = $true }
        default {
            Write-Host "`nExiting Sync Suite.`n" -ForegroundColor DarkGray
            return
        }
    }
}

# Determine Selected Tasks
$tasksToRun = [ordered]@{}

if ($Task) {
    if ($SyncCatalog.Contains($Task)) {
        $tasksToRun[$Task] = $SyncCatalog[$Task]
    } else {
        $match = $SyncCatalog.Keys | Where-Object { $_ -like "*$Task*" -or $SyncCatalog[$_].Script -like "*$Task*" } | Select-Object -First 1
        if ($match) {
            $tasksToRun[$match] = $SyncCatalog[$match]
        } else {
            Write-Error "Task '$Task' not found in catalog."
            return
        }
    }
} elseif ($All) {
    foreach ($k in $SyncCatalog.Keys) {
        $tasksToRun[$k] = $SyncCatalog[$k]
    }
} else {
    # Default non-interactive: Priority Handoffs
    $tasksToRun["PriorityHandoffs"] = $SyncCatalog["PriorityHandoffs"]
}

# Execute Tasks
Write-Host "`n================================================================================" -ForegroundColor DarkCyan
Write-Host "   E X E C U T I N G   S Y N C   S U I T E" -ForegroundColor Cyan
Write-Host ("   Tasks Selected: {0}" -f $tasksToRun.Count) -ForegroundColor DarkGray
Write-Host "================================================================================" -ForegroundColor DarkCyan

$results = @()

foreach ($tKey in $tasksToRun.Keys) {
    $info = $tasksToRun[$tKey]
    $scriptPath = Join-Path $SyncDir $info.Script

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
        if ($RunOnce -and $acceptedParams -contains "RunOnce") { $params["RunOnce"] = $true }
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

# Display Results Scorecard
Write-Host "`n================================================================================" -ForegroundColor DarkCyan
Write-Host "   S Y N C   S U I T E   R E S U L T S" -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor DarkCyan
Write-Host "TASK                           | STATUS     | ELAPSED  | NAME" -ForegroundColor White
Write-Host "--------------------------------------------------------------------------------" -ForegroundColor DarkGray

foreach ($r in $results) {
    $c = if ($r.Status -eq "SUCCESS") { "Green" } else { "Red" }
    Write-Host ("{0,-30} | " -f $r.Task) -NoNewline -ForegroundColor White
    Write-Host ("{0,-10}" -f $r.Status) -NoNewline -ForegroundColor $c
    Write-Host (" | {0,-8} | {1}" -f $r.Elapsed, $r.Name) -ForegroundColor White
}

# Export Markdown Report
$reportFile = Join-Path $HandoffsDir "MediaStack_Sync_Suite_Report_$fileTag.md"
$rep = @"
# MediaStack Master Synchronization Suite Execution Report

| Parameter | Value |
| :--- | :--- |
| **Execution Host** | $($env:COMPUTERNAME) |
| **Execution Timestamp** | $timestamp |
| **Subdirectory** | \sync-files |
| **Tasks Executed** | $($results.Count) |
| **Success Count** | $(($results | Where-Object { $_.Status -eq 'SUCCESS' }).Count) |
| **Error Count** | $(($results | Where-Object { $_.Status -ne 'SUCCESS' }).Count) |

## Tasks Breakdown

| Task | Status | Elapsed | Description |
| :--- | :--- | :--- | :--- |
$($results | ForEach-Object { "| **$($_.Task)** | **$($_.Status)** | $($_.Elapsed) | $($_.Name) |" } | Out-String)

---
*Generated by Invoke-MediaStackSyncSuite.ps1.*
"@

Set-Content -Path $reportFile -Value $rep -Encoding UTF8
Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host ("   [COMPLETE] Sync Suite Finished. Full Report: {0}" -f $reportFile) -ForegroundColor Green
Write-Host "================================================================================`n" -ForegroundColor Cyan
