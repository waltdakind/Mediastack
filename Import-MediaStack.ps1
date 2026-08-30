param (
    [Parameter(Mandatory=$true)]
    [string]$BackupZipPath,
    
    [string]$DestinationPath = "$PSScriptRoot",
    [string]$NewDataDir = "$(Split-Path -Parent $PSScriptRoot)"
)

$ErrorActionPreference = 'Stop'

Write-Host "Creating destination directory if not exists: $DestinationPath"
if (!(Test-Path -Path $DestinationPath)) {
    New-Item -ItemType Directory -Path $DestinationPath | Out-Null
}

Write-Host "Extracting archive to $DestinationPath..."
Expand-Archive -Path $BackupZipPath -DestinationPath $DestinationPath -Force

$EnvFile = Join-Path $DestinationPath ".env"
if (Test-Path $EnvFile) {
    Write-Host "Updating DATA_DIR in .env to: $NewDataDir"
    $EnvContent = Get-Content $EnvFile
    $NewEnvContent = @()
    $DataDirUpdated = $false
    
    foreach ($line in $EnvContent) {
        if ($line -match "^DATA_DIR=") {
            $NewEnvContent += "DATA_DIR=$NewDataDir"
            $DataDirUpdated = $true
        } else {
            $NewEnvContent += $line
        }
    }
    
    if (-not $DataDirUpdated) {
        $NewEnvContent += "DATA_DIR=$NewDataDir"
    }
    
    $NewEnvContent | Set-Content $EnvFile
} else {
    Write-Host "Warning: .env file not found in the extracted archive."
}

Write-Host "Import completed successfully!"
Write-Host "You can now run 'docker-compose up -d' in $DestinationPath to start your stack."
