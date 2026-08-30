# MediaStack Fleet Proxy & Port Diagnostic Report

- **Generated:** 2026-08-30 18:25:06
- **Local Node:** VOLTAIREDEUX (VoltaireDeux (AI Acceleration & Push Node))
- **Local IP:** 192.168.4.30
- **Peer Node:** VOLTAIREUN (VoltaireUn (Main 24/7 Server Node))
- **Peer IP:** 192.168.4.21
- **Auto-Repair Mode:** ACTIVE (Enabled)
- **Remediated Issues:** 0
- **Critical Failures Remaining:** 12

---

## 1. Canonical Sockets & Port Verification Matrix

| Service | Port | Container | Category | Critical | Status | Latency | Root-Cause Analysis / Notes |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Caddy Gateway HTTP** | 80 | caddy | INGRESS | **YES** | FAILING | 1211 ms | Container 'caddy' is stopped / not created. |
| **Caddy Gateway HTTPS** | 443 | caddy | INGRESS | **YES** | FAILING | 1214 ms | Container 'caddy' is stopped / not created. |
| **API Gateway REST** | 3000 | api-gateway | API | **YES** | FAILING | 1211 ms | Container 'api-gateway' is stopped / not created. |
| **Jellyfin Media Server** | 8096 | jellyfin | STREAMING | **YES** | FAILING | 1206 ms | Container 'jellyfin' is stopped / not created. |
| **Sonarr TV Automation** | 8989 | sonarr | AUTOMATION | **YES** | FAILING | 1204 ms | Container 'sonarr' is stopped / not created. |
| **Radarr Movie Manager** | 7878 | radarr | AUTOMATION | **YES** | FAILING | 1206 ms | Container 'radarr' is stopped / not created. |
| **Prowlarr Indexer** | 9696 | prowlarr | INDEXER | **YES** | FAILING | 1206 ms | Container 'prowlarr' is stopped / not created. |
| **Bazarr Subtitles** | 6767 | bazarr | SUBTITLES | **YES** | FAILING | 1203 ms | Container 'bazarr' is stopped / not created. |
| **Jellyseerr Requests** | 5055 | jellyseerr | REQUESTS | **YES** | FAILING | 1204 ms | Container 'jellyseerr' is stopped / not created. |
| **Transmission Web UI** | 9091 | transmission | TORRENT | **YES** | FAILING | 1214 ms | Container 'transmission' is stopped / not created. |
| **Transmission Peer TCP** | 51413 | transmission | TORRENT | No | STANDBY | 1207 ms | Standby / optional node service not currently active. |
| **TVHeadend Web UI** | 9981 | tvheadend | LIVETV | **YES** | FAILING | 1213 ms | Container 'tvheadend' is stopped / not created. |
| **TVHeadend HTSP Stream** | 9982 | tvheadend | LIVETV | No | STANDBY | 1198 ms | Standby / optional node service not currently active. |
| **Mediastack DB GUI** | 8080 | mediastack-db | DATABASE | **YES** | FAILING | 1211 ms | Container 'mediastack-db' is stopped / not created. |
| **Syncthing Web GUI** | 8384 | syncthing | SYNC | No | STANDBY | 1207 ms | Standby / optional node service not currently active. |
| **Syncthing Peer TCP** | 22000 | syncthing | SYNC | No | STANDBY | 1213 ms | Standby / optional node service not currently active. |
| **MusicBrainz Secondary** | 5001 | musicbrainz | METADATA | No | STANDBY | 1212 ms | Standby / optional node service not currently active. |
| **MusicBrainz Primary** | 5000 | remote | METADATA | No | ONLINE | 12 ms | Operating normally |

---

## 2. Reverse Proxy Subdomain Ingress Health

| Route Name | Target URL | HTTP Status | Response Time | Diagnostics |
| :--- | :--- | :--- | :--- | :--- |
| **Dashboard Ingress** | http://voltairedeux.local | 0 WARN | 2110 ms | HTTP 0 via curl |
| **Jellyfin Subdomain** | http://jellyfin.voltairedeux.local | 0 WARN | 1373 ms | HTTP 0 via curl |
| **Sonarr Subdomain** | http://sonarr.voltairedeux.local | 0 WARN | 1001 ms | HTTP 0 via curl |
| **Radarr Subdomain** | http://radarr.voltairedeux.local | 0 WARN | 983 ms | HTTP 0 via curl |
| **Prowlarr Subdomain** | http://prowlarr.voltairedeux.local | 0 WARN | 1277 ms | HTTP 0 via curl |
| **Bazarr Subdomain** | http://bazarr.voltairedeux.local | 0 WARN | 763 ms | HTTP 0 via curl |
| **Jellyseerr Route** | http://jellyseerr.voltairedeux.local | 0 WARN | 768 ms | HTTP 0 via curl |
| **API Gateway Route** | http://api.voltairedeux.local | 0 WARN | 566 ms | HTTP 0 via curl |
| **Database GUI Route** | http://db.voltairedeux.local | 0 WARN | 570 ms | HTTP 0 via curl |

---

## 3. Executive Assessment & Readiness

- **Port Health Status:** 12 Unresolved Critical Port Issues
- **Auto-Repair Success:** 0 auto-remediations applied
- **Cluster Readiness:** BLOCKED: Resolve critical port conflicts before continuing.

*Report archived in: C:\Users\waltd\OneDrive\Mediastack\handoffs\Proxy_Port_Diagnostic_Report_20260830_182506.md*
