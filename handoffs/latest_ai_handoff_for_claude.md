# MediaStack VoltaireUn Deep Systems Analysis & Claude AI Handoff
**Document Version:** 2.0-ENTERPRISE  
**Target AI Agent:** Claude (Anthropic) & Cluster AI Collaborators  
**Primary Subject:** `VoltaireUn` (formerly `VOLTAIREUN` / `voltaireun.local`)  
**Analyst Node:** `VoltaireDeux` (AI Acceleration & Push Node)  
**Cluster Architecture:** Dual-Node High-Availability Media, Automation & AI Mesh  
**Analysis Timestamp:** 2026-08-30 20:45:00 EDT  

---

## 1. Executive Summary & Cluster Topology

The MediaStack ecosystem operates as a **coordinated dual-node cluster** designed for continuous 24/7 uptime, automated media ingestion, hardware-accelerated streaming, and distributed AI acceleration.

```
       +=============================================================+
       |                  LAN GATEWAY (192.168.4.1)                  |
       +=============================================================+
                                      |
         +----------------------------+----------------------------+
         |                                                         |
+---------------------------------+       +---------------------------------+
|   VOLTAIREUN (24/7 MAIN NODE)   |       | VOLTAIREDEUX (AI / WORKSTATION) |
|   IP: 192.168.4.21              |  LAN  | IP: 192.168.4.30                |
|   Hostname: voltaireun.local    |<=====>| Hostname: voltairedeux.local    |
|   Role: 24/7 Media & Ingress    | HTTPS | Role: AI Acceleration & Push    |
|   Storage: /data/media (ZFS/NTFS| ONEDRIVE| Storage: Fast NVMe Scratch    |
+---------------------------------+       +---------------------------------+
         |                                                         |
         * Caddy Gateway (:80/:443)                                * Ollama LLM (:11434)
         * Jellyfin Streaming (:8096)                              * MusicBrainz Picard (:5001)
         * Servarr Suite (8989/7878/9696/6767/5055)                * Git Push & Staging Hub
         * MusicBrainz Primary (:5000)                             * AI Collaboration Watcher
         * SQLite Primary DBs (WAL Mode)                            * Development & AST Tester
```

### Node Identity Mapping:
1. **VoltaireUn (Main 24/7 Server)**:
   * **Hostnames**: `voltaireun.local`, `voltaireun.local`, `mediaserver.local`, `192.168.4.21`
   * **Primary Responsibilities**: 24/7 Jellyfin media streaming, Servarr automation (`Sonarr`, `Radarr`, `Prowlarr`, `Bazarr`, `Jellyseerr`), Transmission torrents, TVHeadend live TV, MusicBrainz mirror (`:5000`), and Primary Caddy edge gateway (`:80`/`:443`).
   * **Ingestion Schedule**: Automatically polls for cluster updates daily at 04:00 AM via Windows Scheduled Task (`Invoke-VoltaireUnDailyPoller.ps1`).

2. **VoltaireDeux (AI Workstation & Push Node)**:
   * **Hostnames**: `voltairedeux.local`, `192.168.4.30`
   * **Primary Responsibilities**: Heavy AI model execution (`Ollama` :11434 for semantic search and tagging), batch MusicBrainz Picard tagger, code linting/AST validation, AI expert advice synthesis, and Git/OneDrive staging source.

---

## 2. Deep Diagnostic Root Cause Analysis (RCA) on VoltaireUn Logs

A forensic audit of all historical telemetry and recent incident reports (`VoltaireUn_Sentinel_Report_*.md`, `Incident_RCA_*.md`, `System_Status_Handoff_*.md`) identified three critical failure modes and their resolutions:

---

### Incident 1: Mass Container SIGKILL (Exit Code 137)
* **Observed Symptom**: 12+ Docker containers (`jellyfin`, `sonarr`, `radarr`, `bazarr`, `mediastack-db`, `caddy`, etc.) exited simultaneously with code `137` (SIGKILL).
* **Forensic Root Cause**:
  * VoltaireUn's system Drive `C:` reached critically low storage: **41.9 GB remaining (4.4% free space)**.
  * Docker Desktop on Windows with WSL2/Hyper-V enforces safety throttling when host disk space falls below 5%. When combined with Docker container json logs ballooning without rotation limits, the WSL2 kernel balloon driver initiated out-of-memory / out-of-space SIGKILL termination.
* **Remediation & Best Practices Implemented**:
  1. **Proactive Disk Pruning in Sentinel**: `Invoke-VoltaireUn24hrSentinel.ps1` checks storage headroom on every pass. If free space drops below 10%, it automatically executes `docker system prune -f --volumes=false`, removes old database snapshots older than 5 days, and purges temp locks.
  2. **Docker Log Caps**: Enforced Docker container log constraints (`max-size: "50m"`, `max-file: "3"`).

---

### Incident 2: SQLite B-Tree Inconsistency on `sonarr.db`
* **Observed Symptom**: VoltaireUn logged SQLite integrity errors on `sonarr.db`:
  `*** in database main *** Tree 76 page 728: btreeInitPage() returns error code 11 ... Rowid 1841 out of order ...`
* **Forensic Root Cause**:
  * Abrupt container termination (Exit 137) occurred while Sonarr was performing disk writes to its WAL journal (`sonarr.db-wal`).
  * Concurrently, OneDrive sync client attempted to replicate locked `-wal` and `-shm` files, causing cross-process file lock contention and corrupting the index B-tree.
* **Remediation & Best Practices Implemented**:
  1. **WAL Concurrency Tuning**: Configured `PRAGMA synchronous=NORMAL;`, `PRAGMA wal_autocheckpoint=1000;`, and `PRAGMA busy_timeout=5000;` on all 7 core databases.
  2. **Automated Hot-Restore**: `MediaStackOps.psm1` / `Invoke-DatabaseHotRestore` detects `PRAGMA quick_check` anomalies and immediately recovers data using SQLite recovery or restores from pre-sync snapshots in `db-backup/snapshots/`.
  3. **OneDrive Isolation**: Excluded all live SQLite `.db-wal` and `.db-shm` temporary files from OneDrive synchronization.

---

### Incident 3: Transition to Enterprise SSL/TLS & HTTPS (:443)
* **Observed Symptom**: Mixed HTTP/HTTPS traffic caused insecure browser warnings, CORS blocks on API Gateway, and plain-text transmission across the LAN.
* **Remediation & Best Practices Implemented**:
  1. **4096-bit Multi-Domain Certificate**: Generated with SANs covering DDNS (`waltdakind.xubi.org`), LAN (`*.voltaireun.local`, `*.voltairedeux.local`, `*.voltaireun.local`), and direct IPs.
  2. **Primary Caddyfile Hardening**: Configured reverse proxy blocks on `:443` with HSTS, strict security headers, and seamless HTTP ➔ HTTPS automatic redirection.
  3. **Jellyfin Authentication**: Linked newly created Jellyfin API key (`aa8e...a219`) into automated REST validation suites.

---

## 3. Current Live Verification State Matrix

| Component | Target Port | Status | Protocol / Auth | Latency | Verification Details |
| :--- | :---: | :---: | :---: | :---: | :--- |
| **Caddy Ingress HTTP** | 80 | **ONLINE** | HTTP 200/302 | 16ms | Reverse proxy root & auto-redirects |
| **Caddy Ingress HTTPS** | 443 | **ONLINE** | TLS 1.3 / Custom CA | 0ms | Full TLS encryption & HSTS |
| **Jellyfin Streaming** | 8096 / 443 | **ONLINE** | HTTP / HTTPS (Token) | 12ms / 55ms | Version 10.11.11, Token `aa8e...a219` |
| **Sonarr TV** | 8989 / 443 | **ONLINE** | REST API v3 / HTTPS | 149ms | Version 4.0.19.2979, Key `38c6...0bac` |
| **Radarr Movies** | 7878 / 443 | **ONLINE** | REST API v3 / HTTPS | 67ms | Version 6.3.0.10514, Key `a5e0...f95e` |
| **Prowlarr Indexer** | 9696 / 443 | **ONLINE** | REST API v1 / HTTPS | 155ms | Version 2.5.2.5491, Key `f07e...2596` |
| **Bazarr Subtitles** | 6767 / 443 | **ONLINE** | REST API / HTTPS | 114ms | Key `5f1e...1cfd` |
| **Jellyseerr Requests** | 5055 / 443 | **ONLINE** | REST API v1 / HTTPS | 2672ms | Version 3.4.1, Key `MTc4...NA==` |
| **MusicBrainz Primary** | 5000 | **ONLINE** | WebService v2 JSON | 463ms | Replicated search mirror on VoltaireUn |
| **Database Web GUI** | 8080 / 443 | **ONLINE** | SQLite-Web UI | 54ms | Direct CRUD verified 100% |
| **AcoustID API** | WAN HTTPS | **ONLINE** | REST API v2 | 1683ms | Key `4wzg...6hwM`, status: ok |
| **API Gateway** | 3000 / 443 | **ONLINE** | Node.js Express REST | 164ms | HTTP 200 OK |

---

## 4. Operational Runbook & Tooling Inventory for Claude

When interacting with this codebase in future sessions, Claude should utilize the following pre-built, tested scripts:

### A. Health Diagnostics & Verification
```powershell
# 1. Full Proxy & Port Diagnostic with Auto-Repair
powershell.exe -ExecutionPolicy Bypass -File ".\Test-MediaStackProxyAndPorts.ps1" -AutoRepair

# 2. Dual-Node LCP & Performance Optimization Sweep
powershell.exe -ExecutionPolicy Bypass -File ".\Optimize-DualNodeLcp.ps1"

# 3. SQLite Database Integrity & CRUD Optimization
powershell.exe -ExecutionPolicy Bypass -File ".\Optimize-MediaStackDatabase.ps1"

# 4. Enforce 24/7 Always-On Host Safeguards (No-Sleep, Docker Restart & Headroom)
powershell.exe -ExecutionPolicy Bypass -File ".\Set-MediaStackHostSafeguards.ps1"
```

### B. Priority Cluster Reconciliation & Sync (VoltaireDeux First, then VoltaireUn)
```bat
# Execute from Windows Command Prompt or Explorer
sync-cluster.cmd
# or
sync.cmd
```
```powershell
# Execute from PowerShell
powershell.exe -ExecutionPolicy Bypass -File ".\Sync-MediaStackPriorityHandoffs.ps1"
```

### C. Node Main Execution Suites & Shortcuts
```bat
# Fast Shortcuts
s-v1.cmd    # Launches VoltaireUn Main Execution Suite (192.168.4.21)
s-v2.cmd    # Launches VoltaireDeux Main Execution Suite (192.168.4.30)
s.cmd       # Launches Primary Interactive Single-Key HUD Menu
```
```powershell
.\s-v1.ps1  # VoltaireUn Primary Server Hub (Main Ingress & Media Streaming)
.\s-v2.ps1  # VoltaireDeux AI Workstation Hub (Ollama :11434 & MusicBrainz :5001)
.\s.ps1     # Primary Interactive Control Menu
```

---

## 5. Summary of Best Practices & Architectural Invariants

1. **Reconciliation Precedence**:
   * Always ingest **VoltaireDeux material first** (AI collaboration notes, code staging, and x64 manifests) then **VoltaireUn material second** (telemetry, 24/7 sentinel status, and escalations).

2. **Role Invariants**:
   * **VoltaireUn (`192.168.4.21`)**: Primary 24/7 Media Hub, Ingress Gateway (`:80`/`:443`), Jellyfin, Servarr Hub, TVHeadend, HDHomeRun Proxy, DB Web GUI.
   * **VoltaireDeux (`192.168.4.30`)**: AI Acceleration Engine (`Ollama:11434`), MusicBrainz Secondary Mirror (`:5001`), Picard batch tagger, Git Push & AI Staging Source.

3. **Always-On Power & Safeguards**:
   * Power policies enforce zero AC standby, zero hibernation, zero disk idle, and kernel thread pinned with `ES_SYSTEM_REQUIRED | ES_AWAYMODE_REQUIRED`.
   * Proactively maintain > 15 GB free space on Drive C: to prevent WSL2/Docker Exit 137 (SIGKILL).

---
*Generated by MediaStack AI Collaboration Nexus Engine.*  
*Ready for immediate ingestion and execution by Claude.*

