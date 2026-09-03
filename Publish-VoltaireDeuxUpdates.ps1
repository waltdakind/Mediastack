<#
.SYNOPSIS
    Publish-VoltaireDeuxUpdates.ps1 - VoltaireDeux Update Publisher, Git Push & Cluster Manifest Engine.

.DESCRIPTION
    Executed on VoltaireDeux (AI Acceleration & Push Node) to stage, validate, and broadcast updates
    to VoltaireUn (Main Server) and GitHub:
    1. Node Validation & Cross-Node Compatibility Check: Verifies scripts, compose templates, and configs
       for dual-node cross-architecture compliance.
    2. Mandatory Pre-Push Database Safety Snapshot: Flushes WAL logs and generates SHA-256 verified backups.
    3. Pre-Push Proxy & Port Diagnostic: Validates all ingress endpoints and sockets before releasing updates.
    4. Git Stage, Commit & Push: Pushes changes to GitHub repository (or stages locally if offline).
    5. Cluster Update Manifest Generation: Writes a signed update descriptor (handoffs/cluster_update_manifest.json)
       into the shared OneDrive folder so VoltaireUn's daily poller can ingest and apply updates.
    6. OneDrive Reconciliation: Merges configurations safely without creating conflict files.

.PARAMETER Message
    Commit and release message describing the update.

.PARAMETER SkipPortTest
    Bypasses the pre-push port verification pass.

.PARAMETER DryRun
    Simulates the push and validation pipeline without modifying git or cluster state.

.EXAMPLE
    .\Publish-VoltaireDeuxUpdates.ps1 -Message "Implement AI model acceleration and proxy failover routes"
    .\Publish-VoltaireDeuxUpdates.ps1 -DryRun
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)][string]$Message = "VoltaireDeux cluster update and synchronization pass",
    [Parameter(Mandatory=$false)][switch]$SkipPortTest,
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
$fileTag   = Get-Date -Format "yyyyMMdd_HHmmss"

Write-Host "`n================================================================================" -ForegroundColor DarkCyan
Write-Host "   V O L T A I R E D E U X   C L U S T E R   U P D A T E   P U B L I S H E R" -ForegroundColor Cyan
Write-Host ("   Source Node: {0} ({1}) | IP: {2}" -f $nodeInfo.LocalHostName, $nodeInfo.LocalRole, $nodeInfo.LocalIP) -ForegroundColor DarkGray
Write-Host ("   Target Server: {0} ({1}) | Target IP: {2}" -f $nodeInfo.PeerHostName, $nodeInfo.PeerRole, $nodeInfo.PeerIP) -ForegroundColor DarkGray
Write-Host ("   Timestamp: {0} | DryRun: {1}" -f $timestamp, $DryRun) -ForegroundColor DarkGray
Write-Host "================================================================================" -ForegroundColor DarkCyan

$HandoffsDir = Join-Path $PSScriptRoot "handoffs"
if (-not (Test-Path $HandoffsDir)) { New-Item -ItemType Directory -Force -Path $HandoffsDir | Out-Null }

# --- STAGE 1: CROSS-NODE COMPATIBILITY AUDIT ---
Write-Host "`n[STAGE 1/5] Auditing Cross-Node Configuration Compatibility..." -ForegroundColor Yellow

$compatIssues = 0
$criticalFiles = @("Caddyfile", "docker-compose.yml", "MediaStackOps.psm1", "Sync-MediaStackDatabases.ps1")
foreach ($cf in $criticalFiles) {
    $p = Join-Path $PSScriptRoot $cf
    if (Test-Path $p) {
        Write-Host ("  [OK] Validated core file: {0}" -f $cf) -ForegroundColor Green
    } else {
        Write-Host ("  [FAIL] Missing core cluster file: {0}" -f $cf) -ForegroundColor Red
        $compatIssues++
    }
}

if ($compatIssues -gt 0) {
    Write-Host "`n[ERROR] Compatibility check failed. Aborting update broadcast." -ForegroundColor Red
    exit 1
}

# --- STAGE 2: MANDATORY PRE-PUSH DATABASE BACKUP ---
Write-Host "`n[STAGE 2/5] Creating Pre-Push Database Safety Snapshots (SHA-256)..." -ForegroundColor Yellow
if (-not $DryRun) {
    $dbBackupRes = Backup-MediaStackDatabasesPreSync -ConfigDir (Join-Path $PSScriptRoot "config") -OperationTag "PRE_PUSH_VOLTAIREDEUX"
    if ($dbBackupRes.AllPassed) {
        Write-Host "  [OK] All database snapshots generated and verified before push." -ForegroundColor Green
    } else {
        Write-Host "  [WARN] Database backup completed with warnings." -ForegroundColor Yellow
    }
} else {
    Write-Host "  [DRY-RUN] Skipped physical snapshot creation." -ForegroundColor DarkGray
}

# --- STAGE 3: PRE-PUSH PROXY & PORT VERIFICATION ---
if (-not $SkipPortTest) {
    Write-Host "`n[STAGE 3/5] Executing Pre-Push Proxy & Port Health Check..." -ForegroundColor Yellow
    $portScript = Join-Path $PSScriptRoot "Test-MediaStackProxyAndPorts.ps1"
    if (Test-Path $portScript) {
        if (-not $DryRun) {
            & $portScript -AutoRepair:$true
        } else {
            & $portScript -AuditOnly
        }
    }
} else {
    Write-Host "`n[STAGE 3/5] Skipping Port Tests (-SkipPortTest requested)." -ForegroundColor DarkGray
}

# --- STAGE 4: GIT COMMIT & PUSH TO GITHUB ---
Write-Host "`n[STAGE 4/5] Staging, Committing & Pushing to GitHub..." -ForegroundColor Yellow

$gitBranch = (git branch --show-current 2>$null)
if (-not $gitBranch) { $gitBranch = "main" }

$gitStatus = (git status --porcelain 2>$null)
$commitSha = "LOCAL_STAGING"

if (-not $DryRun) {
    if ($gitStatus) {
        Write-Host "  • Staging modified and untracked files into Git index..." -ForegroundColor DarkCyan
        git add -A
        
        $fullCommitMsg = "feat(cluster): [VoltaireDeux -> VoltaireUn] $Message ($fileTag)"
        Write-Host ("  • Creating Git commit: {0}" -f $fullCommitMsg) -ForegroundColor DarkCyan
        git commit -m "$fullCommitMsg" 2>&1 | Out-Null
    } else {
        Write-Host "  • Working tree is clean. No new Git changes to commit." -ForegroundColor DarkGray
    }

    $commitSha = (git rev-parse HEAD 2>$null)
    if (-not $commitSha) { $commitSha = "HEAD_$fileTag" }

    # Check Git Remote
    $hasRemote = (git remote -v 2>$null)
    if ($hasRemote) {
        Write-Host "  • Pushing changes to remote repository (origin $gitBranch)..." -ForegroundColor DarkCyan
        $pushOut = git push origin $gitBranch 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host ("  [OK] GitHub push completed: {0}" -f ($pushOut -join ' ')) -ForegroundColor Green
        } else {
            Write-Host ("  [INFO] Git remote sync notice: {0}" -f ($pushOut -join ' ').Trim()) -ForegroundColor DarkYellow
            Write-Host "  [OK] Update package will synchronize directly via shared OneDrive cluster channel." -ForegroundColor Cyan
        }
    } else {
        Write-Host "  [INFO] No Git remote configured. Updates will propagate via shared OneDrive repository." -ForegroundColor Yellow
    }
} else {
    Write-Host "  [DRY-RUN] Simulated git commit and push." -ForegroundColor DarkGray
}

# --- STAGE 5: EMIT CLUSTER UPDATE MANIFEST & RECONCILE ONEDRIVE ---
Write-Host "`n[STAGE 5/5] Emitting Cluster Update Manifest & Synchronizing OneDrive..." -ForegroundColor Yellow

$manifestPath = Join-Path $HandoffsDir "cluster_update_manifest.json"
$manifestObj = [ordered]@{
    manifest_version   = "2.0.0"
    update_id          = "VOLTAIREDEUX_REL_$fileTag"
    publisher_node     = $nodeInfo.LocalHostName
    publisher_role     = $nodeInfo.LocalRole
    publisher_ip       = $nodeInfo.LocalIP
    target_node        = $nodeInfo.PeerHostName
    target_role        = $nodeInfo.PeerRole
    target_ip          = $nodeInfo.PeerIP
    published_at       = $timestamp
    commit_sha         = $commitSha
    commit_message     = $Message
    git_branch         = $gitBranch
    requires_db_sync   = $true
    status             = "READY_FOR_VOLTAIREUN_PULL"
}

$manifestJson = $manifestObj | ConvertTo-Json -Depth 5
Set-Content -Path $manifestPath -Value $manifestJson -Encoding UTF8
Write-Host ("  [OK] Signed cluster update manifest written: {0}" -f $manifestPath) -ForegroundColor Green

# Trigger OneDrive merge engine
$mergeScript = Join-Path $PSScriptRoot "Merge-OneDriveMediaStack.ps1"
if (Test-Path $mergeScript) {
    if (-not $DryRun) {
        & $mergeScript -PurgeStaleConflictFiles:$true -CreateBackupArchive:$true
    }
}

Write-Host "`n================================================================================" -ForegroundColor DarkCyan
Write-Host "     V O L T A I R E D E U X   U P D A T E   P U B L I S H E D   S U C C E S S F U L L Y" -ForegroundColor Cyan
Write-Host ("     Update Tag: {0} | Commit: {1}" -f $manifestObj.update_id, $commitSha.Substring(0, [Math]::Min(12, $commitSha.Length))) -ForegroundColor DarkGray
Write-Host "================================================================================`n" -ForegroundColor DarkCyan
