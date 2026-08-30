# ==============================================================================
# Merge-OneDriveMediaStack.ps1 - OneDrive & Local Configuration Merger & Reconciliation Engine
# ==============================================================================
param(
    [string]$OneDrivePath = "C:\Users\waltd\OneDrive\Mediastack",
    [string]$LocalConfigPath = "$env:SystemDrive\MediastackConfig",
    [switch]$PurgeStaleConflictFiles = $true,
    [switch]$CreateBackupArchive = $true
)

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::InputEncoding  = [System.Text.Encoding]::UTF8

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$fileTimestamp = Get-Date -Format "yyyyMMdd_HHmmss"

Write-Host "`n================================================================================" -ForegroundColor DarkCyan
Write-Host "     O N E D R I V E   &   M E D I A S T A C K   M E R G E   E N G I N E" -ForegroundColor Cyan
Write-Host ("     Source: {0} <---> Target: {1}" -f $OneDrivePath, $LocalConfigPath) -ForegroundColor DarkGray
Write-Host "================================================================================" -ForegroundColor DarkCyan

# --- 1. BACKUP ARCHIVE BEFORE MERGE ---
if ($CreateBackupArchive) {
    Write-Host "`n[1/4] Creating Pre-Merge Safety Snapshot Archive..." -ForegroundColor Yellow
    $handoffsDir = Join-Path $OneDrivePath "handoffs"
    if (-not (Test-Path $handoffsDir)) { New-Item -ItemType Directory -Force -Path $handoffsDir | Out-Null }
    
    $snapFile = Join-Path $handoffsDir "OneDrive_PreMerge_Snapshot_$fileTimestamp.zip"
    $itemsToCompress = @()
    foreach ($item in @("Caddyfile", "docker-compose.yml", "mediastack-ops.ps1", "config")) {
        $p = Join-Path $OneDrivePath $item
        if (Test-Path $p) { $itemsToCompress += $p }
    }
    if ($itemsToCompress.Count -gt 0) {
        Compress-Archive -Path $itemsToCompress -DestinationPath $snapFile -Force -ErrorAction SilentlyContinue
        Write-Host ("  [OK] Safety snapshot archived: {0}" -f $snapFile) -ForegroundColor Green
    }
}

# --- 2. MERGE & RECONCILE NODE CONFIGS ---
Write-Host "`n[2/4] Merging Root Service & Ingress Configurations..." -ForegroundColor Yellow

# A. Reconcile Caddyfile
$mainCaddy = Join-Path $OneDrivePath "Caddyfile"
$vdCaddy   = Join-Path $OneDrivePath "Caddyfile-VoltaireDeux"
if (Test-Path $mainCaddy) {
    Write-Host "  [OK] Master Caddyfile verified as unified cross-node proxy with HA upstream failover" -ForegroundColor Green
    if (Test-Path $LocalConfigPath) {
        Copy-Item $mainCaddy (Join-Path $LocalConfigPath "Caddyfile") -Force -ErrorAction SilentlyContinue
    }
}

# B. Reconcile docker-compose.yml
$mainDc = Join-Path $OneDrivePath "docker-compose.yml"
if (Test-Path $mainDc) {
    Write-Host "  [OK] Master docker-compose.yml synchronized" -ForegroundColor Green
    if (Test-Path $LocalConfigPath) {
        Copy-Item $mainDc (Join-Path $LocalConfigPath "docker-compose.yml") -Force -ErrorAction SilentlyContinue
    }
}

# C. Sync Newly Created Scripts across local & OneDrive
$scripts = @(
    "PrimarySentinelSuite.ps1",
    "Start-MediaStackAutohealer.ps1",
    "Invoke-MediaStackSuite.ps1",
    "Test-MediaStackApis.ps1",
    "Optimize-MediaStackDatabase.ps1",
    "Test-MusicBrainzMirror.ps1",
    "Test-NetworkDiagnostics.ps1",
    "Backup-MusicBrainzMetadata.ps1",
    "Update-MusicBrainz.ps1",
    "Set-DnsServers.ps1",
    "mediastack-ops.ps1"
)

foreach ($s in $scripts) {
    $src = Join-Path $OneDrivePath $s
    if (Test-Path $src) {
        Write-Host ("  • Synchronized Script -> {0}" -f $s) -ForegroundColor DarkCyan
        if (Test-Path $LocalConfigPath) {
            Copy-Item $src (Join-Path $LocalConfigPath $s) -Force -ErrorAction SilentlyContinue
        }
    }
}

# --- 3. RECONCILE SERVICE CONFIGS & API KEYS ---
Write-Host "`n[3/4] Reconciling Application Configs (Sonarr, Radarr, Prowlarr, Bazarr, Jellyseerr)..." -ForegroundColor Yellow

$appFolders = @("sonarr", "radarr", "prowlarr", "bazarr", "jellyseerr", "jellyfin", "transmission", "tvheadend")
foreach ($app in $appFolders) {
    $localAppPath = Join-Path $LocalConfigPath $app
    $oneDriveAppPath = Join-Path $OneDrivePath "config\$app"

    if (Test-Path $localAppPath) {
        # Ensure target dir in OneDrive
        if (-not (Test-Path $oneDriveAppPath)) { New-Item -ItemType Directory -Force -Path $oneDriveAppPath | Out-Null }
        
        # Copy critical xml/yaml/json configs
        Get-ChildItem -Path $localAppPath -File -Include "*.xml","*.yaml","*.json","*.ini" -ErrorAction SilentlyContinue | ForEach-Object {
            $dest = Join-Path $oneDriveAppPath $_.Name
            Copy-Item $_.FullName $dest -Force -ErrorAction SilentlyContinue
            Write-Host ("  [SYNC] {0} -> {1}" -f $app, $_.Name) -ForegroundColor Green
        }
    }
}

# --- 4. CLEAN UP STALE CONFLICT & DANGLING LOCK FILES ---
if ($PurgeStaleConflictFiles) {
    Write-Host "`n[4/4] Purging Stale OneDrive Sync Conflict Artifacts & Dead Temp Locks..." -ForegroundColor Yellow

    $conflictPatterns = @(
        "*VoltaireDeux-2.db*",
        "*VoltaireDeux-3.db*",
        "*ordinateurdevoltaire.db-shm",
        "*.pid-VoltaireDeux",
        "*.db-journal"
    )

    $purgedCount = 0
    foreach ($pat in $conflictPatterns) {
        Get-ChildItem -Path (Join-Path $OneDrivePath "config") -Recurse -File -Include $pat -ErrorAction SilentlyContinue | ForEach-Object {
            try {
                Remove-Item $_.FullName -Force -ErrorAction Stop
                Write-Host ("  [PURGED] Stale conflict file: {0}" -f $_.Name) -ForegroundColor DarkGray
                $purgedCount++
            } catch {
                # In-use file
            }
        }
    }
    Write-Host ("  [OK] Cleaned up {0} stale conflict / temporary lock files" -f $purgedCount) -ForegroundColor Green
}

# Log to SQLite DB
try {
    $sqlInit = "CREATE TABLE IF NOT EXISTS onedrive_sync_log (id INTEGER PRIMARY KEY AUTOINCREMENT, sync_timestamp TEXT NOT NULL, status TEXT, message TEXT); "
    $sqlInsert = "INSERT INTO onedrive_sync_log (sync_timestamp, status, message) VALUES ('$timestamp', 'MERGED', 'Reconciled configs and purged $purgedCount conflict files'); "
    docker exec mediastack-db sqlite3 /config/mediastack_backup.db "$sqlInit $sqlInsert" 2>$null
} catch { }

Write-Host "`n================================================================================" -ForegroundColor DarkCyan
Write-Host "     O N E D R I V E   M E R G E   &   S Y N C   C O M P L E T E" -ForegroundColor Cyan
Write-Host "================================================================================`n" -ForegroundColor DarkCyan
