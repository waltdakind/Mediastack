# MediaStack Fleet Proxy & Port Diagnostic Report

- **Generated:** 2026-08-31 16:46:08
- **Local Node:** VOLTAIREDEUX (VoltaireDeux (AI Acceleration & Push Node))
- **Local IP:** 192.168.4.30
- **Peer Node:** VOLTAIREUN (VoltaireUn (Main 24/7 Server Node))
- **Peer IP:** 192.168.4.21
- **Auto-Repair Mode:** DISABLED
- **Remediated Issues:** 0
- **Critical Failures Remaining:** 3

---

## 1. Canonical Sockets & Port Verification Matrix

| Service | Port | Container | Category | Critical | Status | Latency | Root-Cause Analysis / Notes |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Caddy Gateway HTTP** | 80 | caddy | INGRESS | **YES** | ONLINE | 4 ms | Operating normally |
| **Caddy Gateway HTTPS** | 443 | caddy | INGRESS | **YES** | ONLINE | 0 ms | Operating normally |
| **API Gateway REST** | 3000 | api-gateway | API | **YES** | FAILING | 1201 ms | Container 'api-gateway' is stopped / not created. |
| **Jellyfin Media Server** | 8096 | jellyfin | STREAMING | **YES** | ONLINE | 0 ms | Operating normally |
| **Sonarr TV Automation** | 8989 | sonarr | AUTOMATION | **YES** | ONLINE | 0 ms | Operating normally |
| **Radarr Movie Manager** | 7878 | radarr | AUTOMATION | **YES** | ONLINE | 0 ms | Operating normally |
| **Prowlarr Indexer** | 9696 | prowlarr | INDEXER | **YES** | FAILING | 1206 ms | Container 'prowlarr' is stopped / not created. |
| **Bazarr Subtitles** | 6767 | bazarr | SUBTITLES | **YES** | ONLINE | 0 ms | Operating normally |
| **Jellyseerr Requests** | 5055 | jellyseerr | REQUESTS | **YES** | FAILING | 1213 ms | Container 'jellyseerr' is stopped / not created. |
| **Transmission Web UI** | 9091 | transmission | TORRENT | **YES** | ONLINE | 0 ms | Operating normally |
| **Transmission Peer TCP** | 51413 | transmission | TORRENT | No | STANDBY | 1209 ms | Standby / optional node service not currently active. |
| **TVHeadend Web UI** | 9981 | tvheadend | LIVETV | **YES** | ONLINE | 0 ms | Operating normally |
| **TVHeadend HTSP Stream** | 9982 | tvheadend | LIVETV | No | ONLINE | 0 ms | Operating normally |
| **Mediastack DB GUI** | 8080 | mediastack-db | DATABASE | **YES** | ONLINE | 0 ms | Operating normally |
| **Syncthing Web GUI** | 8384 | syncthing | SYNC | No | STANDBY | 1201 ms | Standby / optional node service not currently active. |
| **Syncthing Peer TCP** | 22000 | syncthing | SYNC | No | STANDBY | 1210 ms | Standby / optional node service not currently active. |
| **MusicBrainz Secondary** | 5001 | musicbrainz | METADATA | No | ONLINE | 0 ms | Operating normally |
| **MusicBrainz Primary** | 5000 | remote | METADATA | No | ONLINE | 119 ms | Operating normally |

---

## 2. Reverse Proxy Subdomain Ingress Health

| Route Name | Target URL | HTTP Status | Response Time | Diagnostics |
| :--- | :--- | :--- | :--- | :--- |
| **Dashboard Ingress HTTP** | http://voltairedeux.local | 302 OK | 53 ms | HTTP 302 via curl |
| **Dashboard Ingress HTTPS** | https://voltairedeux.local | 302 OK | 57 ms | HTTP 302 via curl |
| **Jellyfin Subdomain HTTP** | http://jellyfin.voltairedeux.local | 302 OK | 1180 ms | HTTP 302 (Caddy Gateway Verified) |
| **Jellyfin Subdomain HTTPS** | https://jellyfin.voltairedeux.local | 302 OK | 44 ms | HTTP 302 (Caddy Gateway Verified) |
| **Sonarr Subdomain HTTPS** | https://sonarr.voltairedeux.local | 401 OK | 1146 ms | HTTP 401 (Caddy Gateway Verified) |
| **Radarr Subdomain HTTPS** | https://radarr.voltairedeux.local | 302 OK | 743 ms | HTTP 302 (Caddy Gateway Verified) |
| **Prowlarr Subdomain HTTPS** | https://prowlarr.voltairedeux.local | 0 WARN | 744 ms | HTTP 0 via curl |
| **Bazarr Subdomain HTTPS** | https://bazarr.voltairedeux.local | 200 OK | 959 ms | HTTP 200 (Caddy Gateway Verified) |
| **Jellyseerr Route HTTPS** | https://jellyseerr.voltairedeux.local | 0 WARN | 924 ms | HTTP 0 via curl |
| **API Gateway Route HTTPS** | https://api.voltairedeux.local | 308 OK | 942 ms | HTTP 308 (Caddy Gateway Verified) |
| **Database GUI Route HTTPS** | https://db.voltairedeux.local | 200 OK | 955 ms | HTTP 200 (Caddy Gateway Verified) |

---

## 3. Executive Assessment & Readiness

- **Port Health Status:** 3 Unresolved Critical Port Issues
- **Auto-Repair Success:** 0 auto-remediations applied
- **Cluster Readiness:** BLOCKED: Resolve critical port conflicts before continuing.

*Report archived in: C:\Users\waltd\OneDrive\Mediastack\handoffs\Proxy_Port_Diagnostic_Report_20260831_164608.md*
