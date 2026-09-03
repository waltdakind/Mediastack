# MediaStack AI Expert Advice & Stack Optimization Briefing

- **Authoring Node:** VOLTAIREDEUX (VoltaireDeux (AI Acceleration & Push Node))
- **Authoring IP:** 192.168.4.30
- **Target Recipient:** VOLTAIREUN (VoltaireUn (Main 24/7 Server Node))
- **Target LAN IP:** fe80::2c3c:b2c6:ab71:6c09%6
- **Generated Timestamp:** 2026-09-03 01:16:54
- **Optimization Release Tag:** VOLTAIREDEUX_OPT_20260903_011654

---

## Architectural Role Guidance
```
  [VoltaireDeux - AI Workstation (192.168.4.30)]  ===> PUSHES ADVICE & CODE ===>  [VoltaireUn - 24/7 Server (192.168.4.21)]
  Capabilities: AI Acceleration, Code Synthesis, Picard Mirror   Capabilities: 24/7 Media Streaming, Ingress, Servarr Hub
```

---

## Synthesized Optimization Recommendations

### 1. Storage & Headroom Optimization
- **Temporary Cache Pruning:** Enforce automated cleanup of expired Docker build layers and old snapshot bundles older than 7 days in `db-backup/snapshots/` to maintain >15% free headroom on the primary server volume.
- **Log File Retention Policy:** Truncate active container log files at 100MB (`max-size: 100m`, `max-file: 3`) to prevent disk quota exhaustion during intensive automated scans.

### 2. SQLite Database WAL & Concurrency Architecture
- **Lock-Free Concurrency Mode:** Ensure all 7 SQLite databases operate under `PRAGMA journal_mode=WAL;` and `PRAGMA synchronous=NORMAL;`.
- **High-Frequency Scan Checkpointing:** Configure `PRAGMA wal_autocheckpoint=1000;` and `PRAGMA busy_timeout=5000;` on `sonarr.db` and `radarr.db` so high-frequency indexer lookups never block streaming metadata reads.
- **Weekly Vacuum Window:** Run `VACUUM;` and `PRAGMA optimize;` during the low-traffic window (03:30 AM) prior to the daily sync cycle.

### 3. Caddy Reverse Proxy & Active/Passive Failover
- **Upstream Failover Tuning:** Configure primary `Caddyfile` with `lb_try_duration 4s` and `fail_duration 15s` on streaming routes, enabling seamless failover to VoltaireDeux if primary server transcoding bottlenecks.
- **Internal Subdomain Resolution:** Ensure `*.voltaireun.local` and `*.voltairedeux.local` domain host headers are dynamically forwarded with preserved client IPs.

### 4. Workload Partitioning & AI Amplification
- **Picard Batch Tagging Mirror:** Route intensive music tagging and AcoustID audio fingerprinting to VoltaireDeux (`127.0.0.1:5001`), preserving VoltaireUn WAN bandwidth and CPU resources for real-time video playback.
- **AI LLM Subtitle Extraction:** Expose VoltaireDeux GPU-accelerated Ollama endpoint (`http://192.168.4.30:11434`) for on-demand subtitle translation and metadata enrichment requested by VoltaireUn.

### 5. Resilient Auto-Healing & Sentinel Backoff
- **Crash-Loop Exponential Backoff:** If Radarr or Bazarr encounter external rate limits, apply backoff intervals (15s, 60s, 300s) instead of immediate container restarts to avoid IP bans.
- **Atomic Pre-Sync Safety Rule:** Maintain the requirement that every database pull or update must be preceded by a verified SHA-256 SQLite snapshot.

---

## Action Plan to be Executed on VoltaireUn:
- [x] Purge snapshot archives older than 7 days in db-backup/snapshots/
- [x] Apply PRAGMA wal_autocheckpoint=1000 and PRAGMA busy_timeout=5000 across core DBs
- [x] Synchronize primary Caddyfile with dynamic host routing and HA failover
- [x] Route AI model offloading and Picard batch jobs to VoltaireDeux (192.168.4.30)
- [x] Enforce atomic pre-sync database snapshotting before every code or config merge

---
*Delivered by MediaStack AI Optimization Engine.*
