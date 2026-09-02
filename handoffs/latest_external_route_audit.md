# [REPORT] External Route and HTTPS Ingress Audit

| Audit Parameter | Target / Result | Status |
| :--- | :--- | :---: |
| **Target Endpoint** | https://waltdakind.xubi.org/dashboard/ | PASS |
| **Resolved WAN IP** | $targetIp | PASS |
| **Origin Node WAN IP** | $myWanIp | PASS |
| **Routing Type** | Remote WAN Route | PASS |
| **Primary HTTPS (:443)** | Active (TLSv1.3) | PASS |
| **Fallback HTTPS (:444)** | HTTP 0 | STANDBY |
| **Audit Timestamp** | 2026-09-02 13:56:17 | PASS |

---

## 1. External L7 Route Status Matrix (via https://waltdakind.xubi.org)

| Service Name | Direct HTTPS Route | Target Path | HTTP Response | Latency | Route Health |
| :--- | :--- | :---: | :---: | :---: | :---: |
| **Mission Control Dashboard** | [Launch](https://waltdakind.xubi.org/dashboard/) | $(@{Name=Mission Control Dashboard; Path=/dashboard/; Url=https://waltdakind.xubi.org/dashboard/; Code=0; Latency=291 ms; Success=False; Error=}.Path) | HTTP 0 | $(@{Name=Mission Control Dashboard; Path=/dashboard/; Url=https://waltdakind.xubi.org/dashboard/; Code=0; Latency=291 ms; Success=False; Error=}.Latency) | UNREACHABLE |
| **Jellyfin Streaming Gateway** | [Launch](https://waltdakind.xubi.org/) | $(@{Name=Jellyfin Streaming Gateway; Path=/; Url=https://waltdakind.xubi.org/; Code=302; Latency=162 ms; Success=True; Error=}.Path) | HTTP 302 | $(@{Name=Jellyfin Streaming Gateway; Path=/; Url=https://waltdakind.xubi.org/; Code=302; Latency=162 ms; Success=True; Error=}.Latency) | OPERATIONAL |
| **Sonarr TV Automation** | [Launch](https://waltdakind.xubi.org/sonarr/) | $(@{Name=Sonarr TV Automation; Path=/sonarr/; Url=https://waltdakind.xubi.org/sonarr/; Code=0; Latency=100 ms; Success=False; Error=}.Path) | HTTP 0 | $(@{Name=Sonarr TV Automation; Path=/sonarr/; Url=https://waltdakind.xubi.org/sonarr/; Code=0; Latency=100 ms; Success=False; Error=}.Latency) | UNREACHABLE |
| **Radarr Movie Manager** | [Launch](https://waltdakind.xubi.org/radarr/) | $(@{Name=Radarr Movie Manager; Path=/radarr/; Url=https://waltdakind.xubi.org/radarr/; Code=0; Latency=40 ms; Success=False; Error=}.Path) | HTTP 0 | $(@{Name=Radarr Movie Manager; Path=/radarr/; Url=https://waltdakind.xubi.org/radarr/; Code=0; Latency=40 ms; Success=False; Error=}.Latency) | UNREACHABLE |
| **Prowlarr Indexer Proxy** | [Launch](https://waltdakind.xubi.org/prowlarr/) | $(@{Name=Prowlarr Indexer Proxy; Path=/prowlarr/; Url=https://waltdakind.xubi.org/prowlarr/; Code=0; Latency=56 ms; Success=False; Error=}.Path) | HTTP 0 | $(@{Name=Prowlarr Indexer Proxy; Path=/prowlarr/; Url=https://waltdakind.xubi.org/prowlarr/; Code=0; Latency=56 ms; Success=False; Error=}.Latency) | UNREACHABLE |
| **Bazarr Subtitles** | [Launch](https://waltdakind.xubi.org/bazarr/) | $(@{Name=Bazarr Subtitles; Path=/bazarr/; Url=https://waltdakind.xubi.org/bazarr/; Code=0; Latency=62 ms; Success=False; Error=}.Path) | HTTP 0 | $(@{Name=Bazarr Subtitles; Path=/bazarr/; Url=https://waltdakind.xubi.org/bazarr/; Code=0; Latency=62 ms; Success=False; Error=}.Latency) | UNREACHABLE |
| **Jellyseerr Media Requests** | [Launch](https://waltdakind.xubi.org/jellyseerr/) | $(@{Name=Jellyseerr Media Requests; Path=/jellyseerr/; Url=https://waltdakind.xubi.org/jellyseerr/; Code=0; Latency=47 ms; Success=False; Error=}.Path) | HTTP 0 | $(@{Name=Jellyseerr Media Requests; Path=/jellyseerr/; Url=https://waltdakind.xubi.org/jellyseerr/; Code=0; Latency=47 ms; Success=False; Error=}.Latency) | UNREACHABLE |
| **Transmission Torrent UI** | [Launch](https://waltdakind.xubi.org/transmission/web/) | $(@{Name=Transmission Torrent UI; Path=/transmission/web/; Url=https://waltdakind.xubi.org/transmission/web/; Code=0; Latency=36 ms; Success=False; Error=}.Path) | HTTP 0 | $(@{Name=Transmission Torrent UI; Path=/transmission/web/; Url=https://waltdakind.xubi.org/transmission/web/; Code=0; Latency=36 ms; Success=False; Error=}.Latency) | UNREACHABLE |
| **TVHeadend Live Gateway** | [Launch](https://waltdakind.xubi.org/tvheadend/) | $(@{Name=TVHeadend Live Gateway; Path=/tvheadend/; Url=https://waltdakind.xubi.org/tvheadend/; Code=0; Latency=38 ms; Success=False; Error=}.Path) | HTTP 0 | $(@{Name=TVHeadend Live Gateway; Path=/tvheadend/; Url=https://waltdakind.xubi.org/tvheadend/; Code=0; Latency=38 ms; Success=False; Error=}.Latency) | UNREACHABLE |
| **MediaStack SQLite DB GUI** | [Launch](https://waltdakind.xubi.org/db/) | $(@{Name=MediaStack SQLite DB GUI; Path=/db/; Url=https://waltdakind.xubi.org/db/; Code=0; Latency=77 ms; Success=False; Error=}.Path) | HTTP 0 | $(@{Name=MediaStack SQLite DB GUI; Path=/db/; Url=https://waltdakind.xubi.org/db/; Code=0; Latency=77 ms; Success=False; Error=}.Latency) | UNREACHABLE |
| **API Gateway REST Endpoint** | [Launch](https://waltdakind.xubi.org/api/health) | $(@{Name=API Gateway REST Endpoint; Path=/api/health; Url=https://waltdakind.xubi.org/api/health; Code=0; Latency=3531 ms; Success=False; Error=}.Path) | HTTP 0 | $(@{Name=API Gateway REST Endpoint; Path=/api/health; Url=https://waltdakind.xubi.org/api/health; Code=0; Latency=3531 ms; Success=False; Error=}.Latency) | UNREACHABLE |

---

## 2. L4 Sockets and Port Status on waltdakind.xubi.org

| Port | Target Service / Role | Socket State | Response Time | Diagnostics |
| :---: | :--- | :---: | :---: | :--- |
| :80 | HTTP Primary Ingress | CLOSED / STANDBY | 1525 ms | Timeout (1500ms) |
| :443 | HTTPS Primary Ingress | OPEN | 38 ms | Active Listener |
| :81 | HTTP Fallback Ingress | CLOSED / STANDBY | 1500 ms | Timeout (1500ms) |
| :444 | HTTPS Fallback Ingress | CLOSED / STANDBY | 1513 ms | Timeout (1500ms) |
| :8097 | Jellyfin Fallback (+1) | CLOSED / STANDBY | 1506 ms | Timeout (1500ms) |
| :8990 | Sonarr Fallback (+1) | CLOSED / STANDBY | 1514 ms | Timeout (1500ms) |
| :7879 | Radarr Fallback (+1) | CLOSED / STANDBY | 1511 ms | Timeout (1500ms) |
| :9697 | Prowlarr Fallback (+1) | CLOSED / STANDBY | 1502 ms | Timeout (1500ms) |
| :6768 | Bazarr Fallback (+1) | CLOSED / STANDBY | 1513 ms | Timeout (1500ms) |
| :5056 | Jellyseerr Fallback (+1) | CLOSED / STANDBY | 1514 ms | Timeout (1500ms) |
| :9092 | Transmission Fallback (+1) | CLOSED / STANDBY | 1514 ms | Timeout (1500ms) |
| :8081 | SQLite DB Fallback (+1) | CLOSED / STANDBY | 1512 ms | Timeout (1500ms) |

---

## 3. Direct Clickable Navigation Links

- **Mission Control Dashboard:** [https://waltdakind.xubi.org/dashboard/](https://waltdakind.xubi.org/dashboard/)
- **Fallback HTTPS Ingress (:444):** [https:///dashboard/](https:///dashboard/)
- **Jellyfin Media Server:** [https://waltdakind.xubi.org/](https://waltdakind.xubi.org/)
- **Sonarr TV Automation:** [https://waltdakind.xubi.org/sonarr/](https://waltdakind.xubi.org/sonarr/)
- **Radarr Movie Manager:** [https://waltdakind.xubi.org/radarr/](https://waltdakind.xubi.org/radarr/)
- **Prowlarr Indexer Proxy:** [https://waltdakind.xubi.org/prowlarr/](https://waltdakind.xubi.org/prowlarr/)
- **Bazarr Subtitles:** [https://waltdakind.xubi.org/bazarr/](https://waltdakind.xubi.org/bazarr/)
- **Jellyseerr Requests:** [https://waltdakind.xubi.org/jellyseerr/](https://waltdakind.xubi.org/jellyseerr/)
- **Transmission Web UI:** [https://waltdakind.xubi.org/transmission/web/](https://waltdakind.xubi.org/transmission/web/)
- **TVHeadend Tuner:** [https://waltdakind.xubi.org/tvheadend/](https://waltdakind.xubi.org/tvheadend/)
- **MediaStack SQLite DB:** [https://waltdakind.xubi.org/db/](https://waltdakind.xubi.org/db/)

---
*Report automatically synthesized by MediaStack External Route Audit Suite.*