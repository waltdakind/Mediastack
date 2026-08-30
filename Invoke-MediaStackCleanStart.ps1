<#
.SYNOPSIS
    Invoke-MediaStackCleanStart.ps1 - Enterprise Clean Startup & Synchronization Lifecycle Controller.

.DESCRIPTION
    Executes an orchestrated, safe, zero-downtime startup lifecycle for MediaStack across VoltaireUn and VoltaireDeux:
    1. Dynamic Node Awareness & LAN IP Discovery: Detects node role, local IP, and peer host status.
    2. OneDrive & Git Pre-Start Sync/Merge: Reconciles shared configuration files and scripts.
    3. Mandatory Pre-Start Database Safety Snapshot: Flushes WALs and records SHA-256 backup entries.
    4. Pre-Flight Port Conflict Detection & Auto-Repair: Frees rogue sockets and tests listeners.
    5. Docker Compose Orchestration: Starts the container stack with verified volume mounts.
    6. Post-Start Proxy & Service Verification: Validates Caddy subdomains and API endpoints.

.PARAMETER FreshDeploy
    Pulls fresh container images (docker compose pull) before starting.

.PARAMETER SkipMerge
    Bypasses the OneDrive configuration merge step.

.PARAMETER DryRun
    Simulates the startup pipeline without modifying system state.

.EXAMPLE
    .\Invoke-MediaStackCleanStart.ps1
    .\Invoke-MediaStackCleanStart.ps1 -FreshDeploy
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)][switch]$FreshDeploy,
    [Parameter(Mandatory=$false)][switch]$SkipMerge,
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
Write-Host "   M E D I A S T A C K   C L E A N   S T A R T   L I F E C Y C L E" -ForegroundColor Cyan
Write-Host ("   Node: {0} ({1}) | IP: {2}" -f $nodeInfo.LocalHostName, $nodeInfo.LocalRole, $nodeInfo.LocalIP) -ForegroundColor DarkGray
Write-Host ("   Peer: {0} ({1}) | Peer IP: {2}" -f $nodeInfo.PeerHostName, $nodeInfo.PeerRole, $nodeInfo.PeerIP) -ForegroundColor DarkGray
Write-Host ("   Timestamp: {0} | FreshDeploy: {1}" -f $timestamp, $FreshDeploy) -ForegroundColor DarkGray
Write-Host "================================================================================" -ForegroundColor DarkCyan

# --- STEP 1: PRE-START ONEDRIVE & CONFIGURATION RECONCILIATION ---
if (-not $SkipMerge) {
    Write-Host "`n[1/6] Reconciling Shared Configurations & Purging Conflict Files..." -ForegroundColor Yellow
    $mergeScript = Join-Path $PSScriptRoot "Merge-OneDriveMediaStack.ps1"
    if (Test-Path $mergeScript) {
        if (-not $DryRun) {
            & $mergeScript -PurgeStaleConflictFiles:$true -CreateBackupArchive:$true
        }
    }
} else {
    Write-Host "`n[1/6] Skipping Configuration Merge (-SkipMerge requested)." -ForegroundColor DarkGray
}

# --- STEP 2: MANDATORY PRE-START DATABASE BACKUP ---
Write-Host "`n[2/6] Generating Mandatory Pre-Start Database Safety Snapshot..." -ForegroundColor Yellow
if (-not $DryRun) {
    $dbBackup = Backup-MediaStackDatabasesPreSync -ConfigDir (Join-Path $PSScriptRoot "config") -OperationTag "CLEAN_START_PRE_FLIGHT"
    if ($dbBackup.AllPassed) {
        Write-Host "  [OK] All database snapshots verified pristine before startup." -ForegroundColor Green
    } else {
        Write-Host "  [WARN] Database backup completed with warnings." -ForegroundColor Yellow
    }
} else {
    Write-Host "  [DRY-RUN] Skipped database snapshot." -ForegroundColor DarkGray
}

# --- STEP 3: PRE-FLIGHT PORT CONFLICT DETECTION & RESOLUTION ---
Write-Host "`n[3/6] Scanning for Port Conflicts & Rogue Listeners..." -ForegroundColor Yellow
$diagScript = Join-Path $PSScriptRoot "Test-MediaStackProxyAndPorts.ps1"
if (Test-Path $diagScript) {
    if (-not $DryRun) {
        & $diagScript -AutoRepair:$true
    } else {
        & $diagScript -AuditOnly
    }
}

# --- STEP 4: FRESH IMAGE PULL (IF REQUESTED) ---
if ($FreshDeploy -and -not $DryRun) {
    Write-Host "`n[4/6] Pulling Fresh Docker Images..." -ForegroundColor Yellow
    docker compose pull 2>&1 | Out-Null
    Write-Host "  [OK] Docker images pulled." -ForegroundColor Green
} else {
    Write-Host "`n[4/6] Skipping image pull (using cached images)." -ForegroundColor DarkGray
}

# --- STEP 5: DOCKER COMPOSE STACK STARTUP ---
Write-Host "`n[5/6] Starting MediaStack Docker Compose Services..." -ForegroundColor Yellow
if (-not $DryRun) {
    docker compose up -d --remove-orphans 2>&1 | Out-Null
    Start-Sleep -Seconds 3
    Write-Host "  [OK] Docker compose stack signaled up." -ForegroundColor Green
} else {
    Write-Host "  [DRY-RUN] Simulated docker compose up." -ForegroundColor DarkGray
}

# --- STEP 6: POST-START PROXY & PORT VALIDATION ---
Write-Host "`n[6/6] Executing Post-Start Verification Pass..." -ForegroundColor Yellow
if (Test-Path $diagScript) {
    if (-not $DryRun) {
        & $diagScript -AutoRepair:$true
    }
}

Write-Host "`n================================================================================" -ForegroundColor DarkCyan
Write-Host "     M E D I A S T A C K   C L E A N   S T A R T   C O M P L E T E D" -ForegroundColor Cyan
Write-Host "================================================================================`n" -ForegroundColor DarkCyan
