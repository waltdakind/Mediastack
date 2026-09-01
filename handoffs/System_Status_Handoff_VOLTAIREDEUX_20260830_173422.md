# MediaStack Cross-Node System Status & Architecture Handoff

- **Authoring Node:** VOLTAIREDEUX (VoltaireDeux (AI Acceleration & Push Node))
- **Local LAN IP:** 192.168.4.30
- **Target Peer Node:** VOLTAIREUN (VoltaireUn (Main 24/7 Server Node))
- **Peer LAN IP:** 192.168.4.21
- **Generated Timestamp:** 2026-08-30 17:34:22
- **Running Fleet Containers:** 0 / 0

---

## 1. System Architecture & Topology Overview

```
  Node: VOLTAIREDEUX (192.168.4.30) <===> Peer: VOLTAIREUN (192.168.4.21)
  Role: VoltaireDeux (AI Acceleration & Push Node)  |  Peer Role: VoltaireUn (Main 24/7 Server Node)
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
| **mediastack_backup.db** | mediastack-db | Yes | 112 KB | [OK] PRISTINE | Integrity Check Passed (112 KB) |
| **sonarr.db** | sonarr | Yes | 2868 KB | [OK] PRISTINE | Integrity Check Passed (2868 KB) |
| **radarr.db** | radarr | Yes | 2636 KB | [OK] PRISTINE | Integrity Check Passed (2636 KB) |
| **prowlarr.db** | prowlarr | Yes | 336 KB | [OK] PRISTINE | Integrity Check Passed (336 KB) |
| **bazarr.db** | bazarr | Yes | 316 KB | [OK] PRISTINE | Integrity Check Passed (316 KB) |
| **db.sqlite3** | jellyseerr | Yes | 220 KB | [OK] PRISTINE | Integrity Check Passed (220 KB) |
| **jellyfin.db** | jellyfin | Yes | 46764 KB | [OK] PRISTINE | Integrity Check Passed (46764 KB) |

---

## 3. Discovered System Errors & Incident Logs

[OK] **No active system errors detected.** All containers and database health probes passed.

---

## 4. AI Suggestions for Stability, Self-Healing & Peer Node Optimization

> [!TIP]
> **Recommendations offered by VOLTAIREDEUX for VOLTAIREUN:**

1. **Database WAL Checkpoint Tuning for 24/7 Servarr Workloads:** On VoltaireUn, configure `PRAGMA wal_autocheckpoint=1000;` on `sonarr.db` and `radarr.db` to prevent massive WAL files during high-frequency indexer scans.

2. **Cross-Node Caddy Failover Optimization:** Ensure VoltaireUn's Caddy upstream timeout is set to `lb_try_duration 4s` and `fail_duration 15s` so streaming sessions gracefully fail over to VoltaireDeux if primary transcoding bottlenecks.

3. **Automated SQLite Vacuum & PRAGMA QuickCheck:** Ensure VoltaireUn runs a weekly `VACUUM;` on `jellyfin.db` and `prowlarr.db` during low-traffic windows (03:00 AM) prior to the daily sync pass.

4. **Valkey Redis Instance Separation:** Keep VoltaireUn bound to `musicbrainz-docker-valkey-1` (port 5000) while VoltaireDeux routes metadata lookups to `musicbrainz-docker-valkey-2` (port 5001) to prevent cache stampedes.

5. **Crash-Loop Sentinel on Bazarr / Radarr:** If Bazarr encounters subtitle provider rate-limits, ensure the auto-healing sentinel applies exponential backoff (15s, 60s, 300s) instead of immediate container restart.

---
*Handoff file automatically generated for cluster sync exchange.*
