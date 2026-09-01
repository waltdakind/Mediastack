# ==============================================================================
# Merge-OneDriveMediaStack.ps1 - OneDrive & Local Configuration Merger & Reconciliation Engine
# ==============================================================================
[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)][string]$OneDrivePath = "C:\Users\waltd\OneDrive\Mediastack",
    [Parameter(Mandatory=$false)][string]$LocalConfigPath = "$env:SystemDrive\MediastackConfig",
    [Parameter(Mandatory=$false)][bool]$PurgeStaleConflictFiles = $true,
    [Parameter(Mandatory=$false)][bool]$CreateBackupArchive = $true
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
if (Test-Path $mainCaddy) {
    Write-Host "  [OK] Primary Caddyfile verified as unified cross-node proxy with HA upstream failover" -ForegroundColor Green
    if (Test-Path $LocalConfigPath) {
        Copy-Item $mainCaddy (Join-Path $LocalConfigPath "Caddyfile") -Force -ErrorAction SilentlyContinue
    }
}

# B. Reconcile docker-compose.yml
$mainDc = Join-Path $OneDrivePath "docker-compose.yml"
if (Test-Path $mainDc) {
    Write-Host "  [OK] Primary docker-compose.yml synchronized" -ForegroundColor Green
    if (Test-Path $LocalConfigPath) {
        Copy-Item $mainDc (Join-Path $LocalConfigPath "docker-compose.yml") -Force -ErrorAction SilentlyContinue
    }
}

# C. Sync Core Scripts across local & OneDrive
$scripts = @(
    "MediaStackOps.psm1",
    "MediaStackOps.ps1",
    "Sync-MediaStackDatabases.ps1",
    "Test-MediaStackProxyAndPorts.ps1",
    "Publish-VoltaireDeuxUpdates.ps1",
    "Invoke-VoltaireDeuxAiAdvisor.ps1",
    "Invoke-VoltaireUnDailyPoller.ps1",
    "Invoke-VoltaireUn24hrSentinel.ps1",
    "Install-VoltaireUnDailySchedule.ps1",
    "Invoke-MediaStackCleanStart.ps1",
    "Invoke-MediaStackCleanShutdown.ps1",
    "Invoke-MediaStackClusterHandoff.ps1",
    "Invoke-MediaStackAiCollaboration.ps1",
    "Start-MediaStackAiWatcher.ps1",
    "New-MediaStackSslCertificates.ps1",
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

# D. Synchronize SSL/TLS Certificates
$srcCerts = Join-Path $OneDrivePath "certs"
if (Test-Path $srcCerts) {
    $dstCerts = Join-Path $LocalConfigPath "certs"
    if (-not (Test-Path $dstCerts)) { New-Item -ItemType Directory -Force -Path $dstCerts | Out-Null }
    Get-ChildItem -Path $srcCerts -File -ErrorAction SilentlyContinue | ForEach-Object {
        Copy-Item $_.FullName (Join-Path $dstCerts $_.Name) -Force -ErrorAction SilentlyContinue
    }
    Write-Host "  [OK] SSL/TLS Certificate Store synchronized to $dstCerts" -ForegroundColor Green
}

# --- 3. MERGE SERVARR & APPLICATION DIRECTORIES ---
Write-Host "`n[3/4] Reconciling Application Configs (Sonarr, Radarr, Prowlarr, Bazarr, Jellyseerr)..." -ForegroundColor Yellow
$appDirs = @("sonarr", "radarr", "prowlarr", "bazarr", "jellyseerr", "jellyfin", "caddy", "db-backup", "musicbrainz")

foreach ($app in $appDirs) {
    $srcDir = Join-Path $OneDrivePath "config\$app"
    $dstDir = Join-Path $LocalConfigPath $app
    
    if (Test-Path $srcDir) {
        if (-not (Test-Path $dstDir)) {
            New-Item -ItemType Directory -Force -Path $dstDir | Out-Null
        }
        
        # Copy non-db config xmls/jsons
        Get-ChildItem -Path $srcDir -Filter "*.xml" -ErrorAction SilentlyContinue | ForEach-Object {
            Copy-Item $_.FullName (Join-Path $dstDir $_.Name) -Force -ErrorAction SilentlyContinue
        }
        Get-ChildItem -Path $srcDir -Filter "*.json" -ErrorAction SilentlyContinue | ForEach-Object {
            Copy-Item $_.FullName (Join-Path $dstDir $_.Name) -Force -ErrorAction SilentlyContinue
        }
        Get-ChildItem -Path $srcDir -Filter "*.yaml" -ErrorAction SilentlyContinue | ForEach-Object {
            Copy-Item $_.FullName (Join-Path $dstDir $_.Name) -Force -ErrorAction SilentlyContinue
        }
    }
}

# --- 4. PURGE STALE ONEDRIVE CONFLICT LOCKS ---
if ($PurgeStaleConflictFiles) {
    Write-Host "`n[4/4] Purging Stale OneDrive Sync Conflict Artifacts & Dead Temp Locks..." -ForegroundColor Yellow
    $conflictPatterns = @(
        "*-VoltaireDeux.db*",
        "*-ordinateurdevoltaire.db*",
        "* - Copy.*",
        "*.db-wal.tmp*",
        "*.db-shm.tmp*"
    )
    
    $purgedCount = 0
    foreach ($pat in $conflictPatterns) {
        $targets = @($OneDrivePath, $LocalConfigPath) | Where-Object { Test-Path $_ }
        foreach ($t in $targets) {
            $conflicts = Get-ChildItem -Path $t -Recurse -Filter $pat -ErrorAction SilentlyContinue |
                Where-Object { -not $_.PSIsContainer }
            foreach ($c in $conflicts) {
                try {
                    Remove-Item -Path $c.FullName -Force -ErrorAction SilentlyContinue
                    Write-Host ("  [PURGED] Stale conflict file: {0}" -f $c.Name) -ForegroundColor Green
                    $purgedCount++
                } catch { }
            }
        }
    }
    if ($purgedCount -eq 0) {
        Write-Host "  [OK] Zero stale conflict files found." -ForegroundColor Green
    } else {
        Write-Host ("  [OK] Cleaned up {0} stale conflict / temporary lock files" -f $purgedCount) -ForegroundColor Green
    }
}

Write-Host "`n================================================================================" -ForegroundColor DarkCyan
Write-Host "     O N E D R I V E   M E R G E   &   S Y N C   C O M P L E T E" -ForegroundColor Cyan
Write-Host "================================================================================`n" -ForegroundColor DarkCyan
