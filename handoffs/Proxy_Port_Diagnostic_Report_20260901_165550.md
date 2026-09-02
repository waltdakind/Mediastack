# MediaStack Fleet Proxy & Port Diagnostic Report

- **Generated:** 2026-09-01 16:55:50
- **Local Node:** VOLTAIREDEUX (VoltaireDeux (AI Acceleration & Push Node))
- **Local IP:** 192.168.4.30
- **Peer Node:** VOLTAIREUN (VoltaireUn (Main 24/7 Server Node))
- **Peer IP:** fe80::2c3c:b2c6:ab71:6c09%6
- **Auto-Repair Mode:** DISABLED
- **Remediated Issues:** 0
- **Critical Failures Remaining:** 0

---

## 1. Canonical Sockets & Port Verification Matrix

| Service | Port | Container | Category | Critical | Status | Latency | Root-Cause Analysis / Notes |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Caddy Gateway HTTP** | 80 | caddy | INGRESS | **YES** | ONLINE | 0 ms | Operating normally |
| **Caddy Gateway HTTPS** | 443 | caddy | INGRESS | **YES** | ONLINE | 0 ms | Operating normally |
| **API Gateway REST** | 3000 | api-gateway | API | **YES** | ONLINE | 0 ms | Operating normally |
| **Jellyfin Media Server** | 8096 | jellyfin | STREAMING | **YES** | ONLINE | 1 ms | Operating normally |
| **Sonarr TV Automation** | 8989 | sonarr | AUTOMATION | **YES** | ONLINE | 0 ms | Operating normally |
| **Radarr Movie Manager** | 7878 | radarr | AUTOMATION | **YES** | ONLINE | 0 ms | Operating normally |
| **Prowlarr Indexer** | 9696 | prowlarr | INDEXER | **YES** | ONLINE | 0 ms | Operating normally |
| **Bazarr Subtitles** | 6767 | bazarr | SUBTITLES | **YES** | ONLINE | 0 ms | Operating normally |
| **Jellyseerr Requests** | 5055 | jellyseerr | REQUESTS | **YES** | ONLINE | 0 ms | Operating normally |
| **Transmission Web UI** | 9091 | transmission | TORRENT | **YES** | ONLINE | 0 ms | Operating normally |
| **Transmission Peer TCP** | 51413 | transmission | TORRENT | No | ONLINE | 0 ms | Operating normally |
| **TVHeadend Web UI** | 9981 | tvheadend | LIVETV | **YES** | ONLINE | 0 ms | Operating normally |
| **TVHeadend HTSP Stream** | 9982 | tvheadend | LIVETV | No | ONLINE | 0 ms | Operating normally |
| **Mediastack DB GUI** | 8080 | mediastack-db | DATABASE | **YES** | ONLINE | 0 ms | Operating normally |
| **Syncthing Web GUI** | 8384 | syncthing | SYNC | No | ONLINE | 0 ms | Operating normally |
| **Syncthing Peer TCP** | 22000 | syncthing | SYNC | No | ONLINE | 0 ms | Operating normally |
| **MusicBrainz Secondary** | 5001 | musicbrainz | METADATA | No | ONLINE | 0 ms | Operating normally |
| **MusicBrainz Primary** | 5000 | remote | METADATA | No | STANDBY | 1 ms | Standby / optional node service not currently active. |

---

## 2. Reverse Proxy Subdomain Ingress Health

| Route Name | Target URL | HTTP Status | Response Time | Diagnostics |
| :--- | :--- | :--- | :--- | :--- |
| **Dashboard Ingress HTTP** | http://voltairedeux.local | 301 OK | 87 ms | HTTP 301 via curl |
| **Dashboard Ingress HTTPS** | https://voltairedeux.local | 302 OK | 85 ms | HTTP 302 via curl |
| **Jellyfin Subdomain HTTP** | http://jellyfin.voltairedeux.local | 301 OK | 221 ms | HTTP 301 (Caddy Gateway Verified) |
| **Jellyfin Subdomain HTTPS** | https://jellyfin.voltairedeux.local | 301 OK | 70 ms | HTTP 301 (Caddy Gateway Verified) |
| **Sonarr Subdomain HTTPS** | https://sonarr.voltairedeux.local | 301 OK | 1603 ms | HTTP 301 (Caddy Gateway Verified) |
| **Radarr Subdomain HTTPS** | https://radarr.voltairedeux.local | 301 OK | 1174 ms | HTTP 301 (Caddy Gateway Verified) |
| **Prowlarr Subdomain HTTPS** | https://prowlarr.voltairedeux.local | 301 OK | 1185 ms | HTTP 301 (Caddy Gateway Verified) |
| **Bazarr Subdomain HTTPS** | https://bazarr.voltairedeux.local | 301 OK | 1193 ms | HTTP 301 (Caddy Gateway Verified) |
| **Jellyseerr Route HTTPS** | https://jellyseerr.voltairedeux.local | 301 OK | 1178 ms | HTTP 301 (Caddy Gateway Verified) |
| **API Gateway Route HTTPS** | https://api.voltairedeux.local | 301 OK | 1135 ms | HTTP 301 (Caddy Gateway Verified) |
| **Database GUI Route HTTPS** | https://db.voltairedeux.local | 301 OK | 1168 ms | HTTP 301 (Caddy Gateway Verified) |

---

## 3. Executive Assessment & Readiness

- **Port Health Status:** 100% Core Sockets Operational
- **Auto-Repair Success:** 0 auto-remediations applied
- **Cluster Readiness:** READY for cluster synchronization & pipeline operations.

*Report archived in: C:\Users\waltd\OneDrive\Mediastack\handoffs\Proxy_Port_Diagnostic_Report_20260901_165550.md*
