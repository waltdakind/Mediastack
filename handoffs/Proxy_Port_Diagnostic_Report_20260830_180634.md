# MediaStack Fleet Proxy & Port Diagnostic Report

- **Generated:** 2026-08-30 18:06:34
- **Local Node:** VOLTAIREUN (VoltaireUn (Main 24/7 Server Node))
- **Local IP:** 192.168.4.21
- **Peer Node:** VOLTAIREDEUX (VoltaireDeux (AI Acceleration & Push Node))
- **Peer IP:** fe80::a96e:fd36:62a8:42ba%25
- **Auto-Repair Mode:** ACTIVE (Enabled)
- **Remediated Issues:** 0
- **Critical Failures Remaining:** 0

---

## 1. Canonical Sockets & Port Verification Matrix

| Service | Port | Container | Category | Critical | Status | Latency | Root-Cause Analysis / Notes |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Caddy Gateway HTTP** | 80 | caddy | INGRESS | **YES** | ONLINE | 33 ms | Operating normally |
| **Caddy Gateway HTTPS** | 443 | caddy | INGRESS | **YES** | ONLINE | 2 ms | Operating normally |
| **API Gateway REST** | 3000 | api-gateway | API | **YES** | ONLINE | 1 ms | Operating normally |
| **Jellyfin Media Server** | 8096 | jellyfin | STREAMING | **YES** | ONLINE | 6 ms | Operating normally |
| **Sonarr TV Automation** | 8989 | sonarr | AUTOMATION | **YES** | ONLINE | 2 ms | Operating normally |
| **Radarr Movie Manager** | 7878 | radarr | AUTOMATION | **YES** | ONLINE | 2 ms | Operating normally |
| **Prowlarr Indexer** | 9696 | prowlarr | INDEXER | **YES** | ONLINE | 2 ms | Operating normally |
| **Bazarr Subtitles** | 6767 | bazarr | SUBTITLES | **YES** | ONLINE | 5 ms | Operating normally |
| **Jellyseerr Requests** | 5055 | jellyseerr | REQUESTS | **YES** | ONLINE | 4 ms | Operating normally |
| **Transmission Web UI** | 9091 | transmission | TORRENT | **YES** | ONLINE | 2 ms | Operating normally |
| **Transmission Peer TCP** | 51413 | transmission | TORRENT | No | STANDBY | 1210 ms | Standby / optional node service not currently active. |
| **TVHeadend Web UI** | 9981 | tvheadend | LIVETV | **YES** | ONLINE | 2 ms | Operating normally |
| **TVHeadend HTSP Stream** | 9982 | tvheadend | LIVETV | No | ONLINE | 2 ms | Operating normally |
| **Mediastack DB GUI** | 8080 | mediastack-db | DATABASE | **YES** | ONLINE | 3 ms | Operating normally |
| **Syncthing Web GUI** | 8384 | syncthing | SYNC | No | STANDBY | 1208 ms | Standby / optional node service not currently active. |
| **Syncthing Peer TCP** | 22000 | syncthing | SYNC | No | STANDBY | 1231 ms | Standby / optional node service not currently active. |
| **MusicBrainz Secondary** | 5001 | musicbrainz | METADATA | No | ONLINE | 3 ms | Operating normally |
| **MusicBrainz Primary** | 5000 | remote | METADATA | No | ONLINE | 19 ms | Operating normally |

---

## 2. Reverse Proxy Subdomain Ingress Health

| Route Name | Target URL | HTTP Status | Response Time | Diagnostics |
| :--- | :--- | :--- | :--- | :--- |
| **Dashboard Ingress** | http://voltaireun.local | 200 OK | 2182 ms | HTTP 200 (Caddy Gateway Verified) |
| **Jellyfin Subdomain** | http://jellyfin.voltaireun.local | 0 WARN | 806 ms | HTTP 0 via curl |
| **Sonarr Subdomain** | http://sonarr.voltaireun.local | 401 OK | 1176 ms | HTTP 401 (Caddy Gateway Verified) |
| **Radarr Subdomain** | http://radarr.voltaireun.local | 302 OK | 1014 ms | HTTP 302 (Caddy Gateway Verified) |
| **Prowlarr Subdomain** | http://prowlarr.voltaireun.local | 302 OK | 567 ms | HTTP 302 (Caddy Gateway Verified) |
| **Bazarr Subdomain** | http://bazarr.voltaireun.local | 200 OK | 287 ms | HTTP 200 (Caddy Gateway Verified) |
| **Jellyseerr Route** | http://jellyseerr.voltaireun.local | 307 OK | 374 ms | HTTP 307 (Caddy Gateway Verified) |
| **API Gateway Route** | http://api.voltaireun.local | 308 OK | 905 ms | HTTP 308 (Caddy Gateway Verified) |
| **Database GUI Route** | http://db.voltaireun.local | 200 OK | 413 ms | HTTP 200 (Caddy Gateway Verified) |

---

## 3. Executive Assessment & Readiness

- **Port Health Status:** 100% Core Sockets Operational
- **Auto-Repair Success:** 0 auto-remediations applied
- **Cluster Readiness:** READY for cluster synchronization & pipeline operations.

*Report archived in: C:\Users\waltd\OneDrive\Mediastack\handoffs\Proxy_Port_Diagnostic_Report_20260830_180634.md*
