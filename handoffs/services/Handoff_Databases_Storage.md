# Expert Operational Handoff: MediaStack SQLite Web DB

| Architectural Parameter | Runtime Specification |
| :--- | :--- |
| **Service Key** | mediastack-db |
| **Display Name** | MediaStack SQLite Web DB |
| **Service Category** | Database |
| **Container Name** | mediastack-db |
| **Image Tag** | coleifer/sqlite-web |
| **Primary Ingress Port** | 8080 |
| **Associated Storage/DB**| mediastack_backup.db |
| **Container Status** | **RUNNING** |
| **Restart Count** | 0 |
| **Container Started** | 2026-08-31T23:38:17.174600687Z |
| **L7 Response Code** | HTTP 200 |
| **TTFB Latency** | 48.4 ms |
| **Vault Secrets Status**| SYSTEM MANAGED |
| **Error Lines Detected**| 0 |
| **Audit Timestamp** | 2026-08-31 20:00:15 |

---

## 1. Network & Reverse-Proxy Topology
- **Local Ingress Endpoint:** `http://localhost:8080/`
- **Caddy Virtual Host Route:** `http://mediastack-db.voltairedeux.local/`
- **Peer Cluster Gateway:** `http://192.168.4.30:8080/`
- **Security Policy:** TLS 1.3 / Reverse-Proxy Ingress isolated via Caddy network.

---

## 2. Storage & Database Layout
- **Host Config Root:** `C:\MediastackConfig\mediastack-db`
- **Active Database File:** `mediastack_backup.db`
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
172.18.0.1 - - [30/Aug/2026 03:36:46] "GET / HTTP/1.1" 200 - 172.18.0.1 - - [30/Aug/2026 03:38:07] "GET / HTTP/1.1" 200 - 172.18.0.1 - - [30/Aug/2026 03:38:14] "GET / HTTP/1.1" 200 - 172.18.0.1 - - [30/Aug/2026 03:38:25] "GET / HTTP/1.1" 200 - 172.18.0.1 - - [30/Aug/2026 16:26:53] "GET / HTTP/1.1" 200 -  * Serving Flask app 'sqlite_web.sqlite_web'  * Debug mode: off [31m[1mWARNING: This is a development server. Do not use it in a production deployment. Use a production WSGI server instead.[0m  * Running on all addresses (0.0.0.0)  * Running on http://127.0.0.1:8080  * Running on http://172.18.0.2:8080 [33mPress CTRL+C to quit[0m 172.18.0.1 - - [30/Aug/2026 22:29:33] "GET / HTTP/1.1" 200 - 172.18.0.1 - - [30/Aug/2026 22:30:58] "GET / HTTP/1.1" 200 - 172.18.0.1 - - [30/Aug/2026 22:31:42] "GET / HTTP/1.1" 200 - 172.18.0.3 - - [30/Aug/2026 22:33:59] "GET / HTTP/1.1" 200 - 172.18.0.3 - - [30/Aug/2026 23:16:48] "GET / HTTP/1.1" 200 - 172.18.0.1 - - [30/Aug/2026 23:17:07] "GET / HTTP/1.1" 200 - 172.18.0.1 - - [31/Aug/2026 01:50:44] "GET / HTTP/1.1" 200 - 172.18.0.1 - - [31/Aug/2026 01:51:03] "GET / HTTP/1.1" 200 - 172.18.0.1 - - [31/Aug/2026 01:52:40] "GET / HTTP/1.1" 200 - 172.18.0.1 - - [31/Aug/2026 01:52:51] "GET / HTTP/1.1" 200 - 172.18.0.3 - - [31/Aug/2026 01:52:56] "GET / HTTP/1.1" 200 - 172.18.0.1 - - [31/Aug/2026 05:49:16] "GET / HTTP/1.1" 200 - 172.18.0.1 - - [31/Aug/2026 05:49:43] "GET / HTTP/1.1" 200 - 172.18.0.3 - - [31/Aug/2026 05:49:48] "GET / HTTP/1.1" 200 - 172.18.0.3 - - [31/Aug/2026 20:46:28] "GET / HTTP/1.1" 200 - 172.18.0.3 - - [31/Aug/2026 20:48:30] "GET / HTTP/1.1" 200 - 172.18.0.1 - - [31/Aug/2026 22:56:59] "GET / HTTP/1.1" 200 - 172.18.0.1 - - [31/Aug/2026 22:59:45] "GET / HTTP/1.1" 200 -  * Serving Flask app 'sqlite_web.sqlite_web'  * Debug mode: off [31m[1mWARNING: This is a development server. Do not use it in a production deployment. Use a production WSGI server instead.[0m  * Running on all addresses (0.0.0.0)  * Running on http://127.0.0.1:8080  * Running on http://172.18.0.2:8080 [33mPress CTRL+C to quit[0m 172.18.0.1 - - [31/Aug/2026 23:58:46] "GET / HTTP/1.1" 200 - 172.18.0.1 - - [31/Aug/2026 23:59:05] "GET / HTTP/1.1" 200 - 172.18.0.1 - - [31/Aug/2026 23:59:51] "GET / HTTP/1.1" 200 -
`

---

## 5. Architectural Recommendations & Maintenance Tips
1. **Auto-Recovery:** If degraded, execute `.\Repair-mediastack-db.ps1` or `.\Repair-MediaStackFleet.ps1 -Service Database`.
2. **Backup Strategy:** Included in atomic hot backup snapshot via `.\Backup-MediaStackFleet.ps1`.
3. **Replication Strategy:** Synchronized across Voltaire nodes via `.\Replicate-MediaStackCluster.ps1`.

---
*Generated autonomously by MediaStack Deep Analysis Engine.*
