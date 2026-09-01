<#
.SYNOPSIS
    New-MediaStackNodePackage.ps1 - Builds Turnkey Distribution ZIP for Replicating MediaStack on New Machines.

.DESCRIPTION
    Packages all required orchestration scripts, Docker compose manifests, Caddyfiles,
    network user & SMB share provisioners, sanitized secrets templates, and 1-click bootstrap
    launchers into a clean, distributable ZIP archive for download and instant execution on new machines.

.PARAMETER OutputPath
    Target path for the generated ZIP package (default: dist\MediaStack_Cluster_Node_Installer.zip).

.PARAMETER IncludeLiveSecrets
    If specified, includes local secrets.json into the package (CAUTION: keep archive private).

.EXAMPLE
    .\New-MediaStackNodePackage.ps1
    .\New-MediaStackNodePackage.ps1 -IncludeLiveSecrets
#>

[CmdletBinding()]
param(
    [string]$OutputPath = "",
    [switch]$IncludeLiveSecrets
)

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::InputEncoding  = [System.Text.Encoding]::UTF8

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$fileTimestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$BaseDir = $PSScriptRoot

if (-not $OutputPath) {
    $distDir = Join-Path $BaseDir "dist"
    if (-not (Test-Path $distDir)) { New-Item -ItemType Directory -Force -Path $distDir | Out-Null }
    $OutputPath = Join-Path $distDir "MediaStack_Cluster_Node_Installer.zip"
} else {
    $parentDir = Split-Path -Parent $OutputPath
    if ($parentDir -and (-not (Test-Path $parentDir))) { New-Item -ItemType Directory -Force -Path $parentDir | Out-Null }
}

Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host "   M E D I A S T A C K   D I S T R I B U T I O N   P A C K A G E R" -ForegroundColor DarkCyan
Write-Host "   Creating Turnkey Cluster Replicator ZIP for New Machines" -ForegroundColor White
Write-Host "   Timestamp: $timestamp | Destination: $OutputPath" -ForegroundColor DarkGray
Write-Host "================================================================================" -ForegroundColor Cyan

$stagingDir = Join-Path $BaseDir "staging_dist_$fileTimestamp"
if (Test-Path $stagingDir) { Remove-Item -Path $stagingDir -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Force -Path $stagingDir | Out-Null

try {
    Write-Host "`n[1/4] Staging Orchestration Scripts & Bootstrap Launchers..." -ForegroundColor Yellow

    $rootFiles = @(
        "bootstrap.bat",
        "Bootstrap-NewNode.ps1",
        "Set-MediaStackNetworkUsers.ps1",
        "Mount-MediaStackNetworkShares.ps1",
        "Invoke-MediaStackMainLifecycle.ps1",
        "Test-MediaStackApis.ps1",
        "Sync-MediaStackSecrets.ps1",
        "Get-PicardApiKey.ps1",
        "Set-PicardLocalMirror.ps1",
        "Picard-Main-Tagging.txt",
        "s.ps1",
        "s-v1.ps1",
        "s-v2.ps1",
        "Start-VoltaireUn.ps1",
        "Start-VoltaireUnMainExecution.ps1",
        "Start-VoltaireDeux.ps1",
        "Start-VoltaireDeuxMainExecution.ps1",
        "Optimize-DualNodeLcp.ps1",
        "Repair-JellyfinServer.ps1",
        "Merge-OneDriveMediaStack.ps1",
        "Set-MediaStackHostSafeguards.ps1",
        "setup-shares.ps1",
        "Caddyfile",
        "Caddyfile-VoltaireDeux",
        "Caddyfile-VoltaireDeux-2",
        "docker-compose.yml",
        "docker-compose.x64.yml",
        "docker-compose.x64-VoltaireDeux.yml",
        "docker-compose.arm.yml",
        "SERVICE_SETUP.md",
        "SERVICES_OVERVIEW.md"
    )

    foreach ($rf in $rootFiles) {
        $srcPath = Join-Path $BaseDir $rf
        if (Test-Path $srcPath) {
            Copy-Item -Path $srcPath -Destination $stagingDir -Force
        }
    }

    Write-Host "`n[2/4] Staging Modular Sub-Stacks & Templates..." -ForegroundColor Yellow

    # Copy subdirectories
    $subDirs = @("api-gateway", "dashboard", "bin", "certs")
    foreach ($sd in $subDirs) {
        $src = Join-Path $BaseDir $sd
        if (Test-Path $src) {
            $dst = Join-Path $stagingDir $sd
            Copy-Item -Path $src -Destination $dst -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    # Staging MusicBrainz Sub-Stack manifests (without huge pgdata dumps)
    $mbDir = Join-Path $BaseDir "musicbrainz-docker"
    if (Test-Path $mbDir) {
        $dstMb = Join-Path $stagingDir "musicbrainz-docker"
        New-Item -ItemType Directory -Force -Path $dstMb | Out-Null
        $mbFiles = Get-ChildItem -Path $mbDir -File -Include @("*.yml", "*.yaml", "*.env*", "*.md", "*.txt", "*.sh", "*.ps1") -ErrorAction SilentlyContinue
        foreach ($mf in $mbFiles) {
            Copy-Item -Path $mf.FullName -Destination $dstMb -Force
        }
        $composeDir = Join-Path $mbDir "compose"
        if (Test-Path $composeDir) {
            Copy-Item -Path $composeDir -Destination (Join-Path $dstMb "compose") -Recurse -Force -ErrorAction SilentlyContinue
        }
        $secretsMb = Join-Path $dstMb "local\secrets"
        New-Item -ItemType Directory -Force -Path $secretsMb | Out-Null
    }

    # Staging Secrets Directory
    $dstSec = Join-Path $stagingDir "config\secrets"
    New-Item -ItemType Directory -Force -Path $dstSec | Out-Null
    Copy-Item -Path (Join-Path $BaseDir "config\secrets\secrets.example.json") -Destination $dstSec -Force -ErrorAction SilentlyContinue
    Copy-Item -Path (Join-Path $BaseDir "config\secrets\secrets.example.env") -Destination $dstSec -Force -ErrorAction SilentlyContinue

    if ($IncludeLiveSecrets) {
        Copy-Item -Path (Join-Path $BaseDir "config\secrets\secrets.json") -Destination $dstSec -Force -ErrorAction SilentlyContinue
        Copy-Item -Path (Join-Path $BaseDir "config\secrets\secrets.env") -Destination $dstSec -Force -ErrorAction SilentlyContinue
        Write-Host "  [LIVE SECRETS INCLUDED] Added active secrets.json to distribution archive." -ForegroundColor Yellow
    }

    # Create README-NEW-NODE.md inside archive
    $readmeLines = @(
        "# MediaStack Cluster Node Installation Guide",
        "",
        "Welcome to your new MediaStack node.",
        "",
        "## Quick Setup (1-Click)",
        "1. Right-click `bootstrap.bat` -> **Run as Administrator** (or run `.\Bootstrap-NewNode.ps1` in an elevated PowerShell).",
        "2. The installer will automatically:",
        "   - Create local `mediasync`, `voltaireun`, and `voltairedeux` network service accounts.",
        "   - Create and grant Read-Write access to media folders (`Music`, `TV`, `Videos`, `Radio`, `Podcasts`).",
        "   - Configure SMB network shares (`\\<hostname>\\Public-Music`, etc.).",
        "   - Connect and mount peer shares from `VoltaireUn` (192.168.4.21) and `VoltaireDeux` (192.168.4.30).",
        "   - Launch Caddy and Docker containers.",
        "",
        "## Quick Management Menu",
        "Run `.\\s.ps1` to open the interactive single-key HUD.",
        ""
    )
    Set-Content -Path (Join-Path $stagingDir "README-NEW-NODE.md") -Value ($readmeLines -join "`n") -Encoding UTF8

    Write-Host "`n[3/4] Compressing Archive to $OutputPath..." -ForegroundColor Yellow
    if (Test-Path $OutputPath) { Remove-Item -Path $OutputPath -Force -ErrorAction SilentlyContinue }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::CreateFromDirectory($stagingDir, $OutputPath, [System.IO.Compression.CompressionLevel]::Optimal, $false)

    $sizeMb = [math]::Round(((Get-Item $OutputPath).Length / 1MB), 2)
    Write-Host "`n[4/4] Cleaning Up Staging Files..." -ForegroundColor Yellow
    Remove-Item -Path $stagingDir -Recurse -Force -ErrorAction SilentlyContinue

    Write-Host "`n================================================================================" -ForegroundColor Cyan
    Write-Host "   P A C K A G E   C R E A T I O N   S U C C E S S F U L" -ForegroundColor Green
    Write-Host "================================================================================" -ForegroundColor Cyan
    Write-Host "  * Output Archive: $OutputPath" -ForegroundColor White
    Write-Host "  * Archive Size  : $sizeMb MB" -ForegroundColor White
    Write-Host "  * Ready for download, unzipping, and execution on any network machine." -ForegroundColor Green
    Write-Host "================================================================================`n" -ForegroundColor Cyan
} catch {
    Write-Host "  [ERROR] Packaging failed: $($_.Exception.Message)" -ForegroundColor Red
    if (Test-Path $stagingDir) { Remove-Item -Path $stagingDir -Recurse -Force -ErrorAction SilentlyContinue }
}
