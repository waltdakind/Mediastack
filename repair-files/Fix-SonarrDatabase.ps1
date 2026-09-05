# ==============================================================================
# Fix-SonarrDatabase.ps1 - Dynamic Sonarr SQLite Database Recovery & Repair
# ==============================================================================
[CmdletBinding()]
param()

$BaseDir = if (Test-Path "$PSScriptRoot\..\docker-compose.yml") { (Resolve-Path "$PSScriptRoot\..").Path } else { $PSScriptRoot }
$sonarrConfigDir = Join-Path $BaseDir "config\sonarr"
$dbPath = Join-Path $sonarrConfigDir "sonarr.db"

if (-not (Test-Path $dbPath)) {
    Write-Host "  [ERR] sonarr.db not found at $dbPath" -ForegroundColor Red
    return
}

$fileTag = Get-Date -Format "yyyyMMdd_HHmmss"
$backupPath = Join-Path $sonarrConfigDir "sonarr.db.bak_$fileTag"

Write-Host "Creating safety backup of Sonarr database..." -ForegroundColor Yellow
Copy-Item -Path $dbPath -Destination $backupPath -Force
Write-Host "  [OK] Safety backup created: $backupPath" -ForegroundColor Green

# 1. Checkpoint WAL and run integrity check via mediastack-db container or alpine
Write-Host "`nInspecting and checkpointing sonarr.db..." -ForegroundColor Cyan
$dockerUp = (docker info 2>&1) -match "Server Version"

if ($dockerUp) {
    # Stop sonarr briefly during database repair to ensure exclusive access
    Write-Host "Temporarily stopping sonarr container..." -ForegroundColor DarkGray
    docker stop sonarr -t 5 2>$null | Out-Null

    # Fold WAL journals and check integrity
    $mountPath = $sonarrConfigDir.Replace("\", "/")
    docker run --rm -v "${mountPath}:/db" alpine sh -c "
        apk add --no-cache sqlite >/dev/null 2>&1
        echo '--- PRAGMA INTEGRITY CHECK ---'
        sqlite3 /db/sonarr.db 'PRAGMA integrity_check;'
        echo '--- CLEANING VERSIONINFO MIGRATIONS ---'
        sqlite3 /db/sonarr.db 'UPDATE VersionInfo SET AppliedOn = \"2024-01-01T00:00:00\" WHERE AppliedOn = \"UpdateSceneMapping\" OR AppliedOn NOT LIKE \"20%\";'
        echo '--- CHECKPOINTING WAL ---'
        sqlite3 /db/sonarr.db 'PRAGMA wal_checkpoint(TRUNCATE);'
        echo '--- VACUUM & REINDEX ---'
        sqlite3 /db/sonarr.db 'REINDEX; PRAGMA optimize;'
        echo '[SQL OK] Sonarr database repair completed.'
    "

    Write-Host "`nRestarting sonarr container..." -ForegroundColor Yellow
    docker start sonarr 2>$null | Out-Null

    Start-Sleep -Seconds 5
    $code = curl.exe -k -s -o NUL -w "%{http_code}" --max-time 6 "http://localhost:8989/ping"
    Write-Host "Sonarr Health Probe Status: $code" -ForegroundColor $(if ($code -eq "200") { "Green" } else { "Yellow" })
} else {
    Write-Host "  [WARN] Docker daemon is not running. Please start Docker and re-run." -ForegroundColor Yellow
}
