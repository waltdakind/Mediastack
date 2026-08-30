<#
.SYNOPSIS
    Creates a snapshot backup of current MediaStack configuration files and settings.

.DESCRIPTION
    Backs up Caddyfile, .env*, docker-compose*.yml, scripts, and service definitions
    into a timestamped .zip archive in the backups directory without taking down containers.

.PARAMETER DestinationPath
    Destination directory for the archive (default: .\backups).

.EXAMPLE
    .\Backup-MediaStackConfig.ps1
#>

[CmdletBinding()]
param (
    [string]$DestinationPath = "$PSScriptRoot\backups"
)

$ErrorActionPreference = 'Stop'
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$ArchiveName = "MediaStack_Backup_$Timestamp.zip"
$ArchiveFullName = Join-Path $DestinationPath $ArchiveName

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   MediaStack Live Configuration Snapshot" -ForegroundColor White
Write-Host "==========================================================" -ForegroundColor Cyan

if (!(Test-Path -Path $DestinationPath)) {
    New-Item -ItemType Directory -Path $DestinationPath | Out-Null
}

$SourceDir = "$PSScriptRoot"
$StagingDir = Join-Path $DestinationPath "MediaStack_Staging_$Timestamp"
New-Item -ItemType Directory -Path $StagingDir | Out-Null

$IncludeFiles = @(
    ".env*",
    "env.*",
    "docker-compose*.yml",
    "Caddyfile*",
    "*.ps1",
    "*.sh",
    "*.md",
    "*.json",
    "*.sql"
)

$IncludeDirs = @(
    "api-gateway",
    "dashboard",
    "bin",
    "certs",
    "db-backup"
)

Write-Host "`n[1/3] Copying core configuration files and scripts..." -ForegroundColor Yellow
foreach ($pattern in $IncludeFiles) {
    $matchedFiles = Get-ChildItem -Path $SourceDir -Filter $pattern -File -ErrorAction SilentlyContinue
    foreach ($file in $matchedFiles) {
        Copy-Item -Path $file.FullName -Destination $StagingDir -Force
    }
}

foreach ($subDir in $IncludeDirs) {
    $subDirPath = Join-Path $SourceDir $subDir
    if (Test-Path $subDirPath) {
        $destSubDir = Join-Path $StagingDir $subDir
        Copy-Item -Path $subDirPath -Destination $destSubDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Copy specific XML / YAML / INI config files from config/ without copying huge media/cache folders
$configDir = Join-Path $SourceDir "config"
if (Test-Path $configDir) {
    $destConfigDir = Join-Path $StagingDir "config"
    New-Item -ItemType Directory -Path $destConfigDir -Force | Out-Null
    
    $configFiles = Get-ChildItem -Path $configDir -Recurse -Include @("*.xml", "*.json", "*.yaml", "*.yml", "*.ini", "*.conf") -ErrorAction SilentlyContinue |
                   Where-Object { $_.FullName -notmatch "cache|transcode|metadata|logs" }
    
    foreach ($cfg in $configFiles) {
        $relPath = $cfg.FullName.Substring($configDir.Length + 1)
        $targetFilePath = Join-Path $destConfigDir $relPath
        $targetFileDir = Split-Path $targetFilePath
        if (!(Test-Path $targetFileDir)) {
            New-Item -ItemType Directory -Path $targetFileDir -Force | Out-Null
        }
        Copy-Item -Path $cfg.FullName -Destination $targetFilePath -Force
    }
}

Write-Host "[2/3] Compressing backup to $ArchiveFullName..." -ForegroundColor Yellow
Compress-Archive -Path $StagingDir\* -DestinationPath $ArchiveFullName -Force

Write-Host "[3/3] Cleaning up temporary files..." -ForegroundColor Yellow
Remove-Item -Path $StagingDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host "   Backup Completed Successfully!" -ForegroundColor Green
Write-Host "   Archive: $ArchiveFullName" -ForegroundColor White
Write-Host "==========================================================" -ForegroundColor Cyan
