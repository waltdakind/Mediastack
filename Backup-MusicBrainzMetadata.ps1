# ==============================================================================
# Backup-MusicBrainzMetadata.ps1 - Automated Metadata Backup to Local SQLite DB & Filesystem
# ==============================================================================

[CmdletBinding()]
param(
    [string]$ConfigDir = "$env:SystemDrive\MediastackConfig",
    [string]$PicardIniPath = "$env:APPDATA\MusicBrainz\Picard.ini",
    [switch]$DetailedDump
)

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::InputEncoding  = [System.Text.Encoding]::UTF8

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$fileTimestamp = Get-Date -Format "yyyyMMdd_HHmmss"

Write-Host "`n=======================================================" -ForegroundColor Cyan
Write-Host "   M U S I C B R A I N Z   M E T A D A T A   B A C K U P" -ForegroundColor Cyan
Write-Host "   Timestamp: $timestamp" -ForegroundColor DarkGray
Write-Host "=======================================================" -ForegroundColor Cyan

# 1. Resolve Backup Paths
$dbBackupDir = Join-Path $ConfigDir "db-backup"
if (-not (Test-Path $dbBackupDir)) {
    New-Item -ItemType Directory -Force -Path $dbBackupDir | Out-Null
}

Write-Host "[1/4] Inspecting Local MusicBrainz Database Container..." -ForegroundColor Yellow
$dbRunning = (docker ps --filter "name=musicbrainz-docker-db-1" --format "{{.Status}}")

$schemaSeq = "Unknown"
$lastReplication = "Unknown"
$artistCount = 0
$releaseCount = 0
$status = "Online"

if ($dbRunning) {
    Write-Host "  MusicBrainz Postgres is active. Querying replication & catalog metadata..." -ForegroundColor Green
    try {
        $repInfo = docker exec musicbrainz-docker-db-1 psql -U musicbrainz -d musicbrainz -t -A -F "|" -c "SELECT current_schema_sequence, last_replication_date FROM replication_control LIMIT 1;" 2>$null
        if ($repInfo) {
            $parts = $repInfo.Split("|")
            $schemaSeq = $parts[0].Trim()
            if ($parts.Length -gt 1) { $lastReplication = $parts[1].Trim() }
            Write-Host "  Schema Sequence: $schemaSeq | Last Replication: $lastReplication" -ForegroundColor DarkCyan
        }
    } catch { }

    try {
        $stats = docker exec musicbrainz-docker-db-1 psql -U musicbrainz -d musicbrainz -t -A -F "|" -c "SELECT (SELECT count(*) FROM artist), (SELECT count(*) FROM release);" 2>$null
        if ($stats) {
            $parts = $stats.Split("|")
            $artistCount = [int]($parts[0].Trim())
            if ($parts.Length -gt 1) { $releaseCount = [int]($parts[1].Trim()) }
            Write-Host "  Artist Count: $artistCount | Release Count: $releaseCount" -ForegroundColor DarkCyan
        }
    } catch { }
} else {
    Write-Host "  MusicBrainz DB is not currently running. Logging offline state." -ForegroundColor Yellow
    $status = "Offline"
}

# 2. Extract Picard Configuration Metadata
Write-Host "`n[2/4] Capturing Picard Client Configuration & OAuth Tokens..." -ForegroundColor Yellow
$picardUser = "Unknown"
$picardHost = "192.168.4.30"
$picardPort = "5001"
$acoustidKey = ""

if (Test-Path $PicardIniPath) {
    $iniLines = Get-Content $PicardIniPath
    foreach ($line in $iniLines) {
        if ($line -match '^oauth_username=(.*)$') { $picardUser = $matches[1].Trim() }
        if ($line -match '^server_host=(.*)$') { $picardHost = $matches[1].Trim() }
        if ($line -match '^server_port=(.*)$') { $picardPort = $matches[1].Trim() }
        if ($line -match '^acoustid_apikey=(.*)$') { $acoustidKey = $matches[1].Trim() }
    }
    Write-Host "  Captured Picard config for user '$picardUser' pointing to ${picardHost}:${picardPort}" -ForegroundColor Green
}

# 3. Write Snapshot into Local SQLite DB (mediastack-db)
Write-Host "`n[3/4] Ingesting Metadata Records into Local SQLite Database..." -ForegroundColor Yellow

$sqlInit = @"
CREATE TABLE IF NOT EXISTS musicbrainz_metadata_backup (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    backup_timestamp TEXT NOT NULL,
    status TEXT,
    schema_sequence TEXT,
    last_replication_date TEXT,
    artist_count INTEGER,
    release_count INTEGER,
    picard_user TEXT,
    picard_host TEXT,
    picard_port TEXT,
    acoustid_key_configured INTEGER
);
"@

# Initialize tables inside mediastack-db container
docker exec mediastack-db sqlite3 /config/mediastack_backup.db "$sqlInit"

$hasAcoustid = if ($acoustidKey) { 1 } else { 0 }
$sqlInsert = "INSERT INTO musicbrainz_metadata_backup (backup_timestamp, status, schema_sequence, last_replication_date, artist_count, release_count, picard_user, picard_host, picard_port, acoustid_key_configured) VALUES ('$timestamp', '$status', '$schemaSeq', '$lastReplication', $artistCount, $releaseCount, '$picardUser', '$picardHost', '$picardPort', $hasAcoustid);"

docker exec mediastack-db sqlite3 /config/mediastack_backup.db "$sqlInsert"
Write-Host "  [OK] Successfully recorded MusicBrainz metadata row into /config/mediastack_backup.db" -ForegroundColor Green

# 4. Generate Snapshot Backup File for Restore Engine
Write-Host "`n[4/4] Generating Standalone Snapshot for MediaStack Restore Engine..." -ForegroundColor Yellow
$exportSql = @"
$sqlInit
$sqlInsert
"@
Set-Content -Path (Join-Path $dbBackupDir "musicbrainz_$fileTimestamp.sql") -Value $exportSql -Encoding UTF8
docker exec mediastack-db sqlite3 "/config/musicbrainz_$fileTimestamp.sqlite3" "$exportSql"

Write-Host "  [OK] Snapshot created: $dbBackupDir\musicbrainz_$fileTimestamp.sqlite3" -ForegroundColor Green

Write-Host "`n=======================================================" -ForegroundColor Cyan
Write-Host "   M E T A D A T A   B A C K U P   C O M P L E T E" -ForegroundColor Cyan
Write-Host "=======================================================`n" -ForegroundColor Cyan
