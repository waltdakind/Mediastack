# MediaStack Cross-Node System Status & Architecture Handoff

- **Authoring Node:** VOLTAIREUN (VoltaireUn (Main 24/7 Server Node))
- **Local LAN IP:** 192.168.4.21
- **Target Peer Node:** VOLTAIREDEUX (VoltaireDeux (AI Acceleration & Push Node))
- **Peer LAN IP:** fe80::a96e:fd36:62a8:42ba%25
- **Generated Timestamp:** 2026-08-31 22:15:24
- **Running Fleet Containers:** 16 / 21

---

## 1. System Architecture & Topology Overview

```
  Node: VOLTAIREUN (192.168.4.21) <===> Peer: VOLTAIREDEUX (fe80::a96e:fd36:62a8:42ba%25)
  Role: VoltaireUn (Main 24/7 Server Node)  |  Peer Role: VoltaireDeux (AI Acceleration & Push Node)
  Ingress: Caddy Reverse Proxy (Ports 80 / 443)  |  Failover Ingress: Port 80
  Databases: SQLite WAL Mode (7 core DBs)  |  Synchronized Mirror + Snapshots
```

### Code & Configuration Layout:
- **Ingress Proxy:** Master `Caddyfile` with dynamic `Host` header routing (`*.voltaireun.local` and `*.voltairedeux.local`).
- **Orchestration:** `docker-compose.yml` with host volume mounts and bridge network `mediastack`.
- **Database Sentinel:** Lock-free integrity checks via `MediaStackOps.psm1` (`PRAGMA quick_check;`).
- **Cluster Push-Pull:** Git commits pushed from VoltaireDeux and ingested once per day via VoltaireUn daily poller.

---

## 2. Active Database Inventory & Health Audit

| Database Name | Service | Exists | Size (KB) | Health Status | Diagnostics |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **mediastack_backup.db** | mediastack-db | Yes | 132 KB | [WARN] CORRUPT | Integrity Anomaly: Error response from daemon: Container 6cc37c0349320c0a212b5230b22873ccab290d9c47dd4e1ba40e446b49a72d72 is restarting, wait until the container is running |
| **sonarr.db** | sonarr | Yes | 2904 KB | [WARN] CORRUPT | Integrity Anomaly: Error response from daemon: Container 6cc37c0349320c0a212b5230b22873ccab290d9c47dd4e1ba40e446b49a72d72 is restarting, wait until the container is running |
| **radarr.db** | radarr | Yes | 1064 KB | [WARN] CORRUPT | Integrity Anomaly: Error response from daemon: Container 6cc37c0349320c0a212b5230b22873ccab290d9c47dd4e1ba40e446b49a72d72 is restarting, wait until the container is running |
| **prowlarr.db** | prowlarr | Yes | 336 KB | [WARN] CORRUPT | Integrity Anomaly: Error response from daemon: Container 6cc37c0349320c0a212b5230b22873ccab290d9c47dd4e1ba40e446b49a72d72 is restarting, wait until the container is running |
| **bazarr.db** | bazarr | Yes | 316 KB | [WARN] CORRUPT | Integrity Anomaly: Error response from daemon: Container 6cc37c0349320c0a212b5230b22873ccab290d9c47dd4e1ba40e446b49a72d72 is restarting, wait until the container is running |
| **db.sqlite3** | jellyseerr | Yes | 220 KB | [WARN] CORRUPT | Integrity Anomaly: Error response from daemon: Container 6cc37c0349320c0a212b5230b22873ccab290d9c47dd4e1ba40e446b49a72d72 is restarting, wait until the container is running |
| **jellyfin.db** | jellyfin | Yes | 60996 KB | [WARN] CORRUPT | Integrity Anomaly: Error response from daemon: Container 6cc37c0349320c0a212b5230b22873ccab290d9c47dd4e1ba40e446b49a72d72 is restarting, wait until the container is running |

---

## 3. Discovered System Errors & Incident Logs

[WARN] **Offline / Stopped Containers:** musicbrainz-docker-valkey-2, mediastack-db, kind_hawking, competent_mcnulty, caddy

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
