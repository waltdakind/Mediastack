# MediaStack Enterprise Fleet Deployment Report

| Parameter | Value |
| :--- | :--- |
| **Deployment Timestamp** | 2026-08-29 00:23:51 |
| **Host Machine** | VOLTAIREDEUX |
| **Deployment Duration** | 42.8s |
| **Boot Sentinel ID** | $bootId |
| **Overall Fleet Health** | 100% OPERATIONAL |
| **CRUD Verification** | PASS (100%) |
| **Databases Verified** | 7 |

---

## Database Persistence & Hot-Restore Summary
| Database | Valid | Hot-Restored | Details |
| :--- | :--- | :--- | :--- |
| MediaStack Backup DB | PASS | NO | Integrity Check Passed (92 KB) |
| Sonarr Database | PASS | NO | Integrity Check Passed (1388 KB) |
| Radarr Database | PASS | NO | Integrity Check Passed (872 KB) |
| Prowlarr Database | PASS | NO | Integrity Check Passed (1400 KB) |
| Bazarr Database | PASS | NO | Integrity Check Passed (1388 KB) |
| Jellyseerr Database | PASS | NO | Integrity Check Passed (4 KB) |
| Jellyfin Main DB | PASS | NO | Integrity Check Passed (456 KB) |

---

## Service Port Probing Matrix
| Service Name | Port | Status | Latency |
| :--- | :--- | :--- | :--- |
| Caddy Gateway HTTP | 80 | OPEN | 0ms |
| Caddy Gateway HTTPS | 443 | OPEN | 0ms |
| Jellyfin Media Server | 8096 | OPEN | 0ms |
| Sonarr TV Automation | 8989 | OPEN | 0ms |
| Radarr Movie Manager | 7878 | OPEN | 0ms |
| Prowlarr Indexer | 9696 | OPEN | 0ms |
| Bazarr Subtitles | 6767 | OPEN | 0ms |
| Jellyseerr Requests | 5055 | OPEN | 0ms |
| Transmission Web UI | 9091 | OPEN | 0ms |
| Transmission Peer TCP | 51413 | CLOSED | 1002ms |
| TVHeadend Web UI | 9981 | OPEN | 0ms |
| TVHeadend HTSP Stream | 9982 | OPEN | 0ms |
| API Gateway REST | 3000 | OPEN | 0ms |
| Mediastack SQLite DB | 8080 | CLOSED | 1010ms |
| MusicBrainz (Port 5000) | 5000 | OPEN | 0ms |
| MusicBrainz (Port 5001) | 5001 | OPEN | 0ms |

---
*Report generated automatically by MediaStack Enterprise Deployer Engine.*
