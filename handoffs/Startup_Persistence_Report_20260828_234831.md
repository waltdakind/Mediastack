# MediaStack Startup & Database Persistence Report

| Parameter | Value |
| :--- | :--- |
| **Startup Timestamp** | 2026-08-28 23:48:31 |
| **Host System** | VOLTAIREDEUX |
| **Boot Sentinel ID** | $bootId |
| **CRUD Lifecycle Test** | PASS (100%) |
| **Databases Inspected** | 7 |
| **Auto-Restored Databases** | 0 |

---

## Database Persistence & Recovery Telemetry
| Database Name | Valid | Auto-Restored | Status & Diagnostics |
| :--- | :--- | :--- | :--- |
| MediaStack Backup DB | PASS | NO | Integrity OK (92 KB) |
| Sonarr Database | FAIL | NO | UNRESOLVED PERSISTENCE FAILURE |
| Radarr Database | PASS | NO | Integrity OK (872 KB) |
| Prowlarr Database | FAIL | NO | UNRESOLVED PERSISTENCE FAILURE |
| Bazarr Database | FAIL | NO | UNRESOLVED PERSISTENCE FAILURE |
| Jellyseerr Database | PASS | NO | Integrity OK (4 KB) |
| Jellyfin Main DB | PASS | NO | Integrity OK (456 KB) |

---

## CRUD Capability Lifecycle Verification
| Operation | Result | Description |
| :--- | :--- | :--- |
| **CREATE (Insert)** | PASS | Inserted dynamic test row with UUID |
| **READ (Select)** | PASS | Successfully queried matching payload |
| **UPDATE (Modify)** | PASS | Successfully updated and verified payload |
| **DELETE (Purge)** | PASS | Purged record and verified 0 remaining rows |
| **PRAGMA Check** | PASS | Database constraints and integrity verified |

---

## Stack Port & Network Status
| Service Name | Port | Listener Status | Latency |
| :--- | :--- | :--- | :--- |
| Caddy Gateway HTTP | 80 | OPEN | 22ms |
| Caddy Gateway HTTPS | 443 | OPEN | 0ms |
| Jellyfin Media Server | 8096 | OPEN | 0ms |
| Sonarr TV Automation | 8989 | OPEN | 0ms |
| Radarr Movie Manager | 7878 | OPEN | 0ms |
| Prowlarr Indexer | 9696 | OPEN | 0ms |
| Bazarr Subtitles | 6767 | OPEN | 0ms |
| Jellyseerr Requests | 5055 | OPEN | 0ms |
| Transmission Web UI | 9091 | OPEN | 0ms |
| Transmission Peer TCP | 51413 | OPEN | 0ms |
| TVHeadend Web UI | 9981 | OPEN | 0ms |
| TVHeadend HTSP Stream | 9982 | OPEN | 0ms |
| API Gateway REST | 3000 | OPEN | 0ms |
| Mediastack SQLite DB | 8080 | OPEN | 0ms |
| MusicBrainz (Port 5000) | 5000 | FAIL | 1004ms |
| MusicBrainz (Port 5001) | 5001 | OPEN | 0ms |

---
*Report generated automatically by MediaStack Startup & Persistence Engine.*
