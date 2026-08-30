param(
    [int] = 100
)

Clear-Host
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "   MediaStack Playback Debugger"
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

 = ".env.x64"
if (ARM64 -match "ARM") {  = ".env.arm" }
 = Join-Path  

 = ".\config"
if (Test-Path ) {
    Get-Content  | ForEach-Object {
        if ( -match "^CONFIG_ROOT=(.*)$") {  = [1].Trim() }
    }
}

 = Join-Path  "jellyfin\log"

Write-Host "[1] Checking Caddy Proxy Errors (Last  lines)..." -ForegroundColor Yellow
docker compose -f docker-compose.yml -f docker-compose.arm.yml logs --tail  caddy 2>&1 | Select-String -Pattern "502|500|timeout|ERR|error"

Write-Host "
[2] Checking Jellyfin Container Errors..." -ForegroundColor Yellow
docker compose -f docker-compose.yml -f docker-compose.arm.yml logs --tail  jellyfin 2>&1 | Select-String -Pattern "FTL|ERR|Error|Exception|Playback"

Write-Host "
[3] Checking FFmpeg Transcoding Logs..." -ForegroundColor Yellow
if (Test-Path ) {
     = Get-ChildItem -Path  -Filter "FFmpeg*.log" | Sort-Object LastWriteTime -Descending | Select-Object -First 3
    if () {
        foreach ( in ) {
            Write-Host "--- Found FFmpeg Log:  ---" -ForegroundColor Magenta
            Get-Content .FullName -Tail 20 | Select-String -Pattern "Error|fatal|failed|Video:|Audio:"
        }
    } else {
        Write-Host "No recent FFmpeg logs found. (Direct Play might have been active, or no playback was attempted)." -ForegroundColor DarkGray
    }
} else {
    Write-Host "Cannot access Jellyfin log directory at " -ForegroundColor Red
}

Write-Host "
[4] Checking Media Mount Accessibility..." -ForegroundColor Yellow
Write-Host "Testing if Jellyfin container can see /data/video..."
 = docker exec jellyfin ls -la /data/video 2>&1
if ( -eq 0) {
    Write-Host "[OK] /data/video is mounted and accessible." -ForegroundColor Green
} else {
    Write-Host "[!] /data/video is NOT accessible inside container! (Error: )" -ForegroundColor Red
}

Write-Host "
=============================================" -ForegroundColor Cyan
Write-Host "   Debug complete."
