# MediaStack Fleet Proxy & Port Diagnostic Report

- **Generated:** 2026-09-02 19:03:42
- **Local Node:** VOLTAIREUN (VoltaireUn (Main 24/7 Server Node))
- **Local IP:** 192.168.4.21
- **Peer Node:** VOLTAIREDEUX (VoltaireDeux (AI Acceleration & Push Node))
- **Peer IP:** fe80::a96e:fd36:62a8:42ba%24
- **Auto-Repair Mode:** ACTIVE (Enabled)
- **Remediated Issues:** 0
- **Critical Failures Remaining:** 0

---

## 1. Canonical Sockets & Port Verification Matrix

| Service | Port | Container | Category | Critical | Status | Latency | Root-Cause Analysis / Notes |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Caddy Gateway HTTP** | 80 | caddy | INGRESS | **YES** | ONLINE | 21 ms | Operating normally |
| **Caddy Gateway HTTPS** | 443 | caddy | INGRESS | **YES** | ONLINE | 3 ms | Operating normally |
| **API Gateway REST** | 3000 | api-gateway | API | **YES** | ONLINE | 1 ms | Operating normally |
| **Jellyfin Media Server** | 8096 | jellyfin | STREAMING | **YES** | ONLINE | 1 ms | Operating normally |
| **Sonarr TV Automation** | 8989 | sonarr | AUTOMATION | **YES** | ONLINE | 1 ms | Operating normally |
| **Radarr Movie Manager** | 7878 | radarr | AUTOMATION | **YES** | ONLINE | 1 ms | Operating normally |
| **Prowlarr Indexer** | 9696 | prowlarr | INDEXER | **YES** | ONLINE | 1 ms | Operating normally |
| **Bazarr Subtitles** | 6767 | bazarr | SUBTITLES | **YES** | ONLINE | 1 ms | Operating normally |
| **Jellyseerr Requests** | 5055 | jellyseerr | REQUESTS | **YES** | ONLINE | 3 ms | Operating normally |
| **Transmission Web UI** | 9091 | transmission | TORRENT | **YES** | ONLINE | 1205 ms | Operating normally |
| **Transmission Peer TCP** | 51413 | transmission | TORRENT | No | STANDBY | 1202 ms | Standby / optional node service not currently active. |
| **TVHeadend Web UI** | 9981 | tvheadend | LIVETV | **YES** | ONLINE | 1 ms | Operating normally |
| **TVHeadend HTSP Stream** | 9982 | tvheadend | LIVETV | No | ONLINE | 1 ms | Operating normally |
| **Mediastack DB GUI** | 8080 | mediastack-db | DATABASE | **YES** | ONLINE | 1 ms | Operating normally |
| **Syncthing Web GUI** | 8384 | syncthing | SYNC | No | STANDBY | 1219 ms | Standby / optional node service not currently active. |
| **Syncthing Peer TCP** | 22000 | syncthing | SYNC | No | STANDBY | 1206 ms | Standby / optional node service not currently active. |
| **MusicBrainz Secondary** | 5001 | musicbrainz | METADATA | No | ONLINE | 2 ms | Operating normally |
| **MusicBrainz Primary** | 5000 | remote | METADATA | No | ONLINE | 1 ms | Operating normally |

---

## 2. Reverse Proxy Subdomain Ingress Health

| Route Name | Target URL | HTTP Status | Response Time | Diagnostics |
| :--- | :--- | :--- | :--- | :--- |
| **Dashboard Ingress HTTP** | http://voltaireun.local | 301 OK | 13306 ms | HTTP 301 via curl |
| **Dashboard Ingress HTTPS** | https://voltaireun.local | 301 OK | 2731 ms | HTTP 301 (Caddy Gateway Verified) |
| **Jellyfin Subdomain HTTP** | http://jellyfin.voltaireun.local | 301 OK | 1553 ms | HTTP 301 (Caddy Gateway Verified) |
| **Jellyfin Subdomain HTTPS** | https://jellyfin.voltaireun.local | 301 OK | 432 ms | HTTP 301 (Caddy Gateway Verified) |
| **Sonarr Subdomain HTTPS** | https://sonarr.voltaireun.local | 301 OK | 1374 ms | HTTP 301 (Caddy Gateway Verified) |
| **Radarr Subdomain HTTPS** | https://radarr.voltaireun.local | 301 OK | 1414 ms | HTTP 301 (Caddy Gateway Verified) |
| **Prowlarr Subdomain HTTPS** | https://prowlarr.voltaireun.local | 301 OK | 999 ms | HTTP 301 (Caddy Gateway Verified) |
| **Bazarr Subdomain HTTPS** | https://bazarr.voltaireun.local | 301 OK | 1039 ms | HTTP 301 (Caddy Gateway Verified) |
| **Jellyseerr Route HTTPS** | https://jellyseerr.voltaireun.local | 301 OK | 1156 ms | HTTP 301 (Caddy Gateway Verified) |
| **API Gateway Route HTTPS** | https://api.voltaireun.local | 308 OK | 1011 ms | HTTP 308 (Caddy Gateway Verified) |
| **Database GUI Route HTTPS** | https://db.voltaireun.local | 301 OK | 1414 ms | HTTP 301 (Caddy Gateway Verified) |

---

## 3. Executive Assessment & Readiness

- **Port Health Status:** 100% Core Sockets Operational
- **Auto-Repair Success:** 0 auto-remediations applied
- **Cluster Readiness:** READY for cluster synchronization & pipeline operations.

*Report archived in: C:\Users\waltd\OneDrive\Mediastack\handoffs\Proxy_Port_Diagnostic_Report_20260902_190342.md*
