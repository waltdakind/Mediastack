# Fix-SonarrDatabase.ps1
$dbPath = "C:\Users\waltd\OneDrive\Mediastack\config\sonarr\sonarr.db"
$backupPath = "C:\Users\waltd\OneDrive\Mediastack\config\sonarr\sonarr.db.bak_$(Get-Date -Format 'yyyyMMdd_HHmmss')"

Write-Host "Creating backup of Sonarr database..." -ForegroundColor Yellow
Copy-Item -Path $dbPath -Destination $backupPath -Force

Write-Host "Inspecting and repairing VersionInfo table in sonarr.db..." -ForegroundColor Cyan
docker run --rm -v "C:\Users\waltd\OneDrive\Mediastack\config\sonarr:/db" alpine sh -c "apk add --no-cache sqlite >/dev/null 2>&1 && sqlite3 /db/sonarr.db 'SELECT * FROM VersionInfo WHERE AppliedOn = \"UpdateSceneMapping\" OR AppliedOn NOT LIKE \"20%\";' && sqlite3 /db/sonarr.db 'UPDATE VersionInfo SET AppliedOn = \"2024-01-01T00:00:00\" WHERE AppliedOn = \"UpdateSceneMapping\" OR AppliedOn NOT LIKE \"20%\";' && echo '[SQL OK] VersionInfo cleaned.'"

Write-Host "Restarting sonarr container..." -ForegroundColor Yellow
docker restart sonarr

Start-Sleep -Seconds 4
$code = curl.exe -k -s -o NUL -w "%{http_code}" --max-time 4 "http://localhost:8989/ping"
Write-Host "Sonarr HTTP Status: $code" -ForegroundColor Green
