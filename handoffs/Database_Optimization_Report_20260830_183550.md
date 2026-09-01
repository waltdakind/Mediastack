# MediaStack Database Health, Integrity & Optimization Report

| Parameter | Value |
| :--- | :--- |
| **Optimization Timestamp** | 2026-08-30 18:35:50 |
| **Host System** | VOLTAIREUN |
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
| MediaStack Backup DB | PASS | PASS | 120 KB | 120 KB | 0 KB | 0% |
| Sonarr Database | FAIL: *** in database main *** Tree 76 page 728: btreeInitPage() returns error code 11 Tree 76 page 727: btreeInitPage() returns error code 11 Tree 76 page 726: btreeInitPage() returns error code 11 Tree 76 page 725: btreeInitPage() returns error code 11 Tree 76 page 724: btreeInitPage() returns error code 11 Tree 76 page 723: btreeInitPage() returns error code 11 Tree 76 page 722: btreeInitPage() returns error code 11 Tree 76 page 721: btreeInitPage() returns error code 11 Tree 76 page 720: btreeInitPage() returns error code 11 Tree 76 page 719: btreeInitPage() returns error code 11 Tree 76 page 718: btreeInitPage() returns error code 11 Tree 76 page 717: btreeInitPage() returns error code 11 Tree 76 page 716: btreeInitPage() returns error code 11 Tree 76 page 715: btreeInitPage() returns error code 11 Tree 76 page 714: btreeInitPage() returns error code 11 Tree 76 page 713: btreeInitPage() returns error code 11 Tree 76 page 712: btreeInitPage() returns error code 11 Tree 76 page 711: btreeInitPage() returns error code 11 Tree 76 page 710: btreeInitPage() returns error code 11 Tree 76 page 76 cell 204: Rowid 1841 out of order Tree 76 page 76 cell 203: Rowid 1832 out of order Page 132: never used Page 248: never used Page 249: never used Page 250: never used Page 251: never used Page 252: never used Page 253: never used Page 254: never used Page 255: never used Page 256: never used Page 257: never used Page 258: never used Page 259: never used Page 260: never used Page 261: never used Page 262: never used Page 263: never used Page 264: never used Page 265: never used Page 266: never used Page 267: never used Page 268: never used Page 269: never used Page 270: never used Page 271: never used Page 272: never used Page 273: never used Page 274: never used Page 275: never used Page 276: never used Page 277: never used Page 278: never used Page 279: never used Page 280: never used Page 281: never used Page 282: never used Page 283: never used Page 284: never used Page 285: never used Page 286: never used Page 287: never used Page 288: never used Page 289: never used Page 290: never used Page 291: never used Page 292: never used Page 293: never used Page 294: never used Page 295: never used Page 296: never used Page 297: never used Page 298: never used Page 299: never used Page 300: never used Page 301: never used Page 302: never used Page 303: never used Page 304: never used Page 305: never used Page 306: never used Page 307: never used Page 308: never used Page 309: never used Page 310: never used Page 311: never used Page 312: never used Page 313: never used Page 314: never used Page 315: never used Page 316: never used Page 317: never used Page 318: never used Page 319: never used Page 320: never used Page 321: never used Page 322: never used Page 323: never used Page 324: never used Page 325: never used | WARN | 2836 KB | 2836 KB | 0 KB | 0% |
| Radarr Database | PASS | PASS | 604 KB | 604 KB | 0 KB | 0% |
| Prowlarr Database | PASS | PASS | 336 KB | 336 KB | 0 KB | 0% |
| Bazarr Database | PASS | PASS | 316 KB | 316 KB | 0 KB | 0% |
| Jellyseerr Database | PASS | PASS | 220 KB | 220 KB | 0 KB | 0% |
| Jellyfin Main DB | PASS | PASS | 36188 KB | 36188 KB | 0 KB | 0% |

---
*Report generated automatically by MediaStack Database Optimizer Engine.*
