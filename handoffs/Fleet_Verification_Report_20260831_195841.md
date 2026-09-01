# MediaStack Fleet Verification & Certification Report

| Parameter | Value |
| :--- | :--- |
| **Execution Host** | VOLTAIREDEUX (192.168.4.30) |
| **Peer Node** | VoltaireUn (192.168.4.21) |
| **Timestamp** | 2026-08-31 19:58:41 |
| **Health Index** | **88.6%** |
| **Operational Verdict** | **FUNCTIONAL WITH WARNINGS** |
| **Points Passed** | 31 / 35 |

---

## Detailed Verification Results
| Category | Verification Item | Status | Result Details |
| :--- | :--- | :--- | :--- |
| Runtime | Docker Engine Daemon | PASS | Version 29.7.2 |
| Containers | Container: caddy | PASS | Status: RUNNING (Started: 2026-08-31T23:38:27.954200722Z) |
| Containers | Container: jellyfin | PASS | Status: RUNNING (Started: 2026-08-31T23:38:23.173230591Z) |
| Containers | Container: sonarr | PASS | Status: RUNNING (Started: 2026-08-31T23:38:20.454072494Z) |
| Containers | Container: radarr | PASS | Status: RUNNING (Started: 2026-08-31T23:38:20.617481202Z) |
| Containers | Container: prowlarr | FAIL | Status: STOPPED (Started: N/A) |
| Containers | Container: bazarr | PASS | Status: RUNNING (Started: 2026-08-31T23:38:20.814119918Z) |
| Containers | Container: jellyseerr | FAIL | Status: STOPPED (Started: N/A) |
| Containers | Container: syncthing | PASS | Status: RUNNING (Started: 2026-08-31T23:38:23.498314816Z) |
| Containers | Container: transmission | PASS | Status: RUNNING (Started: 2026-08-31T23:38:23.999346493Z) |
| Containers | Container: mediastack-db | PASS | Status: RUNNING (Started: 2026-08-31T23:38:17.174600687Z) |
| HTTP | Caddy Reverse Proxy | PASS | HTTP 301 (TTFB: 3.8ms) |
| HTTP | Jellyfin Stream | PASS | HTTP 302 (TTFB: 2.6ms) |
| HTTP | Sonarr TV Manager | PASS | HTTP 200 (TTFB: 9.9ms) |
| HTTP | Radarr Movies | PASS | HTTP 200 (TTFB: 5ms) |
| HTTP | Prowlarr Indexers | PASS | HTTP 200 (TTFB: 9.8ms) |
| HTTP | Bazarr Subtitles | PASS | HTTP 200 (TTFB: 29.4ms) |
| HTTP | Jellyseerr Requests | PASS | HTTP 200 (TTFB: 164.6ms) |
| HTTP | Syncthing P2P Mesh | PASS | HTTP 200 (TTFB: 3.9ms) |
| HTTP | Transmission Web | PASS | HTTP 200 (TTFB: 3.1ms) |
| API Auth | Sonarr REST API Auth | PASS | HTTP 200 (Authenticated) |
| API Auth | Radarr REST API Auth | PASS | HTTP 200 (Authenticated) |
| API Auth | Prowlarr REST API Auth | PASS | HTTP 200 (Authenticated) |
| Databases | SQLite Lock Verification | FAIL | 6 dangling journal/lock files found |
| Databases | SQLite Web Interface (:8080) | PASS | HTTP 200 |
| Ingress | Virtual Host: voltairedeux.local | PASS | HTTP 301 |
| Ingress | Virtual Host: jellyfin.voltairedeux.local | PASS | HTTP 301 |
| Ingress | Virtual Host: radarr.voltairedeux.local | PASS | HTTP 301 |
| Ingress | Virtual Host: sonarr.voltairedeux.local | PASS | HTTP 301 |
| Ingress | Virtual Host: musicbrainz.voltairedeux.local | PASS | HTTP 301 |
| Cluster | VoltaireUn Peer Link | PASS | IP: 192.168.4.21 (Latency: <1ms) |
| Cluster | VoltaireUn MusicBrainz (:5000) | PASS | HTTP 000 |


---
*Certified by MediaStack Master Fleet Verification Suite.*
