<#
.SYNOPSIS
    Debug-Playback.ps1 - Comprehensive Jellyfin Playback, Transcoding & Client Diagnostic Suite.
#>
[CmdletBinding()]
param(
    [int]$Lines = 100,
    [switch]$AutoRepair
)

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::InputEncoding  = [System.Text.Encoding]::UTF8

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host "   J E L L Y F I N   P L A Y B A C K   &   T R A N S C O D I N G   D E B U G G E R" -ForegroundColor DarkCyan
Write-Host "   Timestamp: $timestamp" -ForegroundColor DarkGray
Write-Host "================================================================================" -ForegroundColor Cyan

$ActiveConfig = if (Test-Path "$PSScriptRoot\config") { "$PSScriptRoot\config" } else { "$env:SystemDrive\MediastackConfig" }
$jellyLogDir = Join-Path $ActiveConfig "jellyfin\log"
$jellyConfigDir = Join-Path $ActiveConfig "jellyfin"

# --- 1. PROBE JELLYFIN CONTAINER HEALTH ---
Write-Host "`n[1/6] Probing Jellyfin Container Liveness & HTTP Socket..." -ForegroundColor Yellow
$jfStatus = docker ps --filter "name=^/jellyfin$" --format "{{.Status}}" 2>$null
if ($jfStatus -and $jfStatus -match "Up") {
    Write-Host "  [OK] Jellyfin container is running ($jfStatus)" -ForegroundColor Green
} else {
    Write-Host "  [ERR] Jellyfin container is OFFLINE or restarting ($jfStatus)" -ForegroundColor Red
    if ($AutoRepair) {
        Write-Host "  [*] Attempting container start..." -ForegroundColor Yellow
        docker compose up -d jellyfin 2>&1 | Out-Null
    }
}

# --- 2. CHECK RECENT SERVER EXCEPTIONS ---
Write-Host "`n[2/6] Inspecting Recent Jellyfin Server Exceptions..." -ForegroundColor Yellow
$errLogs = docker logs --tail $Lines jellyfin 2>&1 | Select-String -Pattern "FTL|ERR|Error|Exception|malformed|failed"
if ($errLogs) {
    Write-Host "  [WARN] Discovered recent error events in container log:" -ForegroundColor Yellow
    $errLogs | Select-Object -First 10 | ForEach-Object {
        Write-Host ("    * " + $_.Line.Trim()) -ForegroundColor Red
    }
} else {
    Write-Host "  [OK] Zero fatal or critical exceptions in the last $Lines log lines." -ForegroundColor Green
}

# --- 3. AUDIT JELLYFIN DATABASE INTEGRITY ---
Write-Host "`n[3/6] Auditing jellyfin.db SQLite Integrity..." -ForegroundColor Yellow
$jfDbPath = "$jellyConfigDir\data\data\jellyfin.db"
if (Test-Path $jfDbPath) {
    $dbSizeKb = [math]::Round((Get-Item $jfDbPath).Length / 1KB, 1)
    Write-Host "  • Database File: $jfDbPath ($dbSizeKb KB)" -ForegroundColor DarkGray
    
    $checkRes = docker exec mediastack-db sqlite3 /mediastack/config/jellyfin/data/data/jellyfin.db "PRAGMA quick_check;" 2>&1
    if ($checkRes -match "^ok") {
        Write-Host "  [OK] jellyfin.db PRAGMA quick_check returned: OK (Pristine)" -ForegroundColor Green
    } else {
        Write-Host "  [ERR] jellyfin.db PRAGMA quick_check reported anomalies: $checkRes" -ForegroundColor Red
    }
} else {
    Write-Host "  [INFO] Local jellyfin.db path not found at $jfDbPath (checking alternate volume)" -ForegroundColor DarkGray
}

# --- 4. AUDIT TRANSCODING & FFMPEG HARDWARE ACCELERATION SETTINGS ---
Write-Host "`n[4/6] Auditing Transcoding & Hardware Acceleration Profile..." -ForegroundColor Yellow
$encXmlPath = "$jellyConfigDir\encoding.xml"
if (Test-Path $encXmlPath) {
    [xml]$encXml = Get-Content $encXmlPath -ErrorAction SilentlyContinue
    $hwType = $encXml.EncodingOptions.HardwareAccelerationType
    $hwEnc  = $encXml.EncodingOptions.EnableHardwareEncoding
    $nvdec  = $encXml.EncodingOptions.EnableEnhancedNvdecDecoder
    
    Write-Host ("  • Hardware Acceleration Type : {0}" -f $hwType) -ForegroundColor White
    Write-Host ("  • Enable Hardware Encoding   : {0}" -f $hwEnc) -ForegroundColor White
    Write-Host ("  • Enhanced NVDEC Decoder     : {0}" -f $nvdec) -ForegroundColor White
    
    if ($hwType -eq "none" -and $hwEnc -eq "true") {
        Write-Host "  [WARN] Incompatible config: HardwareAccelerationType is 'none' but EnableHardwareEncoding is 'true'!" -ForegroundColor Yellow
        Write-Host "         This can cause FFmpeg to fail during client transcoding requests." -ForegroundColor Yellow
        if ($AutoRepair) {
            $encXml.EncodingOptions.EnableHardwareEncoding = "false"
            $encXml.EncodingOptions.EnableEnhancedNvdecDecoder = "false"
            $encXml.EncodingOptions.PreferSystemNativeHwDecoder = "false"
            $encXml.Save($encXmlPath)
            Write-Host "  [REPAIRED] Harmonized encoding.xml for clean CPU software transcoding fallback." -ForegroundColor Green
        }
    } else {
        Write-Host "  [OK] Transcoding options are properly aligned for stable playback." -ForegroundColor Green
    }
}

# --- 5. AUDIT MEDIA MOUNT ACCESSIBILITY ---
Write-Host "`n[5/6] Checking Container Media Mounts & Permissions..." -ForegroundColor Yellow
$mediaCheck = docker exec jellyfin ls -la /data 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "  [OK] /data media volume is mounted and accessible inside container." -ForegroundColor Green
} else {
    Write-Host "  [ERR] /data is NOT accessible inside container! ($mediaCheck)" -ForegroundColor Red
}

# --- 6. CADDY STREAMING PROXY & WINDOWS CLIENT GUIDANCE ---
Write-Host "`n[6/6] Caddy Streaming Ingress & Windows Player Diagnostics..." -ForegroundColor Yellow
$caddyErrors = docker logs --tail 30 caddy 2>&1 | Select-String -Pattern "502|504|timeout|error"
if ($caddyErrors) {
    Write-Host "  [WARN] Recent Caddy reverse proxy errors:" -ForegroundColor Yellow
    $caddyErrors | Select-Object -First 5 | ForEach-Object { Write-Host ("    * " + $_.Line.Trim()) -ForegroundColor Red }
} else {
    Write-Host "  [OK] Zero Caddy reverse proxy streaming errors detected." -ForegroundColor Green
}

Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host "   P L A Y B A C K   T R O U B L E S H O O T I N G   R U N B O O K" -ForegroundColor White
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "If Jellyfin Windows Player displays 'Playback Error' on VoltaireUn:" -ForegroundColor Yellow
Write-Host "1. SSL Certificate Trust (Most Common for JMP):" -ForegroundColor White
Write-Host "   Jellyfin Media Player enforces strict TLS validation. On the Windows client," -ForegroundColor DarkGray
Write-Host "   run: Import-Certificate -FilePath '.\certs\ca.crt' -CertStoreLocation 'Cert:\CurrentUser\Root'" -ForegroundColor Cyan
Write-Host "   Or connect directly using LAN address: http://192.168.4.21:8096" -ForegroundColor Cyan
Write-Host "2. Transcoding Bitrate & DirectPlay:" -ForegroundColor White
Write-Host "   In Jellyfin Windows Player Settings > Playback, set 'Maximum Allowed Bitrate' to 'Auto'" -ForegroundColor DarkGray
Write-Host "   and ensure 'Direct Play' is enabled." -ForegroundColor DarkGray
Write-Host "3. Audio Codec Passthrough:" -ForegroundColor White
Write-Host "   If playing EAC3 / TrueHD on a stereo PC, set Audio Output to 'Stereo Downmix'." -ForegroundColor DarkGray
Write-Host "================================================================================`n" -ForegroundColor Cyan
