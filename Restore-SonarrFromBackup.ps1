# Restore-SonarrFromBackup.ps1
Write-Host "Stopping Sonarr container..." -ForegroundColor Yellow
docker stop sonarr

$backupZip = "C:\Users\waltd\OneDrive\Mediastack\config\sonarr\Backups\scheduled\sonarr_backup_v4.0.19.2979_2026.08.29_23.12.23.zip"
$sonarrDir = "C:\Users\waltd\OneDrive\Mediastack\config\sonarr"

Write-Host "Extracting clean Sonarr database from $backupZip..." -ForegroundColor Cyan
Expand-Archive -Path $backupZip -DestinationPath $sonarrDir -Force

Write-Host "Cleaning stale WAL/SHM locks..." -ForegroundColor Yellow
Remove-Item "$sonarrDir\sonarr.db-shm", "$sonarrDir\sonarr.db-wal" -Force -ErrorAction SilentlyContinue

Write-Host "Starting Sonarr container..." -ForegroundColor Green
docker start sonarr

Start-Sleep -Seconds 6
$pingCode = curl.exe -k -s -o NUL -w "%{http_code}" --max-time 5 "http://localhost:8989/ping"
Write-Host "Sonarr Local Ping Status: HTTP $pingCode" -ForegroundColor $(if ($pingCode -eq "200") { "Green" } else { "Yellow" })

$wanCode = curl.exe -k -s -o NUL -w "%{http_code}" --max-time 5 -H "Host: sonarr.waltdakind.xubi.org" "https://localhost:443/"
Write-Host "Sonarr WAN HTTPS Status: HTTP $wanCode" -ForegroundColor $(if ($wanCode -eq "302" -or $wanCode -eq "200") { "Green" } else { "Yellow" })
