<#
.SYNOPSIS
    Debug-Playback.ps1 - MediaStack Playback & Transcoding Debugger.
#>
param(
    [int]$Lines = 100
)

Clear-Host
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "   MediaStack Playback Debugger"
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

$envFile = if ($env:PROCESSOR_ARCHITECTURE -match "ARM") { ".env.arm" } else { ".env.x64" }
$envPath = Join-Path $PSScriptRoot $envFile

$detectedConfig = ".\config"
if (Test-Path $envPath) {
    foreach ($line in (Get-Content $envPath)) {
        if ($line -match "^CONFIG_ROOT=(.*)$") {
            $detectedConfig = $line.Substring(12).Trim()
            break
        }
    }
}

$jellyLogDir = Join-Path $detectedConfig "jellyfin\log"

Write-Host "[1] Checking Caddy Proxy Errors (Last $Lines lines)..." -ForegroundColor Yellow
docker logs --tail $Lines caddy 2>&1 | Select-String -Pattern "502|500|timeout|ERR|error"

Write-Host "`n[2] Checking Jellyfin Container Errors..." -ForegroundColor Yellow
docker logs --tail $Lines jellyfin 2>&1 | Select-String -Pattern "FTL|ERR|Error|Exception|Playback"

Write-Host "`n[3] Checking FFmpeg Transcoding Logs..." -ForegroundColor Yellow
if (Test-Path $jellyLogDir) {
    $ffmpegLogs = Get-ChildItem -Path $jellyLogDir -Filter "FFmpeg*.log" | Sort-Object LastWriteTime -Descending | Select-Object -First 3
    if ($ffmpegLogs) {
        foreach ($fLog in $ffmpegLogs) {
            Write-Host "--- Found FFmpeg Log: $($fLog.Name) ---" -ForegroundColor Magenta
            Get-Content $fLog.FullName -Tail 20 | Select-String -Pattern "Error|fatal|failed|Video:|Audio:"
        }
    } else {
        Write-Host "No recent FFmpeg logs found. (Direct Play might have been active, or no playback was attempted)." -ForegroundColor DarkGray
    }
} else {
    Write-Host "Cannot access Jellyfin log directory at $jellyLogDir" -ForegroundColor Red
}

Write-Host "`n[4] Checking Media Mount Accessibility..." -ForegroundColor Yellow
Write-Host "Testing if Jellyfin container can see /data/video..."
$mountCheck = docker exec jellyfin ls -la /data/video 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "[OK] /data/video is mounted and accessible." -ForegroundColor Green
} else {
    Write-Host "[!] /data/video is NOT accessible inside container! (Error: $mountCheck)" -ForegroundColor Red
}

Write-Host "`n=============================================" -ForegroundColor Cyan
Write-Host "   Debug complete."
