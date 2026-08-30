# MediaStack Fleet Proxy & Port Diagnostic Report

- **Generated:** 2026-08-30 18:33:09
- **Local Node:** VOLTAIREDEUX (VoltaireDeux (AI Acceleration & Push Node))
- **Local IP:** 192.168.4.30
- **Peer Node:** VOLTAIREUN (VoltaireUn (Main 24/7 Server Node))
- **Peer IP:** 192.168.4.21
- **Auto-Repair Mode:** ACTIVE (Enabled)
- **Remediated Issues:** 10
- **Critical Failures Remaining:** 0

---

## 1. Canonical Sockets & Port Verification Matrix

| Service | Port | Container | Category | Critical | Status | Latency | Root-Cause Analysis / Notes |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Caddy Gateway HTTP** | 80 | caddy | INGRESS | **YES** | ONLINE | 1200 ms | Container 'caddy' is stopped / not created. -> Remediated automatically. |
| **Caddy Gateway HTTPS** | 443 | caddy | INGRESS | **YES** | ONLINE | 0 ms | Operating normally |
| **API Gateway REST** | 3000 | api-gateway | API | **YES** | ONLINE | 1213 ms | Container 'api-gateway' is stopped / not created. -> Remediated automatically. |
| **Jellyfin Media Server** | 8096 | jellyfin | STREAMING | **YES** | ONLINE | 1207 ms | Container 'jellyfin' is stopped / not created. -> Remediated automatically. |
| **Sonarr TV Automation** | 8989 | sonarr | AUTOMATION | **YES** | ONLINE | 1214 ms | Container 'sonarr' is stopped / not created. -> Remediated automatically. |
| **Radarr Movie Manager** | 7878 | radarr | AUTOMATION | **YES** | ONLINE | 1205 ms | Container 'radarr' is stopped / not created. -> Remediated automatically. |
| **Prowlarr Indexer** | 9696 | prowlarr | INDEXER | **YES** | ONLINE | 1204 ms | Container 'prowlarr' is stopped / not created. -> Remediated automatically. |
| **Bazarr Subtitles** | 6767 | bazarr | SUBTITLES | **YES** | ONLINE | 1215 ms | Container 'bazarr' is stopped / not created. -> Remediated automatically. |
| **Jellyseerr Requests** | 5055 | jellyseerr | REQUESTS | **YES** | ONLINE | 1207 ms | Container 'jellyseerr' is stopped / not created. -> Remediated automatically. |
| **Transmission Web UI** | 9091 | transmission | TORRENT | **YES** | ONLINE | 1211 ms | Container 'transmission' is stopped / not created. -> Remediated automatically. |
| **Transmission Peer TCP** | 51413 | transmission | TORRENT | No | STANDBY | 1201 ms | Standby / optional node service not currently active. |
| **TVHeadend Web UI** | 9981 | tvheadend | LIVETV | **YES** | ONLINE | 1212 ms | Container 'tvheadend' is stopped / not created. -> Remediated automatically. |
| **TVHeadend HTSP Stream** | 9982 | tvheadend | LIVETV | No | ONLINE | 0 ms | Operating normally |
| **Mediastack DB GUI** | 8080 | mediastack-db | DATABASE | **YES** | ONLINE | 0 ms | Operating normally |
| **Syncthing Web GUI** | 8384 | syncthing | SYNC | No | STANDBY | 1203 ms | Standby / optional node service not currently active. |
| **Syncthing Peer TCP** | 22000 | syncthing | SYNC | No | STANDBY | 1212 ms | Standby / optional node service not currently active. |
| **MusicBrainz Secondary** | 5001 | musicbrainz | METADATA | No | STANDBY | 1208 ms | Standby / optional node service not currently active. |
| **MusicBrainz Primary** | 5000 | remote | METADATA | No | ONLINE | 8 ms | Operating normally |

---

## 2. Reverse Proxy Subdomain Ingress Health

| Route Name | Target URL | HTTP Status | Response Time | Diagnostics |
| :--- | :--- | :--- | :--- | :--- |
| **Dashboard Ingress** | http://voltairedeux.local | 200 OK | 80 ms | HTTP 200 via curl |
| **Jellyfin Subdomain** | http://jellyfin.voltairedeux.local | 0 WARN | 559 ms | HTTP 0 via curl |
| **Sonarr Subdomain** | http://sonarr.voltairedeux.local | 401 OK | 568 ms | HTTP 401 (Caddy Gateway Verified) |
| **Radarr Subdomain** | http://radarr.voltairedeux.local | 302 OK | 504 ms | HTTP 302 (Caddy Gateway Verified) |
| **Prowlarr Subdomain** | http://prowlarr.voltairedeux.local | 302 OK | 568 ms | HTTP 302 (Caddy Gateway Verified) |
| **Bazarr Subdomain** | http://bazarr.voltairedeux.local | 200 OK | 713 ms | HTTP 200 (Caddy Gateway Verified) |
| **Jellyseerr Route** | http://jellyseerr.voltairedeux.local | 307 OK | 978 ms | HTTP 307 (Caddy Gateway Verified) |
| **API Gateway Route** | http://api.voltairedeux.local | 308 OK | 567 ms | HTTP 308 (Caddy Gateway Verified) |
| **Database GUI Route** | http://db.voltairedeux.local | 200 OK | 562 ms | HTTP 200 (Caddy Gateway Verified) |

---

## 3. Executive Assessment & Readiness

- **Port Health Status:** 100% Core Sockets Operational
- **Auto-Repair Success:** 10 auto-remediations applied
- **Cluster Readiness:** READY for cluster synchronization & pipeline operations.

*Report archived in: C:\Users\waltd\OneDrive\Mediastack\handoffs\Proxy_Port_Diagnostic_Report_20260830_183309.md*
