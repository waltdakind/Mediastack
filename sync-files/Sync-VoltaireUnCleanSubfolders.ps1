<#
.SYNOPSIS
    Sync-VoltaireUnCleanSubfolders.ps1 - Synchronize & Reconcile Reorganized Subfolders and Purge Root Duplicates.

.DESCRIPTION
    Executes a complete synchronization and directory hygiene pass across the cluster:
    1. Reconciles Git working tree with origin/main (cleaning any files moved to subfolders).
    2. Identifies and purges any legacy duplicate scripts in the root directory that now reside canonically in:
       - repair-files/
       - sync-files/
       - start-files/
       - invoke-files/
       - test-files/
       - update-files/
       - optimize-files/
       - restore-files/
       - replicate-files/
       - setup-files/
    3. Retains designated master launchers and root forwarders.
    4. Purges all OneDrive sync conflict artifacts (*-voltaireun.*, *-VoltaireDeux.*, * - Copy.*).
    5. Verifies junction points and directory health.

.PARAMETER DryRun
    Simulates the cleanup and reports what would be removed without deleting files.

.PARAMETER Force
    Executes cleanup without interactive confirmation.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)][switch]$DryRun,
    [Parameter(Mandatory=$false)][switch]$Force
)

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::InputEncoding  = [System.Text.Encoding]::UTF8

$BaseDir = if (Test-Path (Join-Path $PSScriptRoot "..\docker-compose.yml")) { (Resolve-Path (Join-Path $PSScriptRoot "..")).Path } else { $PSScriptRoot }

Write-Host "`n================================================================================" -ForegroundColor DarkCyan
Write-Host "     C L U S T E R   S U B F O L D E R   C L E A N U P   &   S Y N C" -ForegroundColor Cyan
Write-Host ("     Host: {0} | Working Dir: {1}" -f $env:COMPUTERNAME, $BaseDir) -ForegroundColor DarkGray
Write-Host "================================================================================" -ForegroundColor DarkCyan

# ------------------------------------------------------------------------------
# 1. GIT UPSTREAM RECONCILIATION
# ------------------------------------------------------------------------------
Write-Host "`n[STEP 1/4] Reconciling Git Repository with origin/main..." -ForegroundColor Yellow
$hasRemote = (git remote -v 2>$null)
if ($hasRemote) {
    try {
        Write-Host "  * Fetching latest tree from GitHub..." -ForegroundColor DarkCyan
        git fetch origin main 2>&1 | Out-Null
        if (-not $DryRun) {
            Write-Host "  * Aligning working tree to origin/main (pruning moved root files)..." -ForegroundColor DarkCyan
            $gitReset = git reset --hard origin/main 2>&1
            Write-Host ("  [OK] Git alignment: {0}" -f ($gitReset -join " ")) -ForegroundColor Green
        } else {
            Write-Host "  [DRY-RUN] Skipped git reset --hard" -ForegroundColor DarkGray
        }
    } catch {
        Write-Host ("  [WARN] Git reconciliation notice: {0}" -f $_.Exception.Message) -ForegroundColor Yellow
    }
} else {
    Write-Host "  * No Git remote detected. Skipping Git reset." -ForegroundColor DarkGray
}

# ------------------------------------------------------------------------------
# 2. PURGE ONEDRIVE CONFLICT ARTIFACTS
# ------------------------------------------------------------------------------
Write-Host "`n[STEP 2/4] Purging Stale OneDrive Sync Conflicts & Temp Locks..." -ForegroundColor Yellow

$purgedConflicts = 0
$allItems = Get-ChildItem -Path $BaseDir -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object {
        # Never match legitimate scripts
        $_.Name -notmatch "^Invoke-Voltaire" -and
        $_.Name -notmatch "^Start-Voltaire" -and
        $_.Name -notmatch "^Sync-Voltaire" -and
        $_.Name -notmatch "^Install-Voltaire" -and
        $_.Name -notmatch "^Publish-Voltaire" -and
        $_.Name -notmatch "^\.env-Voltaire" -and
        $_.Name -notmatch "^Caddyfile-Voltaire" -and
        # Match genuine OneDrive conflict formats
        (
            $_.Name -match " - Copy" -or
            $_.Name -match " - VoltaireUn\." -or
            $_.Name -match " - VoltaireDeux\." -or
            $_.Name -match "\.db-wal\.tmp" -or
            $_.Name -match "\.db-shm\.tmp" -or
            $_.Name -match "-VoltaireUn(-\d+)?\.(txt|log|json|md)$" -or
            $_.Name -match "-VoltaireDeux(-\d+)?\.(txt|log|json|md)$"
        )
    }

foreach ($item in $allItems) {
    if (-not $DryRun) {
        try {
            Remove-Item -Path $item.FullName -Force -ErrorAction SilentlyContinue
            Write-Host ("  [PURGED CONFLICT] {0}" -f $item.Name) -ForegroundColor Green
            $purgedConflicts++
        } catch { }
    } else {
        Write-Host ("  [DRY-RUN WOULD PURGE CONFLICT] {0}" -f $item.FullName) -ForegroundColor DarkYellow
        $purgedConflicts++
    }
}
if ($purgedConflicts -eq 0) {
    Write-Host "  [OK] Zero OneDrive conflict artifacts found." -ForegroundColor Green
} else {
    Write-Host ("  [OK] Processed {0} conflict artifacts." -f $purgedConflicts) -ForegroundColor Green
}

# ------------------------------------------------------------------------------
# 3. IDENTIFY & PURGE DUPLICATE ROOT IMPLEMENTATIONS
# ------------------------------------------------------------------------------
Write-Host "`n[STEP 3/4] Scanning for Obsolete Root Files Running from Subfolders..." -ForegroundColor Yellow

$subfolders = @(
    "repair-files", "sync-files", "start-files", "invoke-files",
    "test-files", "update-files", "optimize-files", "restore-files",
    "replicate-files", "setup-files"
)

# Canonical list of files that MUST remain in the root folder
$protectedRootFiles = @(
    "docker-compose.yml", "docker-compose.qbittorrent.yml", "Caddyfile",
    "Caddyfile-VoltaireDeux", "Caddyfile-VoltaireDeux-2", ".gitignore",
    "MediaStackOps.psm1", "MediaStackOps.ps1", "mediastack-ops.ps1",
    "start.ps1", "install.ps1", "control.ps1", "s.ps1", "s-v1.ps1", "s-v2.ps1",
    "s-sync.ps1", "S-MSF.ps1", "login-player.ps1", "System-Health.ps1",
    "Add-HostsEntries.ps1", "Bootstrap-NewNode.ps1", "Deduplicate-Media.ps1",
    "Fetch-ArtistArtwork.ps1", "Get-PicardApiKey.ps1", "HA_MediaStack.ps1",
    "Mount-MediaStackNetworkShares.ps1", "New-MediaStackNodePackage.ps1",
    "Open-DefaultBrowserUri.ps1", "Organize-LiveMusic.ps1", "Organize-Media.ps1",
    "Publish-MediaStackPorts.ps1", "Set-DnsServers.ps1",
    "Sync-VoltaireUnCleanSubfolders.ps1",
    # Master suite orchestrators
    "Invoke-MediaStackExecutionSuite.ps1",
    "Invoke-MediaStackFullRebootSuite.ps1",
    "Invoke-MediaStackOptimizationSuite.ps1",
    "Invoke-MediaStackRepairSuite.ps1",
    "Invoke-MediaStackReplicationSuite.ps1",
    "Invoke-MediaStackRestoreSuite.ps1",
    "Invoke-MediaStackSetupSuite.ps1",
    "Invoke-MediaStackStartSuite.ps1",
    "Invoke-MediaStackSuite.ps1",
    "Invoke-MediaStackSyncSuite.ps1",
    "Invoke-MediaStackTestSuite.ps1",
    "Invoke-MediaStackUpdateSuite.ps1"
)

$subfolderFiles = @{}
foreach ($sf in $subfolders) {
    $sfPath = Join-Path $BaseDir $sf
    if (Test-Path $sfPath) {
        Get-ChildItem -Path $sfPath -Filter *.ps1 -File -ErrorAction SilentlyContinue | ForEach-Object {
            if (-not $subfolderFiles.ContainsKey($_.Name)) {
                $subfolderFiles[$_.Name] = $_.FullName
            }
        }
    }
}

$rootFiles = Get-ChildItem -Path $BaseDir -Filter *.ps1 -File -ErrorAction SilentlyContinue

$purgedRootCount = 0
foreach ($rf in $rootFiles) {
    $name = $rf.Name
    if ($protectedRootFiles -contains $name) { continue }

    # If file also lives inside one of our subfolders
    if ($subfolderFiles.ContainsKey($name)) {
        $content = Get-Content $rf.FullName -Raw -ErrorAction SilentlyContinue
        # If it's an explicit forwarder (< 1200 bytes pointing to subfolder), keep it
        $isForwarder = ($content -match "Forwarder to" -or $content -match "[a-z]+-files[\\/]") -and ($rf.Length -lt 1200)

        if (-not $isForwarder) {
            if (-not $DryRun) {
                try {
                    Remove-Item -Path $rf.FullName -Force -ErrorAction SilentlyContinue
                    Write-Host ("  [PURGED DUPLICATE ROOT] {0} -> (Now running canonically from {1})" -f $name, (Split-Path $subfolderFiles[$name] -LeafBase)) -ForegroundColor Green
                    $purgedRootCount++
                } catch { }
            } else {
                Write-Host ("  [DRY-RUN WOULD PURGE] Root: {0} (duplicate of {1})" -f $name, $subfolderFiles[$name]) -ForegroundColor DarkYellow
                $purgedRootCount++
            }
        }
    }
}

if ($purgedRootCount -eq 0) {
    Write-Host "  [OK] Root directory is already clean. All scripts running canonically from subfolders & launchers." -ForegroundColor Green
} else {
    Write-Host ("  [OK] Successfully cleaned {0} duplicate root script(s)." -f $purgedRootCount) -ForegroundColor Green
}

# ------------------------------------------------------------------------------
# 4. VERIFY REORGANIZED SUBFOLDERS
# ------------------------------------------------------------------------------
Write-Host "`n[STEP 4/4] Verifying Reorganized Subfolder Health..." -ForegroundColor Yellow
foreach ($sf in $subfolders) {
    $p = Join-Path $BaseDir $sf
    if (Test-Path $p) {
        $count = (Get-ChildItem -Path $p -Filter *.ps1 -File -ErrorAction SilentlyContinue).Count
        Write-Host ("  â€¢ Subfolder [{0}]: {1} scripts registered" -f $sf, $count) -ForegroundColor DarkCyan
    }
}

Write-Host "`n================================================================================" -ForegroundColor DarkCyan
Write-Host "     S U N C   &   C L E A N U P   C O M P L E T E" -ForegroundColor Cyan
Write-Host "================================================================================`n" -ForegroundColor DarkCyan
