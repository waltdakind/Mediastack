$ErrorActionPreference = "Stop"

# Create directories if they don't exist
$dirs = @(
    "$(Split-Path -Parent $PSScriptRoot)\Music",
    "$(Split-Path -Parent $PSScriptRoot)\Videos",
    "$(Split-Path -Parent $PSScriptRoot)\Pictures",
    "$(Split-Path -Parent $PSScriptRoot)\downloads",
    "$PSScriptRoot\documents"
)

foreach ($dir in $dirs) {
    if (-not (Test-Path $dir)) {
        Write-Host "Creating directory: $dir"
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }
}

# Remove existing shares if they exist so we can recreate them with the right permissions cleanly
$shares = Get-SmbShare -ErrorAction SilentlyContinue

$shareNames = @("Public-Music", "Public-Videos", "Public-Pictures", "Public-Downloads", "MediaStack-Documents")

foreach ($share in $shareNames) {
    if ($shares.Name -contains $share) {
        Write-Host "Removing existing share: $share"
        Remove-SmbShare -Name $share -Force
    }
}

Write-Host "Creating SMB Shares..."

New-SmbShare -Name "Public-Music" -Path "$(Split-Path -Parent $PSScriptRoot)\Music" -ReadAccess "Everyone" | Out-Null
Write-Host "Created Public-Music"

New-SmbShare -Name "Public-Videos" -Path "$(Split-Path -Parent $PSScriptRoot)\Videos" -ReadAccess "Everyone" | Out-Null
Write-Host "Created Public-Videos"

New-SmbShare -Name "Public-Pictures" -Path "$(Split-Path -Parent $PSScriptRoot)\Pictures" -ReadAccess "Everyone" | Out-Null
Write-Host "Created Public-Pictures"

New-SmbShare -Name "MediaStack-Documents" -Path "$PSScriptRoot\documents" -ReadAccess "Everyone" | Out-Null
Write-Host "Created MediaStack-Documents"

New-SmbShare -Name "Public-Downloads" -Path "$(Split-Path -Parent $PSScriptRoot)\downloads" -FullAccess "Everyone" | Out-Null
Write-Host "Created Public-Downloads"

# Enable Network Discovery & File Sharing firewall rules
Write-Host "Enabling Firewall Rules for File and Printer Sharing..."
Enable-NetFirewallRule -DisplayGroup "File and Printer Sharing" | Out-Null

Write-Host "Done!"
