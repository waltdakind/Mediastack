# Caddy Reverse Proxy Setup

## Overview
Caddy replaces Nginx with automatic HTTPS, simpler configuration, and built-in failover support.

## Configuration

### Caddy Service (docker-compose.yml)
```yaml
caddy:
  image: caddy:latest
  container_name: caddy
  ports:
    - "80:80"      # HTTP
    - "443:443"    # HTTPS
    - "8096:8096"  # Jellyfin external traffic
  volumes:
    - ./caddy/Caddyfile:/etc/caddy/Caddyfile
    - ./caddy/config:/config
    - ./caddy/data:/data
```

### Caddyfile Configuration
Located at `./caddy/Caddyfile`, it defines:
- **Port:** 8096 for external Jellyfin access
- **Upstream servers:**
  - Primary: 192.168.4.21:8096 (OrdinateurdeVol)
  - Secondary: 192.168.4.30:8096 (VoltaireDeux - current)
- **Health checks:** Every 10s on `/health` endpoint
- **Headers:** X-Real-IP, X-Forwarded-For, X-Forwarded-Proto for proper streaming

## Features

### Automatic Failover
If primary (192.168.4.21:8096) is down:
1. Caddy detects health check failure
2. Routes traffic to fallback (192.168.4.30:8096)
3. Resumes to primary when it recovers

### Health Checks
- **Interval:** 10 seconds
- **Timeout:** 5 seconds
- **Endpoint:** `/health`

### WebSocket Support
Jellyfin uses WebSockets; Caddy automatically handles this with the reverse_proxy directive.

## Usage

### Start Stack
```bash
docker compose up -d
```

### Check Caddy Status
```bash
docker logs caddy
```

### Reload Caddyfile (without restarting)
```bash
docker exec caddy caddy reload --config /etc/caddy/Caddyfile
```

## Switching Between Servers

### Primary (OrdinateurdeVol - 192.168.4.21)
- Currently: Commented out, used as primary fallback
- Caddyfile will route to this first; if down, uses VoltaireDeux

### Fallback (VoltaireDeux - 192.168.4.30)
- Currently: Running (current server)
- Will be used if primary is unreachable

## Advanced Configurations

### Custom Domain with HTTPS
Edit Caddyfile to uncomment HTTPS section:
```
jellyfin.yourdomain.com {
  reverse_proxy localhost:8096 192.168.4.21:8096 192.168.4.30:8096 {
    health_uri /health
    health_interval 10s
  }
}
```
Caddy will automatically provision SSL certificates via Let's Encrypt.

### Load Balancing Policy
Add to reverse_proxy block:
```
policy random  # or: least_conn, least_request, round_robin, uri_hash
```

### Request Timeouts
Configured with 5s dial timeout and 30s response timeout for streaming stability.

## External Access
- **IP:** 73.160.54.228:8096
- **Caddy listens on:** 0.0.0.0:8096 (all interfaces)
- **Ensure port 8096 is forwarded** from your router to this machine's port 8096
