# Expert Operational Handoff: Bazarr Subtitles Manager

| Architectural Parameter | Runtime Specification |
| :--- | :--- |
| **Service Key** | bazarr |
| **Display Name** | Bazarr Subtitles Manager |
| **Service Category** | Servarr |
| **Container Name** | bazarr |
| **Image Tag** | lscr.io/linuxserver/bazarr:latest |
| **Primary Ingress Port** | 6767 |
| **Associated Storage/DB**| bazarr.db |
| **Container Status** | **RUNNING** |
| **Restart Count** | 0 |
| **Container Started** | 2026-09-01T20:07:40.165895266Z |
| **L7 Response Code** | HTTP 200 |
| **TTFB Latency** | 445.9 ms |
| **Vault Secrets Status**| SECURED IN VAULT |
| **Error Lines Detected**| 0 |
| **Audit Timestamp** | 2026-09-01 17:53:17 |

---

## 1. Network & Reverse-Proxy Topology
- **Local Ingress Endpoint:** `http://localhost:6767/`
- **Caddy Virtual Host Route:** `http://bazarr.voltairedeux.local/`
- **Peer Cluster Gateway:** `http://192.168.4.30:6767/`
- **Security Policy:** TLS 1.3 / Reverse-Proxy Ingress isolated via Caddy network.

---

## 2. Storage & Database Layout
- **Host Config Root:** `C:\MediastackConfig\bazarr`
- **Active Database File:** `bazarr.db`
- **Persistent Media Mounts:** `C:\MediastackShares\` (Music, TV, Videos, Radio, Podcasts)
- **Lock Management:** SQLite WAL with zero-downtime checkpoints.

---

## 3. Inter-Service Handshake Matrix
- **Upstream Gateway:** Caddy Reverse Proxy (`caddy:80/443`)
- **Downstream Dependencies:** `mediastack-db`, `redis`, `postgres`
- **Cluster Peer Target:** VoltaireUn (`192.168.4.21`) via reciprocal SMB & Syncthing mesh.

---

## 4. Diagnostic Log Mining & Health Assessment
### Log Extraction (Last 40 Lines)
`	ext
[migrations] started [migrations] no migrations found ───────────────────────────────────────        ██╗     ███████╗██╗ ██████╗       ██║     ██╔════╝██║██╔═══██╗       ██║     ███████╗██║██║   ██║       ██║     ╚════██║██║██║   ██║       ███████╗███████║██║╚██████╔╝       ╚══════╝╚══════╝╚═╝ ╚═════╝     Brought to you by linuxserver.io ───────────────────────────────────────  To support the app dev(s) visit: Bazarr: https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=XHHRWXT9YB7WE&source=url  To support LSIO projects visit: https://www.linuxserver.io/donate/  ─────────────────────────────────────── GID/UID ───────────────────────────────────────  User UID:    1000 User GID:    1000 ─────────────────────────────────────── Linuxserver.io version: v1.6.0-ls359 Build-date: 2026-08-16T14:25:04+00:00 ───────────────────────────────────────      [custom-init] No custom files found, skipping... Bazarr starting child process with PID 165... 2026-09-01 16:08:02,573 - root                             (fcd255c2ad20) :  INFO (scheduler:78) - Scheduler will use this timezone: America/New_York Connection to localhost (::1) 6767 port [tcp/*] succeeded! [ls.io-init] done. 2026-09-01 16:08:05,974 - root                             (fcd255c2ad20) :  INFO (main:86) - Interactive jobs queue started and waiting for tasks 2026-09-01 16:08:05,975 - waitress                         (fcd255c2ad20) :  INFO (wasyncore:449) - BAZARR is started and waiting for requests on: http://***.***.***.***:6767 2026-09-01 16:08:05,976 - waitress                         (fcd255c2ad20) :  INFO (wasyncore:449) - BAZARR is started and waiting for requests on: http://[::]:6767
`

---

## 5. Architectural Recommendations & Maintenance Tips
1. **Auto-Recovery:** If degraded, execute `.\Repair-bazarr.ps1` or `.\Repair-MediaStackFleet.ps1 -Service Servarr`.
2. **Backup Strategy:** Included in atomic hot backup snapshot via `.\Backup-MediaStackFleet.ps1`.
3. **Replication Strategy:** Synchronized across Voltaire nodes via `.\Replicate-MediaStackCluster.ps1`.

---
*Generated autonomously by MediaStack Deep Analysis Engine.*
