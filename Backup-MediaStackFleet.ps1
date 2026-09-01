<#
.SYNOPSIS
    Backup-MediaStackFleet.ps1 - Primary Atomic Backup Orchestrator with Integrity Hashing & Retention.

.DESCRIPTION
    Comprehensive backup orchestrator for the entire MediaStack multi-node cluster:
    1. Stages hot backups of all services (Jellyfin, Servarr, MusicBrainz, Caddy, Syncthing, LiveTV, Jellyseerr, Transmission).
    2. Packages full atomic snapshot into a timestamped compressed ZIP archive in backups/.
    3. Computes SHA-256 cryptographic integrity checksums.
    4. Enforces automated backup retention policy (prunes archives older than PruneDays).
    5. Emits structured backup manifests and audit reports.

.PARAMETER Service
    Target service to back up ("All", "Jellyfin", "MusicBrainz", "Servarr", "Caddy", "Syncthing", "LiveTV", "Jellyseerr", "Transmission", "Secrets"). Default: "All".

.PARAMETER Destination
    Destination directory for backup archives (default: .\backups).

.PARAMETER PruneDays
    Number of days to retain historical backup archives (default: 7).

.EXAMPLE
    .\Backup-MediaStackFleet.ps1 -All
    .\Backup-MediaStackFleet.ps1 -Service Jellyfin
    .\Backup-MediaStackFleet.ps1 -All -PruneDays 14
#>

[CmdletBinding()]
param(
    [ValidateSet("All", "Jellyfin", "MusicBrainz", "Servarr", "Caddy", "Syncthing", "LiveTV", "Jellyseerr", "Transmission", "Secrets")]
    [string]$Service = "All",
    [switch]$All,
    [string]$Destination = "$PSScriptRoot\backups",
    [int]$PruneDays = 7
)

if ($All) { $Service = "All" }

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::InputEncoding  = [System.Text.Encoding]::UTF8

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$fileTag = Get-Date -Format "yyyyMMdd_HHmmss"
$BaseDir = $PSScriptRoot
$HandoffsDir = Join-Path $BaseDir "handoffs"
$StagingRoot = Join-Path $Destination "staging_$fileTag"
$ArchiveName = "MediaStack_FullBackup_${Service}_$fileTag.zip"
$ArchiveFile = Join-Path $Destination $ArchiveName

if (-not (Test-Path $Destination)) { New-Item -ItemType Directory -Force -Path $Destination | Out-Null }
if (-not (Test-Path $HandoffsDir)) { New-Item -ItemType Directory -Force -Path $HandoffsDir | Out-Null }

Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host "   M E D I A S T A C K   M A S T E R   F L E E T   B A C K U P" -ForegroundColor DarkCyan
Write-Host ("   Service: {0} | Destination: {1} | Retention: {2} Days" -f $Service, $Destination, $PruneDays) -ForegroundColor White
Write-Host "================================================================================" -ForegroundColor Cyan

# 1. Stage Services
$stageScript = Join-Path $BaseDir "Backup-ServiceConfigs.ps1"
if (Test-Path $stageScript) {
    & $stageScript -TargetService $Service -StagingDir $StagingRoot
} else {
    Write-Host "  [WARN] Backup-ServiceConfigs.ps1 not found. Creating minimal stage..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Force -Path $StagingRoot | Out-Null
}

# 2. Compress to Atomic ZIP Archive
Write-Host "`n[2/4] Compressing Archive to $ArchiveFile..." -ForegroundColor Yellow
try {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::CreateFromDirectory($StagingRoot, $ArchiveFile, [System.IO.Compression.CompressionLevel]::Optimal, $false)
    $archiveSizeMb = [math]::Round(((Get-Item $ArchiveFile).Length / 1MB), 2)
    Write-Host ("  [OK] Compressed Archive Created: {0} ({1} MB)" -f $ArchiveName, $archiveSizeMb) -ForegroundColor Green
} catch {
    Write-Host "  [ERROR] Compression failed: $($_.Exception.Message)" -ForegroundColor Red
    return
} finally {
    # 3. Clean up staging directory
    if (Test-Path $StagingRoot) {
        Remove-Item -Path $StagingRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# 3. Compute SHA-256 Hash
Write-Host "`n[3/4] Generating Cryptographic SHA-256 Checksum..." -ForegroundColor Yellow
$hash = (Get-FileHash -Path $ArchiveFile -Algorithm SHA256).Hash
Write-Host "  * SHA-256 Hash: $hash" -ForegroundColor Cyan

# 4. Prune Historical Archives
Write-Host "`n[4/4] Enforcing Backup Retention Policy (Purging > $PruneDays days old)..." -ForegroundColor Yellow
$cutoff = (Get-Date).AddDays(-$PruneDays)
$pruned = 0
Get-ChildItem -Path $Destination -Filter "MediaStack_FullBackup_*.zip" -File -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -lt $cutoff } |
    ForEach-Object {
        Remove-Item -Path $_.FullName -Force -ErrorAction SilentlyContinue
        $pruned++
    }
Write-Host "  [OK] Retention enforced: $pruned historical archives pruned." -ForegroundColor Green

# 5. Emit Executive Report
$reportFile = Join-Path $HandoffsDir "MediaStack_Backup_Report_$fileTag.md"
$rep = @"
# MediaStack Fleet Backup Execution Report

| Parameter | Value |
| :--- | :--- |
| **Execution Host** | $($env:COMPUTERNAME) |
| **Target Service** | $Service |
| **Timestamp** | $timestamp |
| **Archive File** | $ArchiveFile |
| **Archive Size** | $archiveSizeMb MB |
| **SHA-256 Checksum** | ````$hash```` |
| **Retention Policy** | Retained ($PruneDays days threshold, $pruned pruned) |

---
*Generated by Backup-MediaStackFleet.ps1.*
"@
Set-Content -Path $reportFile -Value $rep -Encoding UTF8
Write-Host "`n[COMPLETE] Backup operation successful! Manifest: $reportFile`n" -ForegroundColor Green
