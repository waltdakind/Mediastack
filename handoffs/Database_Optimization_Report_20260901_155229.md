# MediaStack Database Health, Integrity & Optimization Report

| Parameter | Value |
| :--- | :--- |
| **Optimization Timestamp** | 2026-09-01 15:52:29 |
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
| MediaStack Backup DB | PASS | PASS | 144 KB | 144 KB | 0 KB | 0% |
| Sonarr Database | FAIL: *** in database main *** Tree 41 page 613 cell 8: Rowid 3267 out of order Tree 25 page 25 cell 124: Rowid 3456 out of order Tree 25 page 25 cell 106: Rowid 3294 out of order Tree 14 page 14 cell 2: Rowid 219561 out of order NULL value in VersionInfo.Version NULL value in VersionInfo.Version NULL value in VersionInfo.Version NULL value in VersionInfo.Version NULL value in VersionInfo.Version NULL value in VersionInfo.Version NULL value in VersionInfo.Version NULL value in VersionInfo.Version NULL value in VersionInfo.Version NUMERIC value in SceneMappings.SearchTerm NUMERIC value in SceneMappings.ParseTerm NUMERIC value in SceneMappings.SearchTerm NUMERIC value in SceneMappings.ParseTerm NUMERIC value in SceneMappings.SearchTerm NUMERIC value in SceneMappings.ParseTerm | WARN | 2904 KB | 2904 KB | 0 KB | 0% |
| Radarr Database | FAIL: *** in database main *** Tree 45 page 209 cell 0: Rowid 2542 out of order Tree 45 page 207 cell 7: Rowid 2550 out of order Tree 45 page 206 cell 7: Rowid 2558 out of order Tree 45 page 205 cell 7: Rowid 2587 out of order Tree 45 page 204 cell 5: Rowid 2579 out of order Tree 45 page 203 cell 6: Rowid 2573 out of order Tree 45 page 202 cell 7: Rowid 2566 out of order Tree 45 page 201 cell 7: Rowid 2595 out of order Tree 45 page 200 cell 7: Rowid 2603 out of order Tree 45 page 199 cell 7: Rowid 2611 out of order Tree 45 page 198 cell 7: Rowid 2619 out of order Tree 45 page 197 cell 7: Rowid 2627 out of order Tree 45 page 196 cell 7: Rowid 2635 out of order Tree 45 page 195 cell 7: Rowid 2643 out of order Tree 45 page 194 cell 7: Rowid 2651 out of order Tree 45 page 193 cell 4: Rowid 2534 out of order Tree 45 page 149 cell 2: Rowid 2659 out of order | WARN | 1592 KB | 1592 KB | 0 KB | 0% |
| Prowlarr Database | PASS | PASS | 324 KB | 324 KB | 0 KB | 0% |
| Bazarr Database | PASS | PASS | 316 KB | 316 KB | 0 KB | 0% |
| Jellyseerr Database | PASS | PASS | 220 KB | 220 KB | 0 KB | 0% |
| Jellyfin Main DB | PASS | PASS | 54676 KB | 54676 KB | 0 KB | 0% |

---
*Report generated automatically by MediaStack Database Optimizer Engine.*
