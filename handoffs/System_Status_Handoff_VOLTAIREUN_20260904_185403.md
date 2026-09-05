# MediaStack Cross-Node System Status & Architecture Handoff

- **Authoring Node:** VOLTAIREUN (VoltaireUn (Main 24/7 Server Node))
- **Local LAN IP:** 192.168.4.21
- **Target Peer Node:** VOLTAIREDEUX (VoltaireDeux (AI Acceleration & Push Node))
- **Peer LAN IP:** 192.168.4.30
- **Generated Timestamp:** 2026-09-04 18:54:03
- **Running Fleet Containers:** 18 / 18

---

## 1. System Architecture & Topology Overview

```
  Node: VOLTAIREUN (192.168.4.21) <===> Peer: VOLTAIREDEUX (192.168.4.30)
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
| **mediastack_backup.db** | mediastack-db | Yes | 184 KB | [OK] PRISTINE | Integrity Check Passed (184 KB) |
| **sonarr.db** | sonarr | Yes | 3656 KB | [OK] PRISTINE | Integrity Check Passed (3656 KB) |
| **radarr.db** | radarr | Yes | 1376 KB | [OK] PRISTINE | Integrity Check Passed (1376 KB) |
| **prowlarr.db** | prowlarr | Yes | 332 KB | [OK] PRISTINE | Integrity Check Passed (332 KB) |
| **bazarr.db** | bazarr | Yes | 316 KB | [OK] PRISTINE | Integrity Check Passed (316 KB) |
| **db.sqlite3** | jellyseerr | Yes | 220 KB | [OK] PRISTINE | Integrity Check Passed (220 KB) |
| **jellyfin.db** | jellyfin | Yes | 54784 KB | [OK] PRISTINE | Integrity Check Passed (54784 KB) |

---

## 3. Discovered System Errors & Incident Logs

```
2026-09-01 07:12:12|Transmission Web UI|PORT_REPAIR_FAILED|Flushed DNS Resolver Cache
```

---

## 4. AI Suggestions for Stability, Self-Healing & Peer Node Optimization

> [!TIP]
> **Recommendations offered by VOLTAIREUN for VOLTAIREDEUX:**

1. **AI Acceleration Batch Ingestion:** For VoltaireDeux AI workloads, offload music embedding generation and tagging to Picard via local mirror (`127.0.0.1:5001`) to preserve VoltaireUn WAN bandwidth.

2. **OneDrive Sync Conflict Prevention:** Exclude active SQLite `-wal` and `-shm` temporary lock files from OneDrive sync on VoltaireDeux to eliminate `.db-shm` file locks.

3. **Cross-Node Database Hot-Restore Readiness:** Keep at least 5 verified point-in-time snapshots in `db-backup/snapshots/` to enable sub-second recovery if AI tests write dirty records.

4. **Port Binding Isolation:** Ensure AI model endpoints (e.g. Ollama `:11434` / FastAPI `:8000`) do not collide with Caddy reverse proxy port `80` or API Gateway `:3000`.

---
*Handoff file automatically generated for cluster sync exchange.*
