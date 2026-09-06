# MediaStack Fleet Verification & Certification Report

| Parameter | Value |
| :--- | :--- |
| **Execution Host** | VOLTAIREDEUX (192.168.4.30) |
| **Peer Node** | VoltaireUn (192.168.4.21) |
| **Timestamp** | 2026-09-06 17:36:20 |
| **Health Index** | **89.7%** |
| **Operational Verdict** | **FUNCTIONAL WITH WARNINGS** |
| **Points Passed** | 35 / 39 |

---

## Detailed Verification Results
| Category | Verification Item | Status | Result Details |
| :--- | :--- | :--- | :--- |
| Runtime | Docker Engine Daemon | PASS | Version 29.7.2 |
| Containers | Container: caddy | PASS | Status: RUNNING (Started: 2026-09-06T18:09:39.815359643Z) |
| Containers | Container: jellyfin | PASS | Status: RUNNING (Started: 2026-09-06T18:09:08.671858394Z) |
| Containers | Container: sonarr | PASS | Status: RUNNING (Started: 2026-09-06T18:11:07.169965305Z) |
| Containers | Container: radarr | PASS | Status: RUNNING (Started: 2026-09-06T14:32:57.479328199Z) |
| Containers | Container: prowlarr | PASS | Status: RUNNING (Started: 2026-09-06T18:30:19.607924733Z) |
| Containers | Container: bazarr | PASS | Status: RUNNING (Started: 2026-09-06T14:32:57.431615094Z) |
| Containers | Container: seerr | PASS | Status: RUNNING (Started: 2026-09-06T14:32:57.437915512Z) |
| Containers | Container: syncthing | PASS | Status: RUNNING (Started: 2026-09-05T15:08:57.9914666Z) |
| Containers | Container: transmission | PASS | Status: RUNNING (Started: 2026-09-06T14:32:57.537008907Z) |
| Containers | Container: mediastack-db | PASS | Status: RUNNING (Started: 2026-09-06T18:12:22.172438168Z) |
| Containers | Container: tdarr | PASS | Status: RUNNING (Started: 2026-09-06T14:32:57.455203583Z) |
| Containers | Container: qbittorrent | FAIL | Status: STOPPED (Started: N/A) |
| HTTP | Caddy Reverse Proxy | PASS | HTTP 301 (TTFB: 6.6ms) |
| HTTP | Jellyfin Stream | PASS | HTTP 200 (TTFB: 12.7ms) |
| HTTP | Sonarr TV Manager | PASS | HTTP 200 (TTFB: 12.1ms) |
| HTTP | Radarr Movies | PASS | HTTP 200 (TTFB: 7.7ms) |
| HTTP | Prowlarr Indexers | PASS | HTTP 200 (TTFB: 208.3ms) |
| HTTP | Bazarr Subtitles | PASS | HTTP 200 (TTFB: 278.6ms) |
| HTTP | Seerr Requests | PASS | HTTP 200 (TTFB: 301.1ms) |
| HTTP | Syncthing P2P Mesh | PASS | HTTP 200 (TTFB: 13ms) |
| HTTP | Transmission Web | PASS | HTTP 200 (TTFB: 7.3ms) |
| HTTP | qBittorrent WebUI | FAIL | HTTP 000 (TTFB: 2232.5ms) |
| API Auth | Sonarr REST API Auth | PASS | HTTP 200 (Authenticated) |
| API Auth | Radarr REST API Auth | PASS | HTTP 200 (Authenticated) |
| API Auth | Prowlarr REST API Auth | PASS | HTTP 200 (Authenticated) |
| Databases | SQLite Lock Verification | FAIL | 4 dangling journal/lock files found |
| Databases | SQLite Web Interface (:8080) | PASS | HTTP 200 |
| Ingress | Virtual Host: voltairedeux.local | PASS | HTTP 301 |
| Ingress | Virtual Host: jellyfin.voltairedeux.local | PASS | HTTP 301 |
| Ingress | Virtual Host: radarr.voltairedeux.local | PASS | HTTP 301 |
| Ingress | Virtual Host: sonarr.voltairedeux.local | PASS | HTTP 301 |
| Ingress | Virtual Host: musicbrainz.voltairedeux.local | PASS | HTTP 301 |
| Ingress | Virtual Host: tdarr.voltairedeux.local | PASS | HTTP 301 |
| Cluster | VoltaireUn Peer Link | PASS | IP: 192.168.4.21 (Latency: <1ms) |
| Cluster | VoltaireUn MusicBrainz (:5000) | PASS | HTTP 000 |


---
*Certified by MediaStack Primary Fleet Verification Suite.*
