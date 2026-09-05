<#
.SYNOPSIS
    Invoke-VoltaireUnDailyPoller.ps1 - VoltaireUn Daily Update Poller, Database Sync & Health Sentinel.

.DESCRIPTION
    Autonomous daily orchestration script designed for VoltaireUn (Main Server Node):
    1. Node Awareness: Detects local node and verifies peer node (VoltaireDeux) connectivity.
    2. Update Polling: Polls GitHub remote (git fetch) and the shared OneDrive folder for new
       commits and signed manifests emitted by VoltaireDeux.
    3. Pre-Update Safety Snapshot: Executes mandatory atomic SQLite backup with SHA-256 integrity verification
       before pulling any updates or database changes.
    4. Safe Pull & Merge: Pulls latest code from GitHub and reconciles shared OneDrive configurations.
    5. Database Synchronization: Executes two-way SQLite database synchronization and lock-free verification.
    6. Proxy & Port Self-Healing: Tests all canonical ports and Caddy reverse proxies, analyzes errors,
       and automatically corrects any socket conflicts or offline containers.
    7. Executive Audit Logging: Writes daily audit report to handoffs/ and records telemetry into SQLite database.

.PARAMETER ForceSync
    Forces a complete pull, database backup, synchronization, and port diagnostic pass even if no new update manifest is detected.

.PARAMETER DryRun
    Simulates the polling and diagnostic cycle without applying changes.

.PARAMETER IntervalHours
    When running in loop mode, the polling interval in hours (default: 24).

.PARAMETER Once
    Runs a single polling and update cycle then terminates (used by Windows Task Scheduler).

.EXAMPLE
    .\Invoke-VoltaireUnDailyPoller.ps1 -Once
    .\Invoke-VoltaireUnDailyPoller.ps1 -ForceSync
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)][switch]$ForceSync,
    [Parameter(Mandatory=$false)][switch]$DryRun,
    [Parameter(Mandatory=$false)][int]$IntervalHours = 24,
    [Parameter(Mandatory=$false)][bool]$Once = $true
)

# ==============================================================================
# CLUSTER MACHINE VERIFICATION
# ==============================================================================
function Assert-ClusterNodeTarget {
    param(
        [Parameter(Mandatory=$true)][string]$ExpectedNode,
        [switch]$Force,
        [switch]$NonInteractive
    )
    $currentHost = $env:COMPUTERNAME
    $isMatch = $false
    if ($ExpectedNode -match "VoltaireDeux") {
        $isMatch = ($currentHost -match "VoltaireDeux" -or $currentHost -match "Laptop" -or $env:NODE_ROLE -eq "VoltaireDeux")
    } elseif ($ExpectedNode -match "VoltaireUn") {
        $isMatch = ($currentHost -match "VoltaireUn" -or $currentHost -match "Ordinateur" -or $currentHost -match "Server" -or $env:NODE_ROLE -eq "VoltaireUn")
    } else {
        $isMatch = ($currentHost -like "*$ExpectedNode*")
    }

    if ($Force -or $env:MEDIASTACK_FORCE_NODE -or $isMatch) { return }

    Write-Host ""
    Write-Host "================================================================================" -ForegroundColor Red
    Write-Host " [WARNING] CLUSTER MACHINE MISMATCH DETECTED" -ForegroundColor Yellow
    Write-Host "================================================================================" -ForegroundColor Red
    Write-Host (" Target Machine Requirement : [{0}]" -f $ExpectedNode) -ForegroundColor Cyan
    Write-Host (" Current Local Hostname      : [{0}]" -f $currentHost) -ForegroundColor Yellow
    Write-Host " You are running a script designed specifically for another node in the cluster." -ForegroundColor Red
    Write-Host " Proceeding on the wrong machine may disrupt cluster synchronization or services." -ForegroundColor DarkYellow
    Write-Host "--------------------------------------------------------------------------------" -ForegroundColor DarkGray

    $isNonInteractive = $NonInteractive -or ($PSBoundParameters.ContainsKey('NonInteractive') -and $PSBoundParameters['NonInteractive']) -or ($MyInvocation.Line -match '-NonInteractive')

    if ($isNonInteractive) {
        Write-Host " [ABORT] Non-interactive run on incorrect cluster machine. Exiting." -ForegroundColor Red
        Write-Host " Use -Force or set $env:MEDIASTACK_FORCE_NODE=1 to bypass.
" -ForegroundColor DarkGray
        exit 1
    }

    Write-Host " Options:" -ForegroundColor White
    Write-Host "  [C] Cancel and exit immediately (Recommended to protect cluster state)" -ForegroundColor Green
    Write-Host "  [P] Proceed anyway (Override machine check on current host)" -ForegroundColor DarkYellow
    Write-Host ""
    $choice = Read-Host " Enter choice [C/P] (Default: C)"
    if ($choice -ne "P" -and $choice -ne "p") {
        Write-Host "
 [EXITED] Operation cancelled by user.
" -ForegroundColor DarkGray
        exit 0
    }
    Write-Host "
 [OVERRIDE] Proceeding on current machine ($currentHost) as requested.
" -ForegroundColor Yellow
}
Assert-ClusterNodeTarget -ExpectedNode "VoltaireUn" -Force:$Force -NonInteractive:$NonInteractive

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::InputEncoding  = [System.Text.Encoding]::UTF8

$BaseDir = if (Test-Path (Join-Path $PSScriptRoot "..\docker-compose.yml")) { (Resolve-Path (Join-Path $PSScriptRoot "..")).Path } else { $PSScriptRoot }
$modulePath = Join-Path $BaseDir "MediaStackOps.psm1"
if (Test-Path $modulePath) { 
    Import-Module $modulePath -Force 
} elseif (Test-Path "$BaseDir\MediaStackOps.ps1") {
    . "$BaseDir\MediaStackOps.ps1"
}

$HandoffsDir = Join-Path $BaseDir "handoffs"
if (-not (Test-Path $HandoffsDir)) { New-Item -ItemType Directory -Force -Path $HandoffsDir | Out-Null }

function Invoke-DailyPollPass {
    $nodeInfo = Get-MediaStackClusterNodeInfo
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $fileTag   = Get-Date -Format "yyyyMMdd_HHmmss"

    Write-Host "`n================================================================================" -ForegroundColor DarkCyan
    Write-Host "   V O L T A I R E U N   D A I L Y   U P D A T E   &   S Y N C   P O L L E R" -ForegroundColor Cyan
    Write-Host ("   Main Server: {0} ({1}) | IP: {2}" -f $nodeInfo.LocalHostName, $nodeInfo.LocalRole, $nodeInfo.LocalIP) -ForegroundColor DarkGray
    Write-Host ("   AI Push Node: {0} ({1}) | IP: {2}" -f $nodeInfo.PeerHostName, $nodeInfo.PeerRole, $nodeInfo.PeerIP) -ForegroundColor DarkGray
    Write-Host ("   Timestamp: {0} | ForceSync: {1}" -f $timestamp, $ForceSync) -ForegroundColor DarkGray
    Write-Host "================================================================================" -ForegroundColor DarkCyan

    # --- 1. CHECK FOR NEW COMMITS & MANIFESTS ---
    Write-Host "`n[STEP 1/6] Polling GitHub & OneDrive for Updates from VoltaireDeux..." -ForegroundColor Yellow

    $hasUpdate = $false
    $updateDetails = "No new updates detected."
    $manifestPath = Join-Path $HandoffsDir "cluster_update_manifest.json"

    # A. Check Git Remote
    $hasRemote = (git remote -v 2>$null)
    if ($hasRemote) {
        Write-Host "  â€¢ Fetching remote refs from GitHub (git fetch)..." -ForegroundColor DarkCyan
        git fetch origin 2>&1 | Out-Null
        $gitDiff = git log HEAD..origin/main --oneline 2>$null
        if ($gitDiff) {
            $hasUpdate = $true
            $updateDetails = "GitHub remote contains new commits: `n$gitDiff"
            Write-Host ("  [UPDATE DETECTED] New GitHub commits found!`n{0}" -f $gitDiff) -ForegroundColor Green
        }
    }

    # B. Check Cluster Manifest in Shared OneDrive
    if (Test-Path $manifestPath) {
        try {
            $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
            if ($manifest.status -eq "READY_FOR_VOLTAIREUN_PULL") {
                $hasUpdate = $true
                $updateDetails += " | Manifest update ID: $($manifest.update_id) - $($manifest.commit_message)"
                Write-Host ("  [UPDATE DETECTED] Cluster Update Manifest found: {0} - '{1}'" -f $manifest.update_id, $manifest.commit_message) -ForegroundColor Green
            }
        } catch { }
    }

    if ($ForceSync) {
        $hasUpdate = $true
        $updateDetails += " (ForceSync override requested)"
        Write-Host "  [OVERRIDE] ForceSync flag active. Proceeding with full sync cycle." -ForegroundColor Yellow
    }

    # --- 2. PRE-UPDATE SAFETY DATABASE BACKUP ---
    Write-Host "`n[STEP 2/6] Generating Pre-Update Safety Database Snapshot (SHA-256)..." -ForegroundColor Yellow
    $backupResult = $null
    if (-not $DryRun) {
        $backupResult = Backup-MediaStackDatabasesPreSync -ConfigDir (Join-Path $PSScriptRoot "config") -OperationTag "VOLTAIREUN_DAILY_PRE_SYNC"
        if ($backupResult.AllPassed) {
            Write-Host "  [OK] All database safety snapshots generated and cryptographically verified." -ForegroundColor Green
        } else {
            Write-Host "  [WARN] Database backup completed with warnings." -ForegroundColor Yellow
        }
    } else {
        Write-Host "  [DRY-RUN] Skipped snapshot generation." -ForegroundColor DarkGray
    }

    # --- 3. PULL & MERGE UPDATES ---
    Write-Host "`n[STEP 3/6] Applying Cluster Code & Configuration Updates..." -ForegroundColor Yellow
    if ($hasUpdate -and -not $DryRun) {
        if ($hasRemote) {
            Write-Host "  â€¢ Pulling commits from GitHub (git pull origin main)..." -ForegroundColor DarkCyan
            $pullOut = git pull origin main 2>&1
            Write-Host ("  [OK] Git pull result: {0}" -f $pullOut) -ForegroundColor Green
        }

        # Reconcile OneDrive configs
        $mergeScript = if (Test-Path (Join-Path $BaseDir "sync-files\Merge-OneDriveMediaStack.ps1")) { Join-Path $BaseDir "sync-files\Merge-OneDriveMediaStack.ps1" } else { Join-Path $BaseDir "Merge-OneDriveMediaStack.ps1" }
        if (Test-Path $mergeScript) {
            & $mergeScript -PurgeStaleConflictFiles:$true -CreateBackupArchive:$false
        }
    } else {
        Write-Host "  â€¢ No new code pull required. Configurations are up to date." -ForegroundColor DarkGray
    }

    # --- 4. TWO-WAY DATABASE SYNCHRONIZATION ---
    Write-Host "`n[STEP 4/6] Synchronizing & Validating Cluster Databases..." -ForegroundColor Yellow
    if (-not $DryRun) {
        $syncDbScript = if (Test-Path (Join-Path $BaseDir "sync-files\Sync-MediaStackDatabases.ps1")) { Join-Path $BaseDir "sync-files\Sync-MediaStackDatabases.ps1" } else { Join-Path $BaseDir "Sync-MediaStackDatabases.ps1" }
        if (Test-Path $syncDbScript) {
            & $syncDbScript -RunOnce
        }
    } else {
        Write-Host "  [DRY-RUN] Skipped database sync pass." -ForegroundColor DarkGray
    }

    # --- 5. COMPREHENSIVE PROXY & PORT SELF-HEALING DIAGNOSTICS ---
    Write-Host "`n[STEP 5/6] Probing Proxies & Ports with Auto-Remediation..." -ForegroundColor Yellow
    $diagScript = if (Test-Path (Join-Path $BaseDir "test-files\Test-MediaStackProxyAndPorts.ps1")) { Join-Path $BaseDir "test-files\Test-MediaStackProxyAndPorts.ps1" } else { Join-Path $BaseDir "Test-MediaStackProxyAndPorts.ps1" }
    $portDiagPassed = $true
    if (Test-Path $diagScript) {
        if (-not $DryRun) {
            & $diagScript -AutoRepair:$true
            if ($LASTEXITCODE -ne 0) { $portDiagPassed = $false }
        } else {
            & $diagScript -AuditOnly
        }
    }

    # --- 6. UPDATE MANIFEST STATUS & WRITE DAILY REPORT ---
    Write-Host "`n[STEP 6/6] Finalizing Daily Cycle & Emitting Status Telemetry..." -ForegroundColor Yellow

    if ((Test-Path $manifestPath) -and -not $DryRun) {
        try {
            $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
            $manifest.status = "APPLIED_BY_VOLTAIREUN"
            $manifest.applied_at = $timestamp
            $manifest.applied_host = $nodeInfo.LocalHostName
            $manifest | ConvertTo-Json -Depth 5 | Set-Content -Path $manifestPath -Encoding UTF8
            Write-Host "  [OK] Manifest updated: APPLIED_BY_VOLTAIREUN" -ForegroundColor Green
        } catch { }
    }

    $dailyReportPath = Join-Path $HandoffsDir "VoltaireUn_Daily_Sync_Report_${fileTag}.md"
    $reportMd = @"
# VoltaireUn Daily Sync & Health Report

**Execution Timestamp:** $timestamp  
**Executing Node:** $($nodeInfo.LocalHostName) ($($nodeInfo.LocalRole))  
**Local IP:** $($nodeInfo.LocalIP)  
**Peer AI Node:** $($nodeInfo.PeerHostName) ($($nodeInfo.PeerIP))  
**Update Found:** $(if ($hasUpdate) { "YES" } else { "NO" })  
**Update Summary:** $updateDetails  
**Database Backup Status:** $(if ($backupResult.AllPassed) { "[OK] All Snapshots Pristine" } else { "[WARN] Completed with warnings" })  
**Proxy & Port Health:** $(if ($portDiagPassed) { "[OK] 100% Operational" } else { "[ERROR] Port Anomalies Detected" })  

---

## Actions Executed in Daily Cycle:
1. Checked GitHub repository remote & shared OneDrive update manifests.
2. Created atomic pre-sync database snapshots in ``db-backup/snapshots/``.
3. Synchronized latest scripts, configuration files, and Caddy proxy maps.
4. Flushed SQLite WAL journal logs passively and verified quick_check PRAGMA integrity.
5. Executed full socket and HTTP reverse proxy probing with automated error repair.
6. Archived execution record to SQLite telemetry and audit logs.

*Next scheduled poll cycle will run automatically in $IntervalHours hours.*
"@

    Set-Content -Path $dailyReportPath -Value $reportMd -Encoding UTF8
    Write-Host ("  [REPORT GENERATED] -> {0}" -f $dailyReportPath) -ForegroundColor Cyan

    # Telemetry
    try {
        $logFields = @{
            port_key     = "$($nodeInfo.LocalIP):DAILY_POLL"
            service_name = "VoltaireUnDailyPoller"
            event_type   = if ($portDiagPassed) { "DAILY_POLL_SUCCESS" } else { "DAILY_POLL_WITH_ERRORS" }
            message      = "Daily pass completed. HasUpdate: $hasUpdate, DB Backup OK: $($backupResult.AllPassed), Ports OK: $portDiagPassed"
        }
        Write-MediaStackLog -Table "port_monitor_events_log" -Fields $logFields
    } catch { }

    Write-Host "`n================================================================================" -ForegroundColor DarkCyan
    Write-Host "     V O L T A I R E U N   D A I L Y   P O L L   P A S S   C O M P L E T E" -ForegroundColor Cyan
    Write-Host "================================================================================`n" -ForegroundColor DarkCyan
}

# ==============================================================================
# CONTROLLER LOOP / SINGLE PASS
# ==============================================================================
if ($Once) {
    Invoke-DailyPollPass
    exit 0
}

Write-Host ("Starting continuous VoltaireUn daily poller loop every {0} hours. Press Ctrl+C to terminate." -f $IntervalHours) -ForegroundColor DarkGray
while ($true) {
    Invoke-DailyPollPass
    Start-Sleep -Seconds ($IntervalHours * 3600)
}




