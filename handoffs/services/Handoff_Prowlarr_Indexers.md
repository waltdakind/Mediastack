# Expert Operational Handoff: Prowlarr Indexer Aggregator

| Architectural Parameter | Runtime Specification |
| :--- | :--- |
| **Service Key** | prowlarr |
| **Display Name** | Prowlarr Indexer Aggregator |
| **Service Category** | Servarr |
| **Container Name** | prowlarr |
| **Image Tag** | N/A |
| **Primary Ingress Port** | 9696 |
| **Associated Storage/DB**| prowlarr.db |
| **Container Status** | **STOPPED** |
| **Restart Count** | 0 |
| **Container Started** | N/A |
| **L7 Response Code** | HTTP 302 |
| **TTFB Latency** | 5.3 ms |
| **Vault Secrets Status**| SECURED IN VAULT |
| **Error Lines Detected**| 0 |
| **Audit Timestamp** | 2026-08-31 20:00:15 |

---

## 1. Network & Reverse-Proxy Topology
- **Local Ingress Endpoint:** `http://localhost:9696/`
- **Caddy Virtual Host Route:** `http://prowlarr.voltairedeux.local/`
- **Peer Cluster Gateway:** `http://192.168.4.30:9696/`
- **Security Policy:** TLS 1.3 / Reverse-Proxy Ingress isolated via Caddy network.

---

## 2. Storage & Database Layout
- **Host Config Root:** `C:\MediastackConfig\prowlarr`
- **Active Database File:** `prowlarr.db`
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
1. **Auto-Recovery:** If degraded, execute `.\Repair-prowlarr.ps1` or `.\Repair-MediaStackFleet.ps1 -Service Servarr`.
2. **Backup Strategy:** Included in atomic hot backup snapshot via `.\Backup-MediaStackFleet.ps1`.
3. **Replication Strategy:** Synchronized across Voltaire nodes via `.\Replicate-MediaStackCluster.ps1`.

---
*Generated autonomously by MediaStack Deep Analysis Engine.*
