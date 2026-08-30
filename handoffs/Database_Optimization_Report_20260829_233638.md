# MediaStack Database Health, Integrity & Optimization Report

| Parameter | Value |
| :--- | :--- |
| **Optimization Timestamp** | 2026-08-29 23:36:38 |
| **Host System** | VOLTAIREDEUX |
| **Database Port (Web GUI)** | Port 8080 (Status: OPEN) |
| **CRUD Capabilities Check** | PASS (Create, Read, Update, Delete: 100%) |
| **Databases Inspected** | 7 |
| **Total Space Reclaimed** | 0 KB (0%) |

---

## Database Port & CRUD Startup Verification
| Operation | Status | Details |
| :--- | :--- | :--- |
| Port 8080 Listener | PASS | TCP Socket & HTTP GUI Responding |
| CREATE (Insert) | PASS | Inserted dynamic test row with UUID |
| READ (Select) | PASS | Successfully queried matching payload |
| UPDATE (Modify) | PASS | Successfully updated and verified payload |
| DELETE (Purge) | PASS | Purged record and verified 0 remaining rows |
| PRAGMA Check | PASS | Database constraints and integrity verified |

---

## Database Integrity & Compression Telemetry
| Database Name | Integrity | FK Check | Initial Size | Optimized Size | Reclaimed | Reduction |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| MediaStack Backup DB | PASS | PASS | 124 KB | 124 KB | 0 KB | 0% |
| Sonarr Database | PASS | PASS | 368 KB | 368 KB | 0 KB | 0% |
| Radarr Database | PASS | PASS | 2636 KB | 2636 KB | 0 KB | 0% |
| Prowlarr Database | PASS | PASS | 376 KB | 376 KB | 0 KB | 0% |
| Bazarr Database | PASS | PASS | 316 KB | 316 KB | 0 KB | 0% |
| Jellyseerr Database | PASS | PASS | 220 KB | 220 KB | 0 KB | 0% |
| Jellyfin Main DB | PASS | PASS | 46764 KB | 46764 KB | 0 KB | 0% |

---
*Report generated automatically by MediaStack Database Optimizer Engine.*
