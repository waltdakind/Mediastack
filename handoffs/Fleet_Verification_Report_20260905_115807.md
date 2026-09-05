# MediaStack Fleet Verification & Certification Report

| Parameter | Value |
| :--- | :--- |
| **Execution Host** | VOLTAIREDEUX (192.168.4.30) |
| **Peer Node** | VoltaireUn (192.168.4.21) |
| **Timestamp** | 2026-09-05 11:58:07 |
| **Health Index** | **91.4%** |
| **Operational Verdict** | **CERTIFIED HEALTHY** |
| **Points Passed** | 32 / 35 |

---

## Detailed Verification Results
| Category | Verification Item | Status | Result Details |
| :--- | :--- | :--- | :--- |
| Runtime | Docker Engine Daemon | PASS | Version 29.7.2 |
| Containers | Container: caddy | PASS | Status: RUNNING (Started: 2026-09-05T15:08:57.9472213Z) |
| Containers | Container: jellyfin | PASS | Status: RUNNING (Started: 2026-09-05T15:08:57.9504467Z) |
| Containers | Container: sonarr | PASS | Status: RUNNING (Started: 2026-09-05T15:08:57.8554566Z) |
| Containers | Container: radarr | PASS | Status: RUNNING (Started: 2026-09-05T15:08:57.8165909Z) |
| Containers | Container: prowlarr | FAIL | Status: STOPPED (Started: N/A) |
| Containers | Container: bazarr | PASS | Status: RUNNING (Started: 2026-09-05T15:08:57.8341032Z) |
| Containers | Container: seerr | PASS | Status: RUNNING (Started: 2026-09-05T15:32:54.343505188Z) |
| Containers | Container: syncthing | PASS | Status: RUNNING (Started: 2026-09-05T15:08:57.9914666Z) |
| Containers | Container: transmission | PASS | Status: RUNNING (Started: 2026-09-05T15:08:57.9137576Z) |
| Containers | Container: mediastack-db | PASS | Status: RUNNING (Started: 2026-09-05T15:08:57.959995Z) |
| HTTP | Caddy Reverse Proxy | PASS | HTTP 301 (TTFB: 3.9ms) |
| HTTP | Jellyfin Stream | PASS | HTTP 307 (TTFB: 13.8ms) |
| HTTP | Sonarr TV Manager | PASS | HTTP 200 (TTFB: 45.9ms) |
| HTTP | Radarr Movies | PASS | HTTP 200 (TTFB: 5ms) |
| HTTP | Prowlarr Indexers | PASS | HTTP 200 (TTFB: 7ms) |
| HTTP | Bazarr Subtitles | PASS | HTTP 200 (TTFB: 7.1ms) |
| HTTP | Seerr Requests | PASS | HTTP 200 (TTFB: 8.7ms) |
| HTTP | Syncthing P2P Mesh | PASS | HTTP 200 (TTFB: 4.1ms) |
| HTTP | Transmission Web | PASS | HTTP 200 (TTFB: 2.5ms) |
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
*Certified by MediaStack Primary Fleet Verification Suite.*
