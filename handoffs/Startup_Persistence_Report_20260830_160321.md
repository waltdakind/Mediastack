# MediaStack Startup & Database Persistence Report

| Parameter | Value |
| :--- | :--- |
| **Startup Timestamp** | 2026-08-30 16:03:21 |
| **Host System** | ORDINATEURDEVOL |
| **Boot Sentinel ID** | $bootId |
| **CRUD Lifecycle Test** | PASS (100%) |
| **Databases Inspected** | 7 |
| **Auto-Restored Databases** |  |

---

## Database Persistence & Recovery Telemetry
| Database Name | Valid | Auto-Restored | Status & Diagnostics |
| :--- | :--- | :--- | :--- |
| MediaStack Backup DB | PASS | YES | Auto-Restored from mediastack_backup.db (Integrity: OK) |
| Sonarr Database | FAIL | NO | UNRESOLVED PERSISTENCE FAILURE |
| Radarr Database | FAIL | NO | UNRESOLVED PERSISTENCE FAILURE |
| Prowlarr Database | FAIL | NO | UNRESOLVED PERSISTENCE FAILURE |
| Bazarr Database | FAIL | NO | UNRESOLVED PERSISTENCE FAILURE |
| Jellyseerr Database | FAIL | NO | UNRESOLVED PERSISTENCE FAILURE |
| Jellyfin Main DB | FAIL | NO | UNRESOLVED PERSISTENCE FAILURE |

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
| Caddy Gateway HTTP | 80 | OPEN | 78ms |
| Caddy Gateway HTTPS | 443 | OPEN | 2ms |
| Jellyfin Media Server | 8096 | OPEN | 1ms |
| Sonarr TV Automation | 8989 | OPEN | 2ms |
| Radarr Movie Manager | 7878 | OPEN | 5ms |
| Prowlarr Indexer | 9696 | OPEN | 1ms |
| Bazarr Subtitles | 6767 | OPEN | 3ms |
| Jellyseerr Requests | 5055 | OPEN | 1ms |
| Transmission Web UI | 9091 | OPEN | 3ms |
| Transmission Peer TCP | 51413 | FAIL | 1013ms |
| TVHeadend Web UI | 9981 | OPEN | 16ms |
| TVHeadend HTSP Stream | 9982 | OPEN | 1ms |
| API Gateway REST | 3000 | OPEN | 1ms |
| Mediastack SQLite DB | 8080 | OPEN | 7ms |
| MusicBrainz (Port 5000) | 5000 | OPEN | 1ms |
| MusicBrainz (Port 5001) | 5001 | OPEN | 4ms |

---
*Report generated automatically by MediaStack Startup & Persistence Engine.*
