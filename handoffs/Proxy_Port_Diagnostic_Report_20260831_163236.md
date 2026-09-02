# MediaStack Fleet Proxy & Port Diagnostic Report

- **Generated:** 2026-08-31 16:32:36
- **Local Node:** ORDINATEURDEVOL (VoltaireUn (Main 24/7 Server Node))
- **Local IP:** 192.168.4.21
- **Peer Node:** VOLTAIREDEUX (VoltaireDeux (AI Acceleration & Push Node))
- **Peer IP:** fe80::a96e:fd36:62a8:42ba%25
- **Auto-Repair Mode:** DISABLED
- **Remediated Issues:** 0
- **Critical Failures Remaining:** 0

---

## 1. Canonical Sockets & Port Verification Matrix

| Service | Port | Container | Category | Critical | Status | Latency | Root-Cause Analysis / Notes |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Caddy Gateway HTTP** | 80 | caddy | INGRESS | **YES** | ONLINE | 166 ms | Operating normally |
| **Caddy Gateway HTTPS** | 443 | caddy | INGRESS | **YES** | ONLINE | 61 ms | Operating normally |
| **API Gateway REST** | 3000 | api-gateway | API | **YES** | ONLINE | 66 ms | Operating normally |
| **Jellyfin Media Server** | 8096 | jellyfin | STREAMING | **YES** | ONLINE | 72 ms | Operating normally |
| **Sonarr TV Automation** | 8989 | sonarr | AUTOMATION | **YES** | ONLINE | 124 ms | Operating normally |
| **Radarr Movie Manager** | 7878 | radarr | AUTOMATION | **YES** | ONLINE | 170 ms | Operating normally |
| **Prowlarr Indexer** | 9696 | prowlarr | INDEXER | **YES** | ONLINE | 128 ms | Operating normally |
| **Bazarr Subtitles** | 6767 | bazarr | SUBTITLES | **YES** | ONLINE | 146 ms | Operating normally |
| **Jellyseerr Requests** | 5055 | jellyseerr | REQUESTS | **YES** | ONLINE | 68 ms | Operating normally |
| **Transmission Web UI** | 9091 | transmission | TORRENT | **YES** | ONLINE | 83 ms | Operating normally |
| **Transmission Peer TCP** | 51413 | transmission | TORRENT | No | STANDBY | 1286 ms | Standby / optional node service not currently active. |
| **TVHeadend Web UI** | 9981 | tvheadend | LIVETV | **YES** | ONLINE | 108 ms | Operating normally |
| **TVHeadend HTSP Stream** | 9982 | tvheadend | LIVETV | No | ONLINE | 89 ms | Operating normally |
| **Mediastack DB GUI** | 8080 | mediastack-db | DATABASE | **YES** | ONLINE | 59 ms | Operating normally |
| **Syncthing Web GUI** | 8384 | syncthing | SYNC | No | STANDBY | 1260 ms | Standby / optional node service not currently active. |
| **Syncthing Peer TCP** | 22000 | syncthing | SYNC | No | STANDBY | 1258 ms | Standby / optional node service not currently active. |
| **MusicBrainz Secondary** | 5001 | musicbrainz | METADATA | No | ONLINE | 107 ms | Operating normally |
| **MusicBrainz Primary** | 5000 | remote | METADATA | No | ONLINE | 56 ms | Operating normally |

---

## 2. Reverse Proxy Subdomain Ingress Health

| Route Name | Target URL | HTTP Status | Response Time | Diagnostics |
| :--- | :--- | :--- | :--- | :--- |
| **Dashboard Ingress** | http://voltaireun.local | 200 OK | 3244 ms | HTTP 200 (Caddy Gateway Verified) |
| **Jellyfin Subdomain** | http://jellyfin.voltaireun.local | 0 WARN | 2470 ms | HTTP 0 via curl |
| **Sonarr Subdomain** | http://sonarr.voltaireun.local | 0 WARN | 2431 ms | HTTP 0 via curl |
| **Radarr Subdomain** | http://radarr.voltaireun.local | 302 OK | 2271 ms | HTTP 302 (Caddy Gateway Verified) |
| **Prowlarr Subdomain** | http://prowlarr.voltaireun.local | 0 WARN | 2541 ms | HTTP 0 via curl |
| **Bazarr Subdomain** | http://bazarr.voltaireun.local | 0 WARN | 3005 ms | HTTP 0 via curl |
| **Jellyseerr Route** | http://jellyseerr.voltaireun.local | 0 WARN | 3024 ms | HTTP 0 via curl |
| **API Gateway Route** | http://api.voltaireun.local | 308 OK | 2304 ms | HTTP 308 (Caddy Gateway Verified) |
| **Database GUI Route** | http://db.voltaireun.local | 0 WARN | 2258 ms | HTTP 0 via curl |

---

## 3. Executive Assessment & Readiness

- **Port Health Status:** 100% Core Sockets Operational
- **Auto-Repair Success:** 0 auto-remediations applied
- **Cluster Readiness:** READY for cluster synchronization & pipeline operations.

*Report archived in: C:\Users\waltd\OneDrive\Mediastack\handoffs\Proxy_Port_Diagnostic_Report_20260831_163236.md*
