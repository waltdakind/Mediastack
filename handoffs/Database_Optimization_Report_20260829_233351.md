# MediaStack Database Health, Integrity & Optimization Report

| Parameter | Value |
| :--- | :--- |
| **Optimization Timestamp** | 2026-08-29 23:33:51 |
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
| MediaStack Backup DB | PASS | PASS | 92 KB | 92 KB | 0 KB | 0% |
| Sonarr Database | PASS | PASS | 68 KB | 68 KB | 0 KB | 0% |
| Radarr Database | FAIL: *** in database main *** Tree 45 page 647: btreeInitPage() returns error code 11 Tree 45 page 646: btreeInitPage() returns error code 11 Tree 45 page 645: btreeInitPage() returns error code 11 Tree 45 page 644: btreeInitPage() returns error code 11 Tree 45 page 643: btreeInitPage() returns error code 11 Tree 45 page 642: btreeInitPage() returns error code 11 Tree 45 page 641: btreeInitPage() returns error code 11 Tree 45 page 640: btreeInitPage() returns error code 11 Tree 45 page 639: btreeInitPage() returns error code 11 Tree 45 page 638: btreeInitPage() returns error code 11 Tree 45 page 636: btreeInitPage() returns error code 11 Tree 45 page 635: btreeInitPage() returns error code 11 Tree 45 page 634: btreeInitPage() returns error code 11 Tree 45 page 633: btreeInitPage() returns error code 11 Tree 45 page 632: btreeInitPage() returns error code 11 Tree 45 page 631: btreeInitPage() returns error code 11 Tree 45 page 630: btreeInitPage() returns error code 11 Tree 45 page 629: btreeInitPage() returns error code 11 Tree 45 page 628: btreeInitPage() returns error code 11 Tree 45 page 627: btreeInitPage() returns error code 11 Tree 45 page 626: btreeInitPage() returns error code 11 Tree 46 page 637: btreeInitPage() returns error code 11 Error: stepping, database disk image is malformed (11) | PASS | 68 KB | 68 KB | 0 KB | 0% |
| Prowlarr Database | FAIL: Error: in prepare, database disk image is malformed (11) | FAIL | 36 KB | 36 KB | 0 KB | 0% |
| Bazarr Database | PASS | PASS | 1388 KB | 1388 KB | 0 KB | 0% |
| Jellyseerr Database | PASS | PASS | 4 KB | 4 KB | 0 KB | 0% |
| Jellyfin Main DB | FAIL: Error: stepping, database disk image is malformed (11) | FAIL | 456 KB | 456 KB | 0 KB | 0% |

---
*Report generated automatically by MediaStack Database Optimizer Engine.*
