param (
    [string]$DestinationPath = "$PSScriptRoot\backups"
)

$ErrorActionPreference = 'Stop'
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$ArchiveName = "MediaStack_Backup_$Timestamp.zip"
$ArchiveFullName = Join-Path $DestinationPath $ArchiveName

Write-Host "Stopping docker containers to avoid file locks..."
docker compose down

Write-Host "Creating backup directory if not exists: $DestinationPath"
if (!(Test-Path -Path $DestinationPath)) {
    New-Item -ItemType Directory -Path $DestinationPath | Out-Null
}

$SourceDir = "$PSScriptRoot"
$StagingDir = Join-Path $DestinationPath "MediaStack_Staging_$Timestamp"
New-Item -ItemType Directory -Path $StagingDir | Out-Null

$IncludeItems = @(
    "config",
    "dashboard",
    "api-gateway",
    "db-backup",
    "bin",
    "transmission\config",
    ".env",
    "docker-compose.yml",
    "docker-compose.windows.yml",
    "Caddyfile",
    "*.ps1",
    "*.md",
    "*.sh",
    "*.sql",
    "rootfolder.json",
    "sonarr-indexer.json",
    "sonarr-rootfolder.json"
)

Write-Host "Copying configuration files to staging..."
foreach ($item in $IncludeItems) {
    # Check if wildcard
    if ($item -match "\*") {
        $items = Get-ChildItem -Path $SourceDir -Filter $item -ErrorAction SilentlyContinue
        foreach ($match in $items) {
            Copy-Item -Path $match.FullName -Destination $StagingDir -Force
        }
    } else {
        $itemPath = Join-Path $SourceDir $item
        if (Test-Path $itemPath) {
            $destPath = Join-Path $StagingDir $item
            $parentDest = Split-Path $destPath
            if (!(Test-Path $parentDest)) {
                New-Item -ItemType Directory -Path $parentDest | Out-Null
            }
            Copy-Item -Path $itemPath -Destination $destPath -Recurse -Force -ErrorAction Continue -Exclude @(".machinelogs.json", "*.log", "logs")
        }
    }
}

Write-Host "Removing locked agent log files from staging..."
Remove-Item -Path "$StagingDir\*" -Include @(".machinelogs.json", "*.log") -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "Compressing to $ArchiveFullName..."
Compress-Archive -Path $StagingDir -DestinationPath $ArchiveFullName -Force

Write-Host "Cleaning up staging directory..."
Remove-Item -Path $StagingDir -Recurse -Force

Write-Host "Starting docker containers..."
docker compose up -d

Write-Host "Backup completed successfully! Archive located at: $ArchiveFullName"
