# MediaStack Cross-Node System Status & Architecture Handoff

- **Authoring Node:** ORDINATEURDEVOL (VoltaireUn (Main 24/7 Server Node))
- **Local LAN IP:** 192.168.4.21
- **Target Peer Node:** VOLTAIREDEUX (VoltaireDeux (AI Acceleration & Push Node))
- **Peer LAN IP:** fe80::a96e:fd36:62a8:42ba%25
- **Generated Timestamp:** 2026-08-30 18:38:13
- **Running Fleet Containers:** 20 / 21

---

## 1. System Architecture & Topology Overview

```
  Node: ORDINATEURDEVOL (192.168.4.21) <===> Peer: VOLTAIREDEUX (fe80::a96e:fd36:62a8:42ba%25)
  Role: VoltaireUn (Main 24/7 Server Node)  |  Peer Role: VoltaireDeux (AI Acceleration & Push Node)
  Ingress: Caddy Reverse Proxy (Ports 80 / 443)  |  Failover Ingress: Port 80
  Databases: SQLite WAL Mode (7 core DBs)  |  Synchronized Mirror + Snapshots
```

### Code & Configuration Layout:
- **Ingress Proxy:** Primary `Caddyfile` with dynamic `Host` header routing (`*.voltaireun.local` and `*.voltairedeux.local`).
- **Orchestration:** `docker-compose.yml` with host volume mounts and bridge network `mediastack`.
- **Database Sentinel:** Lock-free integrity checks via `MediaStackOps.psm1` (`PRAGMA quick_check;`).
- **Cluster Push-Pull:** Git commits pushed from VoltaireDeux and ingested once per day via VoltaireUn daily poller.

---

## 2. Active Database Inventory & Health Audit

| Database Name | Service | Exists | Size (KB) | Health Status | Diagnostics |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **mediastack_backup.db** | mediastack-db | Yes | 124 KB | [OK] PRISTINE | Integrity Check Passed (124 KB) |
| **sonarr.db** | sonarr | Yes | 2836 KB | [WARN] CORRUPT | Integrity Anomaly: *** in database main *** Tree 76 page 728: btreeInitPage() returns error code 11 Tree 76 page 727: btreeInitPage() returns error code 11 Tree 76 page 726: btreeInitPage() returns error code 11 Tree 76 page 725: btreeInitPage() returns error code 11 Tree 76 page 724: btreeInitPage() returns error code 11 Tree 76 page 723: btreeInitPage() returns error code 11 Tree 76 page 722: btreeInitPage() returns error code 11 Tree 76 page 721: btreeInitPage() returns error code 11 Tree 76 page 720: btreeInitPage() returns error code 11 Tree 76 page 719: btreeInitPage() returns error code 11 Tree 76 page 718: btreeInitPage() returns error code 11 Tree 76 page 717: btreeInitPage() returns error code 11 Tree 76 page 716: btreeInitPage() returns error code 11 Tree 76 page 715: btreeInitPage() returns error code 11 Tree 76 page 714: btreeInitPage() returns error code 11 Tree 76 page 713: btreeInitPage() returns error code 11 Tree 76 page 712: btreeInitPage() returns error code 11 Tree 76 page 711: btreeInitPage() returns error code 11 Tree 76 page 710: btreeInitPage() returns error code 11 Tree 76 page 76 cell 204: Rowid 1841 out of order Tree 76 page 76 cell 203: Rowid 1832 out of order Page 132: never used Page 248: never used Page 249: never used Page 250: never used Page 251: never used Page 252: never used Page 253: never used Page 254: never used Page 255: never used Page 256: never used Page 257: never used Page 258: never used Page 259: never used Page 260: never used Page 261: never used Page 262: never used Page 263: never used Page 264: never used Page 265: never used Page 266: never used Page 267: never used Page 268: never used Page 269: never used Page 270: never used Page 271: never used Page 272: never used Page 273: never used Page 274: never used Page 275: never used Page 276: never used Page 277: never used Page 278: never used Page 279: never used Page 280: never used Page 281: never used Page 282: never used Page 283: never used Page 284: never used Page 285: never used Page 286: never used Page 287: never used Page 288: never used Page 289: never used Page 290: never used Page 291: never used Page 292: never used Page 293: never used Page 294: never used Page 295: never used Page 296: never used Page 297: never used Page 298: never used Page 299: never used Page 300: never used Page 301: never used Page 302: never used Page 303: never used Page 304: never used Page 305: never used Page 306: never used Page 307: never used Page 308: never used Page 309: never used Page 310: never used Page 311: never used Page 312: never used Page 313: never used Page 314: never used Page 315: never used Page 316: never used Page 317: never used Page 318: never used Page 319: never used Page 320: never used Page 321: never used Page 322: never used Page 323: never used Page 324: never used Page 325: never used |
| **radarr.db** | radarr | Yes | 612 KB | [OK] PRISTINE | Integrity Check Passed (612 KB) |
| **prowlarr.db** | prowlarr | Yes | 336 KB | [OK] PRISTINE | Integrity Check Passed (336 KB) |
| **bazarr.db** | bazarr | Yes | 316 KB | [OK] PRISTINE | Integrity Check Passed (316 KB) |
| **db.sqlite3** | jellyseerr | Yes | 220 KB | [OK] PRISTINE | Integrity Check Passed (220 KB) |
| **jellyfin.db** | jellyfin | Yes | 36188 KB | [OK] PRISTINE | Integrity Check Passed (36188 KB) |

---

## 3. Discovered System Errors & Incident Logs

[WARN] **Offline / Stopped Containers:** musicbrainz-docker-valkey-2

---

## 4. AI Suggestions for Stability, Self-Healing & Peer Node Optimization

> [!TIP]
> **Recommendations offered by ORDINATEURDEVOL for VOLTAIREDEUX:**

1. **AI Acceleration Batch Ingestion:** For VoltaireDeux AI workloads, offload music embedding generation and tagging to Picard via local mirror (`127.0.0.1:5001`) to preserve VoltaireUn WAN bandwidth.

2. **OneDrive Sync Conflict Prevention:** Exclude active SQLite `-wal` and `-shm` temporary lock files from OneDrive sync on VoltaireDeux to eliminate `.db-shm` file locks.

3. **Cross-Node Database Hot-Restore Readiness:** Keep at least 5 verified point-in-time snapshots in `db-backup/snapshots/` to enable sub-second recovery if AI tests write dirty records.

4. **Port Binding Isolation:** Ensure AI model endpoints (e.g. Ollama `:11434` / FastAPI `:8000`) do not collide with Caddy reverse proxy port `80` or API Gateway `:3000`.

---
*Handoff file automatically generated for cluster sync exchange.*
