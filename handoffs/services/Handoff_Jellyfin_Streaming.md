# Expert Operational Handoff: Jellyfin Streaming Server

| Architectural Parameter | Runtime Specification |
| :--- | :--- |
| **Service Key** | jellyfin |
| **Display Name** | Jellyfin Streaming Server |
| **Service Category** | Streaming |
| **Container Name** | jellyfin |
| **Image Tag** | N/A |
| **Primary Ingress Port** | 8096 |
| **Associated Storage/DB**| jellyfin.db |
| **Container Status** | **STOPPED** |
| **Restart Count** | 0 |
| **Container Started** | N/A |
| **L7 Response Code** | HTTP 000 |
| **TTFB Latency** | 1143.3 ms |
| **Vault Secrets Status**| SECURED IN VAULT |
| **Error Lines Detected**| 0 |
| **Audit Timestamp** | 2026-09-03 20:39:20 |

---

## 1. Network & Reverse-Proxy Topology
- **Local Ingress Endpoint:** `http://localhost:8096/`
- **Caddy Virtual Host Route:** `http://jellyfin.voltairedeux.local/`
- **Peer Cluster Gateway:** `http://192.168.4.30:8096/`
- **Security Policy:** TLS 1.3 / Reverse-Proxy Ingress isolated via Caddy network.

---

## 2. Storage & Database Layout
- **Host Config Root:** `C:\MediastackConfig\jellyfin`
- **Active Database File:** `jellyfin.db`
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
Container offline.
`

---

## 5. Architectural Recommendations & Maintenance Tips
1. **Auto-Recovery:** If degraded, execute `.\Repair-jellyfin.ps1` or `.\Repair-MediaStackFleet.ps1 -Service Streaming`.
2. **Backup Strategy:** Included in atomic hot backup snapshot via `.\Backup-MediaStackFleet.ps1`.
3. **Replication Strategy:** Synchronized across Voltaire nodes via `.\Replicate-MediaStackCluster.ps1`.

---
*Generated autonomously by MediaStack Deep Analysis Engine.*
