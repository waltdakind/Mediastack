# ==============================================================================
# Autonomous Remediation Script - Generated 2026-09-02 22:10:32
# ==============================================================================
$ErrorActionPreference = 'Continue'
Write-Host '
[EXECUTING AUTONOMOUS REMEDIATION]' -ForegroundColor Cyan
Write-Host '  -> Deploying missing container: jellyfin...' -ForegroundColor Yellow
docker compose up -d jellyfin
Write-Host '  -> Deploying missing container: transmission...' -ForegroundColor Yellow
docker compose up -d transmission
Write-Host '  -> Deploying missing container: api-gateway...' -ForegroundColor Yellow
docker compose up -d api-gateway
Write-Host '  -> Auto-recovering MusicBrainz database persistence from snapshot...' -ForegroundColor Yellow
& "C:\Users\waltd\OneDrive\Mediastack\Ensure-MusicBrainzPersistence.ps1" -AutoRestore
Write-Host '  [OK] Remediation actions completed.' -ForegroundColor Green
