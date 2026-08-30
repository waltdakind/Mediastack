# MediaStack Database Health, Integrity & Optimization Report

| Parameter | Value |
| :--- | :--- |
| **Optimization Timestamp** | 2026-08-28 21:41:04 |
| **Host System** | VOLTAIREDEUX |
| **Databases Inspected** | 7 |
| **Total Space Reclaimed** | 0 KB (0%) |

---

## Database Integrity & Compression Telemetry
| Database Name | Integrity | FK Check | Initial Size | Optimized Size | Reclaimed | Reduction |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| MediaStack Backup DB | PASS | PASS | 56 KB | 56 KB | 0 KB | 0% |
| Sonarr Database | PASS | PASS | 2156 KB | 2156 KB | 0 KB | 0% |
| Radarr Database | FAIL: Error: in prepare, unable to open database file (14) | FAIL | 768 KB | 768 KB | 0 KB | 0% |
| Prowlarr Database | PASS | PASS | 244 KB | 244 KB | 0 KB | 0% |
| Bazarr Database | FAIL: Error: in prepare, unable to open database file (14) | FAIL | 316 KB | 316 KB | 0 KB | 0% |
| Jellyseerr Database | PASS | PASS | 4 KB | 4 KB | 0 KB | 0% |
| Jellyfin Main DB | PASS | PASS | 456 KB | 456 KB | 0 KB | 0% |

---
*Report generated automatically by MediaStack Database Optimizer Engine.*
