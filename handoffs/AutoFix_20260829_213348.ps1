# ==============================================================================
# Autonomous Remediation Script - Generated 2026-08-29 21:33:48
# ==============================================================================
$ErrorActionPreference = 'Continue'
Write-Host '
[EXECUTING AUTONOMOUS REMEDIATION]' -ForegroundColor Cyan
Write-Host '  -> Reloading Caddy Reverse-Proxy configuration...' -ForegroundColor Yellow
docker exec caddy caddy reload --config /etc/caddy/Caddyfile
Write-Host '  [OK] Remediation actions completed.' -ForegroundColor Green
