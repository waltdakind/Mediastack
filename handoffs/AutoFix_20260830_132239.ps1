# ==============================================================================
# Autonomous Remediation Script - Generated 2026-08-30 13:22:39
# ==============================================================================
$ErrorActionPreference = 'Continue'
Write-Host '
[EXECUTING AUTONOMOUS REMEDIATION]' -ForegroundColor Cyan
Write-Host '  -> Restarting stopped container: caddy...' -ForegroundColor Yellow
docker start caddy
Write-Host '  -> Restarting stopped container: jellyfin...' -ForegroundColor Yellow
docker start jellyfin
Write-Host '  -> Restarting stopped container: sonarr...' -ForegroundColor Yellow
docker start sonarr
Write-Host '  -> Restarting stopped container: radarr...' -ForegroundColor Yellow
docker start radarr
Write-Host '  -> Restarting stopped container: prowlarr...' -ForegroundColor Yellow
docker start prowlarr
Write-Host '  -> Restarting stopped container: bazarr...' -ForegroundColor Yellow
docker start bazarr
Write-Host '  -> Restarting stopped container: jellyseerr...' -ForegroundColor Yellow
docker start jellyseerr
Write-Host '  -> Restarting stopped container: transmission...' -ForegroundColor Yellow
docker start transmission
Write-Host '  -> Restarting stopped container: tvheadend...' -ForegroundColor Yellow
docker start tvheadend
Write-Host '  -> Restarting stopped container: mediastack-db...' -ForegroundColor Yellow
docker start mediastack-db
Write-Host '  -> Restarting stopped container: homepage...' -ForegroundColor Yellow
docker start homepage
Write-Host '  -> Restarting stopped container: api-gateway...' -ForegroundColor Yellow
docker start api-gateway
Write-Host '  -> Reloading Caddy Reverse-Proxy configuration...' -ForegroundColor Yellow
docker exec caddy caddy reload --config /etc/caddy/Caddyfile
Write-Host '  -> Reloading Caddy Reverse-Proxy configuration...' -ForegroundColor Yellow
docker exec caddy caddy reload --config /etc/caddy/Caddyfile
Write-Host '  -> Reloading Caddy Reverse-Proxy configuration...' -ForegroundColor Yellow
docker exec caddy caddy reload --config /etc/caddy/Caddyfile
Write-Host '  -> Reloading Caddy Reverse-Proxy configuration...' -ForegroundColor Yellow
docker exec caddy caddy reload --config /etc/caddy/Caddyfile
Write-Host '  -> Reloading Caddy Reverse-Proxy configuration...' -ForegroundColor Yellow
docker exec caddy caddy reload --config /etc/caddy/Caddyfile
Write-Host '  -> Reloading Caddy Reverse-Proxy configuration...' -ForegroundColor Yellow
docker exec caddy caddy reload --config /etc/caddy/Caddyfile
Write-Host '  -> Reloading Caddy Reverse-Proxy configuration...' -ForegroundColor Yellow
docker exec caddy caddy reload --config /etc/caddy/Caddyfile
Write-Host '  [OK] Remediation actions completed.' -ForegroundColor Green
