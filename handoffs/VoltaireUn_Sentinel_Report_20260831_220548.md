# VoltaireUn 24/7 Primary Server Sentinel Report

- **Host Server:** VOLTAIREUN (VoltaireUn (Main 24/7 Server Node))
- **Local LAN IP:** 192.168.4.21
- **Peer AI Workstation:** VOLTAIREDEUX (fe80::a96e:fd36:62a8:42ba%25)
- **Execution Timestamp:** 2026-08-31 22:05:48
- **Overall Health Status:** âš ï¸ Auto-Healed Anomalies

---

## Summary of Sentinel Actions:
- **Storage & Volumes:** Headroom verified; media folders validated; conflict locks quarantined.
- **Databases (7 core DBs):** WAL autocheckpoints flushed; PRAGMA integrity verified; index optimizations applied.
- **Published Ports & Routes:** All 9 core service ports and Caddy ingress reverse-proxy routes verified.
- **Triple-Channel Updates:** Scanned OneDrive manifests, LAN peer status, and GitHub remote.

### Auto-Remediations Applied:
- Hot-restored sonarr.db from C:\Users\waltd\OneDrive\Mediastack\config\db-backup\snapshots\pre_sync_batch_20260831_175306\sonarr_VOLTAIREUN_DAILY_PRE_SYNC_20260831_175306.db-wal.
- Hot-restored radarr.db from C:\Users\waltd\OneDrive\Mediastack\config\db-backup\snapshots\radarr_PRE_PUSH_VOLTAIREDEUX_20260830_183259.db.
- Hot-restored prowlarr.db from C:\Users\waltd\OneDrive\Mediastack\config\db-backup\snapshots\pre_sync_batch_20260830_214910\prowlarr_PRE_PUSH_VOLTAIREDEUX_20260830_214910.db.
- Hot-restored bazarr.db from C:\Users\waltd\OneDrive\Mediastack\config\db-backup\snapshots\bazarr_PRE_PUSH_VOLTAIREDEUX_20260831_170235.db.

### Active Incident Findings:
- Critically low disk space on Drive C (75.6 GB remaining / 7.9% free).
- Database integrity anomaly on sonarr.db: Integrity Anomaly: Error: in prepare, database disk image is malformed (11)
- Database integrity anomaly on radarr.db: Integrity Anomaly: Error response from daemon: Container 6cc37c0349320c0a212b5230b22873ccab290d9c47dd4e1ba40e446b49a72d72 is restarting, wait until the container is running
- Database integrity anomaly on prowlarr.db: Integrity Anomaly: Error response from daemon: Container 6cc37c0349320c0a212b5230b22873ccab290d9c47dd4e1ba40e446b49a72d72 is restarting, wait until the container is running
- Database integrity anomaly on bazarr.db: Integrity Anomaly: Error: in prepare, database disk image is malformed (11)

---
*VoltaireUn 24/7 Sentinel Suite.*
