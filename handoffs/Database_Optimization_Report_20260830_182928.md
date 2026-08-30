# MediaStack Database Health, Integrity & Optimization Report

| Parameter | Value |
| :--- | :--- |
| **Optimization Timestamp** | 2026-08-30 18:29:28 |
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
| MediaStack Backup DB | PASS | PASS | 116 KB | 116 KB | 0 KB | 0% |
| Sonarr Database | PASS | PASS | 2916 KB | 2916 KB | 0 KB | 0% |
| Radarr Database | FAIL: *** in database main *** Tree 45 page 647: btreeInitPage() returns error code 11 Tree 45 page 646: btreeInitPage() returns error code 11 Tree 45 page 645: btreeInitPage() returns error code 11 Tree 45 page 644: btreeInitPage() returns error code 11 Tree 45 page 643: btreeInitPage() returns error code 11 Tree 45 page 642: btreeInitPage() returns error code 11 Tree 45 page 641: btreeInitPage() returns error code 11 Tree 45 page 640: btreeInitPage() returns error code 11 Tree 45 page 639: btreeInitPage() returns error code 11 Tree 45 page 638: btreeInitPage() returns error code 11 Tree 45 page 636: btreeInitPage() returns error code 11 Tree 45 page 635: btreeInitPage() returns error code 11 Tree 45 page 634: btreeInitPage() returns error code 11 Tree 45 page 633: btreeInitPage() returns error code 11 Tree 45 page 632: btreeInitPage() returns error code 11 Tree 45 page 631: btreeInitPage() returns error code 11 Tree 45 page 630: btreeInitPage() returns error code 11 Tree 45 page 629: btreeInitPage() returns error code 11 Tree 45 page 628: btreeInitPage() returns error code 11 Tree 45 page 627: btreeInitPage() returns error code 11 Tree 45 page 626: btreeInitPage() returns error code 11 Error: stepping, database disk image is malformed (11) Tree 46 page 637: btreeInitPage() returns error code 11 | WARN | 2636 KB | 2636 KB | 0 KB | 0% |
| Prowlarr Database | PASS | PASS | 336 KB | 336 KB | 0 KB | 0% |
| Bazarr Database | PASS | PASS | 316 KB | 316 KB | 0 KB | 0% |
| Jellyseerr Database | PASS | PASS | 220 KB | 220 KB | 0 KB | 0% |
| Jellyfin Main DB | PASS | PASS | 36188 KB | 36188 KB | 0 KB | 0% |

---
*Report generated automatically by MediaStack Database Optimizer Engine.*
