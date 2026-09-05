# Expert Operational Handoff: Syncthing P2P Mesh

| Architectural Parameter | Runtime Specification |
| :--- | :--- |
| **Service Key** | syncthing |
| **Display Name** | Syncthing P2P Mesh |
| **Service Category** | Replication |
| **Container Name** | syncthing |
| **Image Tag** | syncthing/syncthing:latest |
| **Primary Ingress Port** | 8384 |
| **Associated Storage/DB**| index.db |
| **Container Status** | **RUNNING** |
| **Restart Count** | 0 |
| **Container Started** | 2026-09-05T15:08:57.9914666Z |
| **L7 Response Code** | HTTP 200 |
| **TTFB Latency** | 15.9 ms |
| **Vault Secrets Status**| SYSTEM MANAGED |
| **Error Lines Detected**| 5 |
| **Audit Timestamp** | 2026-09-05 12:09:46 |

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
2026-09-05 02:55:31 INF Joined relay (uri=relay://152.53.241.12:22067 log.pkg=relay/client)
2026-09-05 02:55:32 INF Detected NAT type (uri=quic://0.0.0.0:22000 type="Symmetric NAT" log.pkg=connections)
2026-09-05 04:41:29 WRN Failed TLS handshake (address=172.18.0.1:43958 error=EOF log.pkg=connections)
2026-09-05 15:08:59 WRN Failed to correct directory permissions (error="chmod /var/syncthing/config: operation not permitted" log.pkg=syncthing)
2026-09-05 15:08:59 WRN Failed to correct directory permissions (error="chmod /var/syncthing/config: operation not permitted" log.pkg=syncthing)
2026-09-05 15:08:59 WRN Failed to correct directory permissions (error="chmod /var/syncthing/config: operation not permitted" log.pkg=syncthing)
2026-09-05 15:08:59 WRN Failed to correct directory permissions (error="chmod /var/syncthing/config: operation not permitted" log.pkg=syncthing)
2026-09-05 15:08:59 INF syncthing v2.1.3 "Hafnium Hornet" (go1.26.5 linux-arm64) docker@github.syncthing.net 2026-08-03 21:36:05 UTC [noupgrade] (log.pkg=main)
2026-09-05 15:09:00 INF Calculated our device ID (device=ZHSGT66-QM4AUE2-IT642NG-6JJPFCN-STLFGS4-7SHNGAT-YCGERY6-YY34KQW log.pkg=syncthing)
2026-09-05 15:09:00 INF Overall rate limit in use (send="is unlimited" recv="is unlimited" log.pkg=connections)
2026-09-05 15:09:00 INF Using discovery mechanism (identity="global discovery server https://discovery-lookup.syncthing.net/v2/?noannounce" log.pkg=discover)
2026-09-05 15:09:00 INF Relay listener starting (id=dynamic+https://relays.syncthing.net/endpoint log.pkg=connections)
2026-09-05 15:09:00 INF QUIC listener starting (address="[::]:22000" log.pkg=connections)
2026-09-05 15:09:00 INF Using discovery mechanism (identity="global discovery server https://discovery-announce-v4.syncthing.net/v2/?nolookup" log.pkg=discover)
2026-09-05 15:09:00 INF Using discovery mechanism (identity="global discovery server https://discovery-announce-v6.syncthing.net/v2/?nolookup" log.pkg=discover)
2026-09-05 15:09:00 INF TCP listener starting (address="[::]:22000" log.pkg=connections)
2026-09-05 15:09:00 INF Using discovery mechanism (identity="IPv4 local broadcast discovery on port 21027" log.pkg=discover)
2026-09-05 15:09:00 INF Using discovery mechanism (identity="IPv6 local multicast discovery on address [ff12::8384]:21027" log.pkg=discover)
2026-09-05 15:09:00 INF GUI and API listening (address="[::]:8384" log.pkg=api)
2026-09-05 15:09:00 INF Access the GUI via the following URL: http://127.0.0.1:8384/ (log.pkg=api)
2026-09-05 15:09:00 INF Loaded configuration (name=mediastack-x64 log.pkg=syncthing)
2026-09-05 15:09:01 INF Measured hashing performance (perf="1422.86 MB/s" log.pkg=syncthing)
2026-09-05 15:09:21 INF Detected NAT services (count=0 log.pkg=nat)
2026-09-05 15:09:21 INF Joined relay (uri=relay://38.49.216.42:22067 log.pkg=relay/client)
2026-09-05 15:09:23 INF Detected NAT type (uri=quic://0.0.0.0:22000 type="Symmetric NAT" log.pkg=connections)

`

---

## 5. Architectural Recommendations & Maintenance Tips
1. **Auto-Recovery:** If degraded, execute `.\Repair-syncthing.ps1` or `.\Repair-MediaStackFleet.ps1 -Service Replication`.
2. **Backup Strategy:** Included in atomic hot backup snapshot via `.\Backup-MediaStackFleet.ps1`.
3. **Replication Strategy:** Synchronized across Voltaire nodes via `.\Replicate-MediaStackCluster.ps1`.

---
*Generated autonomously by MediaStack Deep Analysis Engine.*
