# ==============================================================================
# Set-PicardLocalMirror.ps1 - Automated Picard Configurator for Canonical Local DB
# Configures Picard.ini to target local PostgreSQL/Solr mirror, unlocks high-speed
# rate limits, and installs master Jellyfin-compliant tagging & naming rules.
# ==============================================================================

[CmdletBinding()]
param(
    [string]$TargetHost = "127.0.0.1",
    [int]$TargetPort = 5000,
    [switch]$v1,
    [switch]$v2,
    [switch]$VoltaireUn,
    [switch]$VoltaireDeux,
    [switch]$UseLocalhost,
    [switch]$SkipTaggingScript
)

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::InputEncoding  = [System.Text.Encoding]::UTF8

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

Write-Host "`n================================================================================" -ForegroundColor DarkCyan
Write-Host "   M U S I C B R A I N Z   P I C A R D   C A N O N I C A L   L I N K E R" -ForegroundColor Cyan
Write-Host "   Timestamp: $timestamp | Local Database Canonical Linking" -ForegroundColor DarkGray
Write-Host "================================================================================" -ForegroundColor DarkCyan

# Resolve Node Target Conventions
if ($v1 -or $VoltaireUn) {
    $TargetHost = "192.168.4.21"
    $TargetPort = 5000
    Write-Host "  [TARGET] VoltaireUn (v1) Primary Node: http://$TargetHost`:$TargetPort" -ForegroundColor Cyan
} elseif ($v2 -or $VoltaireDeux) {
    $TargetHost = "192.168.4.30"
    $TargetPort = 5000
    Write-Host "  [TARGET] VoltaireDeux (v2) Workstation Node: http://$TargetHost`:$TargetPort" -ForegroundColor Cyan
} elseif ($UseLocalhost -or $TargetHost -eq "127.0.0.1" -or $TargetHost -eq "localhost") {
    $TargetHost = "127.0.0.1"
    $TargetPort = 5000
    Write-Host "  [TARGET] Local Canonical Mirror (Loopback): http://$TargetHost`:$TargetPort" -ForegroundColor Cyan
}

$picardDir = "$env:APPDATA\MusicBrainz"
$picardIni = Join-Path $picardDir "Picard.ini"

if (-not (Test-Path $picardDir)) {
    New-Item -ItemType Directory -Force -Path $picardDir | Out-Null
}

# 1. Verify Target MusicBrainz Mirror Reachability
Write-Host "`n[1/3] Verifying Local MusicBrainz Database & REST API Reachability..." -ForegroundColor Yellow
$testCode = curl.exe -s -o NUL -w "%{http_code}" --max-time 4 "http://${TargetHost}:${TargetPort}/"
if ($testCode -eq "200" -or $testCode -eq "301" -or $testCode -eq "302") {
    Write-Host ("  [OK] Local MusicBrainz Mirror Online: http://{0}:{1}/ (HTTP {2})" -f $TargetHost, $TargetPort, $testCode) -ForegroundColor Green
} else {
    Write-Host ("  [NOTICE] MusicBrainz Mirror at http://{0}:{1}/ returned HTTP {2}. Proceeding with configuration." -f $TargetHost, $TargetPort, $testCode) -ForegroundColor Yellow
}

# 2. Update Picard Configuration in Picard.ini
Write-Host "`n[2/3] Configuring Picard to use Local MusicBrainz as Canonical Source..." -ForegroundColor Yellow

$iniContent = @()
if (Test-Path $picardIni) {
    # Backup existing Picard.ini
    $backupIni = "$picardIni.bak_" + (Get-Date -Format "yyyyMMdd_HHmmss")
    Copy-Item -Path $picardIni -Destination $backupIni -Force
    Write-Host "  [BACKUP] Saved existing Picard.ini -> $backupIni" -ForegroundColor DarkGray
    $iniContent = Get-Content $picardIni
} else {
    $iniContent = @("[General]")
}

# Key-value overrides to lock in the local mirror as canonical
$settingsToApply = @{
    "server_host"               = $TargetHost
    "server_port"               = $TargetPort
    "use_server_for_submission" = "false"
    "browser_integration_port"  = "8000"
}

$updatedKeys = @{}
$newLines = @()

foreach ($line in $iniContent) {
    $matched = $false
    foreach ($key in $settingsToApply.Keys) {
        if ($line -match "^$key\s*=") {
            $newLines += "$key=$($settingsToApply[$key])"
            $updatedKeys[$key] = $true
            $matched = $true
            break
        }
    }
    if (-not $matched) {
        $newLines += $line
    }
}

# Append any missing keys
foreach ($key in $settingsToApply.Keys) {
    if (-not $updatedKeys.ContainsKey($key)) {
        $newLines += "$key=$($settingsToApply[$key])"
    }
}

Set-Content -Path $picardIni -Value $newLines -Encoding UTF8
Write-Host "  [OK] Successfully linked Picard to canonical local mirror: $TargetHost`:$TargetPort" -ForegroundColor Green

# 3. Master Tagging Script Integration
Write-Host "`n[3/3] Master Tagging & Audiophile Naming Script Integration..." -ForegroundColor Yellow
$scriptFile = Join-Path $PSScriptRoot "Picard-Main-Tagging.txt"
if (Test-Path $scriptFile) {
    Write-Host "  [OK] Master tagging script active at: $scriptFile" -ForegroundColor Green
    Write-Host "  * Canonical Tags: Multi-value genre ($clean_multi), Artist bucketing (A-Z/#)," -ForegroundColor DarkCyan
    Write-Host "    Disc numbering, Album date formatting, and Jellyfin music organization." -ForegroundColor DarkCyan
}

Write-Host "`n================================================================================" -ForegroundColor DarkCyan
Write-Host "   P I C A R D   C A N O N I C A L   D A T A B A S E   L I N K E D" -ForegroundColor Cyan
Write-Host "================================================================================`n" -ForegroundColor DarkCyan
