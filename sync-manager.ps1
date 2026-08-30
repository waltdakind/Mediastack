param([switch]$DryRun)
$Source = "C:\Users\Public\MediaStack"
$Dest = "C:\Users\waltd\OneDrive\Mediastack"
Write-Host "Starting sync from $Source to $Dest" -ForegroundColor Cyan

$Exclude = @("*.db", "*.db-shm", "*.db-wal", "logs", "*.log", "backups", "data", ".machinelogs.json", ".env")

if ($DryRun) {
    Write-Host "[DRY RUN] Would copy files..." -ForegroundColor Yellow
    Copy-Item -Path "$Source\*" -Destination $Dest -Recurse -Force -Exclude $Exclude -WhatIf
} else {
    Copy-Item -Path "$Source\*" -Destination $Dest -Recurse -Force -Exclude $Exclude
    Write-Host "Sync Complete!" -ForegroundColor Green
}
