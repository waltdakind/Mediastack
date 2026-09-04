<#
.SYNOPSIS
    Install-MediaStackUpdate.ps1 - Interactive MediaStack Update Installer & Node Replicator.

.DESCRIPTION
    Prompts the user to confirm installation of the latest MediaStack cluster update package,
    automatically extracts the distribution archive, and executes node bootstrap and lifecycle orchestration.

.PARAMETER ZipPath
    Path to the installer package ZIP file (default: searches dist\, peer network shares, and local backups).

.PARAMETER TargetDir
    Target directory where files will be unpacked (default: current script root).

.PARAMETER Force
    Bypasses the confirmation prompt and immediately applies the update.

.PARAMETER NonInteractive
    Runs fully unattended without interactive confirmation.

.EXAMPLE
    .\Install-MediaStackUpdate.ps1
    .\Install-MediaStackUpdate.ps1 -Force
    .\Install-MediaStackUpdate.ps1 -ZipPath "\\192.168.4.21\MediaStack-Downloads\MediaStack_Cluster_Node_Installer.zip"
#>

[CmdletBinding()]
param(
    [string]$ZipPath = "",
    [string]$TargetDir = "",
    [switch]$Force,
    [switch]$NonInteractive
)

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::InputEncoding  = [System.Text.Encoding]::UTF8

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$BaseDir = $PSScriptRoot
if (-not $TargetDir) { $TargetDir = $BaseDir }

Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host "   M E D I A S T A C K   U P D A T E   &   N O D E   I N S T A L L E R" -ForegroundColor DarkCyan
Write-Host "   Automated Extraction & Node Bootstrap Execution" -ForegroundColor White
Write-Host "   Timestamp: $timestamp" -ForegroundColor DarkGray
Write-Host "================================================================================" -ForegroundColor Cyan

# 1. Locate Latest Distribution Package
if (-not $ZipPath) {
    $searchPaths = @(
        (Join-Path $BaseDir "dist\MediaStack_Cluster_Node_Installer.zip"),
        "\\192.168.4.21\MediaStack-Downloads\MediaStack_Cluster_Node_Installer.zip",
        "\\192.168.4.30\MediaStack-Downloads\MediaStack_Cluster_Node_Installer.zip",
        (Join-Path $BaseDir "backups\MediaStack_Cluster_Node_Installer.zip")
    )

    foreach ($sp in $searchPaths) {
        if (Test-Path $sp) {
            $ZipPath = $sp
            break
        }
    }
}

if (-not $ZipPath -or (-not (Test-Path $ZipPath))) {
    # If no zip found, check if we can build one on the fly
    $packager = Join-Path $BaseDir "New-MediaStackNodePackage.ps1"
    if (Test-Path $packager) {
        Write-Host "  [*] No existing package found. Generating latest installer package..." -ForegroundColor Yellow
        & $packager | Out-Null
        $ZipPath = Join-Path $BaseDir "dist\MediaStack_Cluster_Node_Installer.zip"
    }
}

if (-not $ZipPath -or (-not (Test-Path $ZipPath))) {
    Write-Host "  [ERROR] MediaStack installer archive not found." -ForegroundColor Red
    Write-Host "          Please build a package using .\New-MediaStackNodePackage.ps1 first." -ForegroundColor DarkGray
    return
}

$zipItem = Get-Item $ZipPath
$zipSizeMb = [math]::Round(($zipItem.Length / 1MB), 2)
$zipDate = $zipItem.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")

Write-Host "`nFOUND UPDATE PACKAGE:" -ForegroundColor Green
Write-Host "  * Package File : $($zipItem.FullName)" -ForegroundColor White
Write-Host "  * Package Size : $zipSizeMb MB" -ForegroundColor White
Write-Host "  * Build Date   : $zipDate" -ForegroundColor White
Write-Host "  * Target Path  : $TargetDir" -ForegroundColor White

# 2. Interactive Prompt to User
if (-not $Force -and (-not $NonInteractive)) {
    Write-Host ""
    Write-Host "--------------------------------------------------------------------------------" -ForegroundColor DarkCyan
    Write-Host " Do you want to install this MediaStack update (unzip package & execute node)? [Y/N]: " -NoNewline -ForegroundColor Yellow
    $response = Read-Host
    Write-Host "--------------------------------------------------------------------------------" -ForegroundColor DarkCyan

    if ($response -notmatch '^(y|yes)$') {
        Write-Host "`n[ABORTED] Update installation cancelled by user.`n" -ForegroundColor DarkGray
        return
    }
} else {
    Write-Host "`n[*] Automatically confirmed update installation (-Force / -NonInteractive)." -ForegroundColor Cyan
}

# 3. Unzip and Extract Package
Write-Host "`n[1/2] Extracting Update Archive to $TargetDir..." -ForegroundColor Yellow
try {
    Add-Type -AssemblyName System.IO.Compression.FileSystem

    # Open zip and extract files with overwrite
    $zip = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
    $extractedCount = 0
    foreach ($entry in $zip.Entries) {
        $destinationPath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($TargetDir, $entry.FullName))
        if ($destinationPath.StartsWith($TargetDir, [System.StringComparison]::OrdinalIgnoreCase)) {
            $destDir = [System.IO.Path]::GetDirectoryName($destinationPath)
            if (-not [System.IO.Directory]::Exists($destDir)) {
                [System.IO.Directory]::CreateDirectory($destDir) | Out-Null
            }
            if (-not $entry.FullName.EndsWith("/") -and -not $entry.FullName.EndsWith("\")) {
                # Extract file (overwrite existing)
                [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $destinationPath, $true)
                $extractedCount++
            }
        }
    }
    $zip.Dispose()
    Write-Host "  [OK] Extracted $extractedCount files successfully." -ForegroundColor Green
} catch {
    Write-Host "  [ERROR] Extraction encountered an issue: $($_.Exception.Message)" -ForegroundColor Red
    return
}

# 4. Execute Node Bootstrap
Write-Host "`n[2/2] Launching Node Bootstrap Orchestrator..." -ForegroundColor Yellow
$bootstrapScript = Join-Path $TargetDir "Bootstrap-NewNode.ps1"
if (Test-Path $bootstrapScript) {
    & $bootstrapScript -NonInteractive:$NonInteractive
} else {
    $lifecycleScript = Join-Path $TargetDir "Invoke-MediaStackMainLifecycle.ps1"
    if (Test-Path $lifecycleScript) {
        & $lifecycleScript
    } else {
        Write-Host "  [OK] Update unzipped. You can now run .\s.ps1 to start services." -ForegroundColor Green
    }
}

Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host "   M E D I A S T A C K   U P D A T E   I N S T A L L A T I O N   C O M P L E T E" -ForegroundColor Green
Write-Host "================================================================================`n" -ForegroundColor Cyan
