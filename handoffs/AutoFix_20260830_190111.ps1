# ==============================================================================
# Autonomous Remediation Script - Generated 2026-08-30 19:01:11
# ==============================================================================
$ErrorActionPreference = 'Continue'
Write-Host '
[EXECUTING AUTONOMOUS REMEDIATION]' -ForegroundColor Cyan
Write-Host '  -> Reloading Caddy Reverse-Proxy configuration...' -ForegroundColor Yellow
docker exec caddy caddy reload --config /etc/caddy/Caddyfile
Write-Host '  -> Reloading Caddy Reverse-Proxy configuration...' -ForegroundColor Yellow
docker exec caddy caddy reload --config /etc/caddy/Caddyfile
Write-Host '  -> Reloading Caddy Reverse-Proxy configuration...' -ForegroundColor Yellow
docker exec caddy caddy reload --config /etc/caddy/Caddyfile
Write-Host '  [OK] Remediation actions completed.' -ForegroundColor Green
