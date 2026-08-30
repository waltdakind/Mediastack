# MediaStack Database Health, Integrity & Optimization Report

| Parameter | Value |
| :--- | :--- |
| **Optimization Timestamp** | 2026-08-28 23:28:54 |
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
| Sonarr Database | FAIL: *** in database main *** Tree 25 page 591: btreeInitPage() returns error code 11 Tree 25 page 590 cell 49: Rowid 386662 out of order Tree 25 page 589: btreeInitPage() returns error code 11 Tree 25 page 588 cell 8: Rowid 7690 out of order Tree 25 page 587 cell 8: Rowid 7681 out of order Tree 25 page 586 cell 8: Rowid 7699 out of order Tree 25 page 585 cell 8: Rowid 7672 out of order Tree 25 page 584 cell 8: Rowid 7663 out of order Tree 25 page 583: btreeInitPage() returns error code 11 Tree 14 page 14 cell 120: 2nd reference to page 590 Page 495: never used Error: stepping, database disk image is malformed (11) Page 516: never used | PASS | 2204 KB | 2204 KB | 0 KB | 0% |
| Radarr Database | FAIL: *** in database main *** Tree 33 page 149 cell 4: Rowid 2959 out of order Tree 33 page 148 cell 5: Rowid 2954 out of order Tree 45 page 232 cell 7: Rowid 5189 out of order Tree 45 page 230 cell 7: Rowid 5165 out of order Tree 45 page 229 cell 7: Rowid 5149 out of order Tree 45 page 228 cell 7: Rowid 5141 out of order Tree 45 page 227 cell 7: Rowid 5133 out of order Tree 45 page 226 cell 5: Rowid 5125 out of order Tree 45 page 225 cell 6: Rowid 5119 out of order Tree 45 page 45 cell 183: Rowid 4398 out of order Tree 45 page 223 cell 7: Rowid 5096 out of order Tree 45 page 222 cell 7: Rowid 5104 out of order Tree 45 page 221 cell 7: Rowid 5080 out of order Tree 45 page 220 cell 7: Rowid 5072 out of order Tree 45 page 219 cell 7: Rowid 5064 out of order Tree 45 page 216 cell 7: Rowid 5032 out of order Tree 45 page 218 cell 7: Rowid 5056 out of order Tree 45 page 217 cell 7: Rowid 5088 out of order Tree 45 page 215 cell 7: Rowid 5040 out of order Tree 45 page 214 cell 7: Rowid 5048 out of order Tree 45 page 213 cell 7: Rowid 5173 out of order Tree 45 page 45 cell 171: Rowid 4303 out of order Tree 45 page 45 cell 170: Rowid 4297 out of order Tree 45 page 45 cell 169: Rowid 4290 out of order Tree 45 page 45 cell 168: Rowid 4282 out of order Tree 45 page 45 cell 167: Rowid 4274 out of order Tree 45 page 45 cell 166: Rowid 4266 out of order Tree 45 page 45 cell 165: Rowid 4260 out of order Tree 45 page 45 cell 164: Rowid 4253 out of order Tree 45 page 45 cell 163: Rowid 4245 out of order Tree 45 page 45 cell 162: Rowid 4237 out of order Tree 45 page 381 cell 7: Rowid 4502 out of order Tree 45 page 45 cell 160: Rowid 4219 out of order Tree 45 page 45 cell 159: Rowid 4211 out of order Tree 45 page 45 cell 158: Rowid 4203 out of order Tree 45 page 45 cell 157: Rowid 4197 out of order Tree 45 page 45 cell 156: Rowid 4190 out of order Tree 45 page 45 cell 155: Rowid 4182 out of order Tree 45 page 45 cell 154: Rowid 4174 out of order Tree 45 page 45 cell 153: Rowid 4166 out of order Tree 45 page 45 cell 152: Rowid 4158 out of order Tree 45 page 45 cell 151: Rowid 4150 out of order Tree 45 page 45 cell 150: Rowid 4142 out of order Tree 45 page 45 cell 149: Rowid 4134 out of order Tree 45 page 190: btreeInitPage() returns error code 11 Tree 45 page 45 cell 147: Rowid 4118 out of order Tree 45 page 191: btreeInitPage() returns error code 11 Tree 45 page 45 cell 145: Rowid 4102 out of order Tree 45 page 45 cell 144: Rowid 4094 out of order Tree 45 page 45 cell 144: 2nd reference to page 187 Tree 45 page 45 cell 143: 2nd reference to page 182 Tree 45 page 45 cell 142: 2nd reference to page 186 Tree 45 page 45 cell 141: 2nd reference to page 185 Tree 45 page 45 cell 140: 2nd reference to page 184 Tree 45 page 45 cell 139: 2nd reference to page 183 Tree 45 page 45 cell 138: 2nd reference to page 176 Tree 45 page 45 cell 137: 2nd reference to page 181 Tree 45 page 45 cell 136: 2nd reference to page 180 Tree 45 page 45 cell 135: 2nd reference to page 179 Tree 45 page 45 cell 134: 2nd reference to page 178 Tree 45 page 45 cell 133: 2nd reference to page 177 Tree 45 page 45 cell 132: 2nd reference to page 174 Tree 45 page 45 cell 131: 2nd reference to page 175 Tree 45 page 45 cell 130: 2nd reference to page 173 Tree 45 page 45 cell 129: 2nd reference to page 170 Tree 45 page 45 cell 128: 2nd reference to page 172 Tree 45 page 45 cell 127: 2nd reference to page 171 Tree 45 page 45 cell 126: 2nd reference to page 168 Tree 45 page 45 cell 125: 2nd reference to page 169 Tree 45 page 45 cell 124: 2nd reference to page 167 Tree 45 page 45 cell 123: 2nd reference to page 166 Tree 45 page 45 cell 122: 2nd reference to page 163 Tree 45 page 45 cell 121: 2nd reference to page 165 Tree 45 page 45 cell 120: 2nd reference to page 164 Tree 45 page 45 cell 119: 2nd reference to page 161 Tree 45 page 45 cell 118: 2nd reference to page 162 Tree 45 page 45 cell 117: 2nd reference to page 160 Tree 45 page 352 cell 7: Rowid 4270 out of order Tree 45 page 45 cell 115: 2nd reference to page 159 Tree 45 page 45 cell 114: 2nd reference to page 157 Tree 45 page 45 cell 113: 2nd reference to page 156 Tree 45 page 45 cell 112: 2nd reference to page 155 Tree 45 page 351 cell 7: Rowid 4262 out of order Tree 45 page 45 cell 110: 2nd reference to page 154 Tree 45 page 45 cell 109: 2nd reference to page 153 Tree 45 page 350 cell 7: Rowid 4254 out of order Tree 45 page 45 cell 107: 2nd reference to page 152 Tree 45 page 45 cell 106: 2nd reference to page 151 Tree 45 page 45 cell 105: 2nd reference to page 150 Tree 45 page 349 cell 7: Rowid 4246 out of order Tree 45 page 342 cell 7: Rowid 4188 out of order Tree 45 page 341 cell 7: Rowid 4180 out of order Tree 45 page 340 cell 7: Rowid 4172 out of order Tree 45 page 339 cell 7: Rowid 4164 out of order Tree 45 page 338 cell 7: Rowid 4156 out of order Tree 45 page 337 cell 7: Rowid 4148 out of order Tree 45 page 336 cell 7: Rowid 4140 out of order Tree 45 page 335 cell 7: Rowid 4132 out of order Tree 45 page 334 cell 7: Rowid 4124 out of order Tree 45 page 333 cell 7: Rowid 4116 out of order | PASS | 872 KB | 872 KB | 0 KB | 0% |
| Prowlarr Database | PASS | PASS | 252 KB | 252 KB | 0 KB | 0% |
| Bazarr Database | PASS | PASS | 316 KB | 316 KB | 0 KB | 0% |
| Jellyseerr Database | PASS | PASS | 4 KB | 4 KB | 0 KB | 0% |
| Jellyfin Main DB | PASS | PASS | 456 KB | 456 KB | 0 KB | 0% |

---
*Report generated automatically by MediaStack Database Optimizer Engine.*
