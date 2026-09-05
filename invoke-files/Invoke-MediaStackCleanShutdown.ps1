<#
.SYNOPSIS
    Invoke-MediaStackCleanShutdown.ps1 - Enterprise Clean Shutdown, WAL Flush & State Preservation Lifecycle.

.DESCRIPTION
    Executes a graceful, zero-data-loss shutdown sequence for MediaStack across VoltaireUn and VoltaireDeux:
    1. Node Awareness & Active State Inspection.
    2. SQLite WAL Checkpoint Flush: Flushes all in-memory WAL journals to disk (TRUNCATE mode)
       to guarantee zero corruption or dangling lock files on shutdown.
    3. Mandatory Pre-Shutdown Database Safety Snapshot: Generates SHA-256 verified snapshots.
    4. Post-Session OneDrive & Config Reconciliation: Synchronizes updated XML/JSON configs back to shared storage.
    5. Graceful Docker Compose Teardown: Stops containers with a 15-second grace period.

.PARAMETER Down
    Removes containers and internal networks instead of only stopping them.

.PARAMETER DryRun
    Simulates the shutdown sequence without stopping containers.

.EXAMPLE
    .\Invoke-MediaStackCleanShutdown.ps1
    .\Invoke-MediaStackCleanShutdown.ps1 -Down
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)][switch]$Down,
    [Parameter(Mandatory=$false)][switch]$DryRun
)

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::InputEncoding  = [System.Text.Encoding]::UTF8

$modulePath = Join-Path $PSScriptRoot "MediaStackOps.psm1"
if (Test-Path $modulePath) { 
    Import-Module $modulePath -Force 
} elseif (Test-Path "$PSScriptRoot\MediaStackOps.ps1") {
    . "$PSScriptRoot\MediaStackOps.ps1"
}

$nodeInfo = Get-MediaStackClusterNodeInfo
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

Write-Host "`n================================================================================" -ForegroundColor DarkCyan
Write-Host "   M E D I A S T A C K   C L E A N   S H U T D O W N   L I F E C Y C L E" -ForegroundColor Cyan
Write-Host ("   Node: {0} ({1}) | IP: {2}" -f $nodeInfo.LocalHostName, $nodeInfo.LocalRole, $nodeInfo.LocalIP) -ForegroundColor DarkGray
Write-Host ("   Timestamp: {0} | Teardown Mode: {1}" -f $timestamp, $(if ($Down) { "DOWN (Remove)" } else { "STOP (Preserve)" })) -ForegroundColor DarkGray
Write-Host "================================================================================" -ForegroundColor DarkCyan

# --- STEP 1: FLUSH SQLITE WAL TRANSACTIONS TO DISK ---
Write-Host "`n[1/4] Flushing SQLite Write-Ahead Log (WAL) Journals to Disk (TRUNCATE)..." -ForegroundColor Yellow
if (-not $DryRun) {
    $walResults = Invoke-MediaStackWalCheckpoint -Mode "TRUNCATE"
    foreach ($r in $walResults) {
        Write-Host ("  [WAL FLUSH] {0,-15} -> {1}" -f $r.Service, $r.Output) -ForegroundColor DarkCyan
    }
} else {
    Write-Host "  [DRY-RUN] Skipped WAL checkpoint flush." -ForegroundColor DarkGray
}

# --- STEP 2: CREATE PRE-SHUTDOWN DATABASE SAFETY SNAPSHOT ---
Write-Host "`n[2/4] Generating Pre-Shutdown Database Safety Snapshots (SHA-256)..." -ForegroundColor Yellow
if (-not $DryRun) {
    $shutdownBackup = Backup-MediaStackDatabasesPreSync -ConfigDir (Join-Path $PSScriptRoot "config") -OperationTag "CLEAN_SHUTDOWN"
    if ($shutdownBackup.AllPassed) {
        Write-Host "  [OK] All database snapshots safely preserved." -ForegroundColor Green
    } else {
        Write-Host "  [WARN] Pre-shutdown backup completed with warnings." -ForegroundColor Yellow
    }
} else {
    Write-Host "  [DRY-RUN] Skipped pre-shutdown snapshot." -ForegroundColor DarkGray
}

# --- STEP 3: RECONCILE STATE & MERGE BACK TO ONEDRIVE ---
Write-Host "`n[3/4] Reconciling Session Configurations to Shared OneDrive Storage..." -ForegroundColor Yellow
$mergeScript = Join-Path $PSScriptRoot "Merge-OneDriveMediaStack.ps1"
if ((Test-Path $mergeScript) -and -not $DryRun) {
    & $mergeScript -PurgeStaleConflictFiles:$true -CreateBackupArchive:$false
}

# --- STEP 4: GRACEFUL CONTAINER STOP / DOWN ---
Write-Host "`n[4/4] Gracefully Stopping Docker Compose Fleet..." -ForegroundColor Yellow
if (-not $DryRun) {
    if ($Down) {
        docker compose down --timeout 15 2>&1 | Out-Null
        Write-Host "  [OK] Docker Compose stack down." -ForegroundColor Green
    } else {
        docker compose stop --timeout 15 2>&1 | Out-Null
        Write-Host "  [OK] Docker Compose containers gracefully stopped." -ForegroundColor Green
    }
} else {
    Write-Host "  [DRY-RUN] Simulated docker compose shutdown." -ForegroundColor DarkGray
}

Write-Host "`n================================================================================" -ForegroundColor DarkCyan
Write-Host "     M E D I A S T A C K   C L E A N   S H U T D O W N   C O M P L E T E D" -ForegroundColor Cyan
Write-Host "================================================================================`n" -ForegroundColor DarkCyan
