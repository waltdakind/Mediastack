# MediaStack Database Health, Integrity & Optimization Report

| Parameter | Value |
| :--- | :--- |
| **Optimization Timestamp** | 2026-09-05 11:24:35 |
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
| MediaStack Backup DB | PASS | PASS | 184 KB | 184 KB | 0 KB | 0% |
| Sonarr Database | FAIL: *** in database main *** Tree 25 page 523 cell 9: Rowid 7776 out of order Tree 25 page 522 cell 9: Rowid 7766 out of order Page 742: never used Page 743: never used Page 744: never used Page 745: never used Page 746: never used Page 747: never used Page 748: never used Page 749: never used Page 750: never used Page 751: never used Page 752: never used Page 753: never used Page 754: never used Page 755: never used Page 756: never used Page 757: never used Page 758: never used Page 759: never used Page 760: never used | WARN | 3200 KB | 3200 KB | 0 KB | 0% |
| Radarr Database | PASS | PASS | 1128 KB | 1128 KB | 0 KB | 0% |
| Prowlarr Database | PASS | PASS | 356 KB | 356 KB | 0 KB | 0% |
| Bazarr Database | PASS | PASS | 316 KB | 316 KB | 0 KB | 0% |
| Jellyseerr Database | PASS | PASS | 220 KB | 220 KB | 0 KB | 0% |
| Jellyfin Main DB | PASS | PASS | 56424 KB | 56424 KB | 0 KB | 0% |

---
*Report generated automatically by MediaStack Database Optimizer Engine.*
