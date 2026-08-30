# Health Checks Configuration

## Overview
The docker-compose.yml now includes health checks for both Syncthing and Jellyfin, ensuring services are properly running and ready to serve traffic.

## Syncthing Health Check
```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:8384/rest/noauth/health"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 10s
```
- **Endpoint:** `http://localhost:8384/rest/noauth/health`
- **Check Interval:** Every 30 seconds
- **Timeout:** 10 seconds per check
- **Max Retries:** 3 consecutive failures before unhealthy
- **Start Grace Period:** 10 seconds (waits before first check)

## Jellyfin Health Check
```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:8096/health"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 30s
```
- **Endpoint:** `http://localhost:8096/health`
- **Check Interval:** Every 30 seconds
- **Timeout:** 10 seconds per check
- **Max Retries:** 3 consecutive failures before unhealthy
- **Start Grace Period:** 30 seconds (longer startup time for Jellyfin)

## Startup Dependencies
Jellyfin depends on Syncthing being healthy before starting:
```yaml
depends_on:
  syncthing:
    condition: service_healthy
```

## Monitoring Health Status
Check container health:
```bash
docker ps --format "table {{.Names}}\t{{.Status}}"
```

Inspect detailed health status:
```bash
docker inspect --format='{{.State.Health.Status}}' syncthing
docker inspect --format='{{.State.Health.Status}}' jellyfin
```

View health check logs:
```bash
docker inspect --format='{{json .State.Health}}' jellyfin | jq .
```

## SQLite Database
Jellyfin uses an embedded SQLite database stored at:
- **Container Path:** `/config/data/db`
- **Host Path:** `./jellyfin/db`
- **Persistent:** Yes - survives container restarts

The database is automatically managed by Jellyfin; no external setup required.
