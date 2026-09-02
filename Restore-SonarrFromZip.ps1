docker stop sonarr
$backupZip = "c:\Users\waltd\OneDrive\Mediastack\config\sonarr\Backups\scheduled\sonarr_backup_v4.0.19.2979_2026.08.29_23.12.23.zip"
$extractDir = "c:\Users\waltd\OneDrive\Mediastack\config\sonarr\Backups\restore_tmp"
if (Test-Path $extractDir) { Remove-Item $extractDir -Recurse -Force }
Expand-Archive -Path $backupZip -DestinationPath $extractDir -Force
Remove-Item "c:\Users\waltd\OneDrive\Mediastack\config\sonarr\sonarr.db*" -Force -ErrorAction SilentlyContinue
Remove-Item "c:\Users\waltd\OneDrive\Mediastack\config\sonarr\logs*" -Force -ErrorAction SilentlyContinue
Copy-Item (Join-Path $extractDir "sonarr.db") "c:\Users\waltd\OneDrive\Mediastack\config\sonarr\sonarr.db" -Force
Remove-Item $extractDir -Recurse -Force
docker start sonarr
Write-Host "[OK] Sonarr restored and restarted successfully." -ForegroundColor Green
