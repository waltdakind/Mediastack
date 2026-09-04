# ==============================================================================
# Autonomous Remediation Script - Generated 2026-09-03 20:49:51
# ==============================================================================
$ErrorActionPreference = 'Continue'
Write-Host '
[EXECUTING AUTONOMOUS REMEDIATION]' -ForegroundColor Cyan
Write-Host '  -> Deploying missing container: prowlarr...' -ForegroundColor Yellow
docker compose up -d prowlarr
Write-Host '  -> Deploying missing container: jellyseerr...' -ForegroundColor Yellow
docker compose up -d jellyseerr
Write-Host '  [OK] Remediation actions completed.' -ForegroundColor Green
