# Expert Operational Handoff: TVHeadend Live TV Gateway

| Architectural Parameter | Runtime Specification |
| :--- | :--- |
| **Service Key** | tvheadend |
| **Display Name** | TVHeadend Live TV Gateway |
| **Service Category** | LiveTV |
| **Container Name** | tvheadend |
| **Image Tag** | lscr.io/linuxserver/tvheadend:latest |
| **Primary Ingress Port** | 9981 |
| **Associated Storage/DB**| tvh.db |
| **Container Status** | **RUNNING** |
| **Restart Count** | 0 |
| **Container Started** | 2026-09-05T15:08:57.9182489Z |
| **L7 Response Code** | HTTP 302 |
| **TTFB Latency** | 2.9 ms |
| **Vault Secrets Status**| SYSTEM MANAGED |
| **Error Lines Detected**| 0 |
| **Audit Timestamp** | 2026-09-05 12:09:46 |

---

## 1. Network & Reverse-Proxy Topology
- **Local Ingress Endpoint:** `http://localhost:9981/`
- **Caddy Virtual Host Route:** `http://tvheadend.voltairedeux.local/`
- **Peer Cluster Gateway:** `http://192.168.4.30:9981/`
- **Security Policy:** TLS 1.3 / Reverse-Proxy Ingress isolated via Caddy network.

---

## 2. Storage & Database Layout
- **Host Config Root:** `C:\MediastackConfig\tvheadend`
- **Active Database File:** `tvh.db`
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

`

---

## 5. Architectural Recommendations & Maintenance Tips
1. **Auto-Recovery:** If degraded, execute `.\Repair-tvheadend.ps1` or `.\Repair-MediaStackFleet.ps1 -Service LiveTV`.
2. **Backup Strategy:** Included in atomic hot backup snapshot via `.\Backup-MediaStackFleet.ps1`.
3. **Replication Strategy:** Synchronized across Voltaire nodes via `.\Replicate-MediaStackCluster.ps1`.

---
*Generated autonomously by MediaStack Deep Analysis Engine.*
