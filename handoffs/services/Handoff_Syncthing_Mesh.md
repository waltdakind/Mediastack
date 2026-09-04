# Expert Operational Handoff: Syncthing P2P Mesh

| Architectural Parameter | Runtime Specification |
| :--- | :--- |
| **Service Key** | syncthing |
| **Display Name** | Syncthing P2P Mesh |
| **Service Category** | Replication |
| **Container Name** | syncthing |
| **Image Tag** | N/A |
| **Primary Ingress Port** | 8384 |
| **Associated Storage/DB**| index.db |
| **Container Status** | **STOPPED** |
| **Restart Count** | 0 |
| **Container Started** | N/A |
| **L7 Response Code** | HTTP 000 |
| **TTFB Latency** | 2253.2 ms |
| **Vault Secrets Status**| SECURED IN VAULT |
| **Error Lines Detected**| 0 |
| **Audit Timestamp** | 2026-09-03 20:39:20 |

---

## 1. Network & Reverse-Proxy Topology
- **Local Ingress Endpoint:** `http://localhost:8384/`
- **Caddy Virtual Host Route:** `http://syncthing.voltairedeux.local/`
- **Peer Cluster Gateway:** `http://192.168.4.30:8384/`
- **Security Policy:** TLS 1.3 / Reverse-Proxy Ingress isolated via Caddy network.

---

## 2. Storage & Database Layout
- **Host Config Root:** `C:\MediastackConfig\syncthing`
- **Active Database File:** `index.db`
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
1. **Auto-Recovery:** If degraded, execute `.\Repair-syncthing.ps1` or `.\Repair-MediaStackFleet.ps1 -Service Replication`.
2. **Backup Strategy:** Included in atomic hot backup snapshot via `.\Backup-MediaStackFleet.ps1`.
3. **Replication Strategy:** Synchronized across Voltaire nodes via `.\Replicate-MediaStackCluster.ps1`.

---
*Generated autonomously by MediaStack Deep Analysis Engine.*
