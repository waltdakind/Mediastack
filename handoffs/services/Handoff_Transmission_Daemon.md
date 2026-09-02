# Expert Operational Handoff: Transmission BitTorrent

| Architectural Parameter | Runtime Specification |
| :--- | :--- |
| **Service Key** | transmission |
| **Display Name** | Transmission BitTorrent |
| **Service Category** | Downloader |
| **Container Name** | transmission |
| **Image Tag** | lscr.io/linuxserver/transmission:latest |
| **Primary Ingress Port** | 9091 |
| **Associated Storage/DB**| settings.json |
| **Container Status** | **RUNNING** |
| **Restart Count** | 0 |
| **Container Started** | 2026-09-01T20:20:39.757337751Z |
| **L7 Response Code** | HTTP 301 |
| **TTFB Latency** | 37.3 ms |
| **Vault Secrets Status**| SECURED IN VAULT |
| **Error Lines Detected**| 0 |
| **Audit Timestamp** | 2026-09-01 17:53:17 |

---

## 1. Network & Reverse-Proxy Topology
- **Local Ingress Endpoint:** `http://localhost:9091/`
- **Caddy Virtual Host Route:** `http://transmission.voltairedeux.local/`
- **Peer Cluster Gateway:** `http://192.168.4.30:9091/`
- **Security Policy:** TLS 1.3 / Reverse-Proxy Ingress isolated via Caddy network.

---

## 2. Storage & Database Layout
- **Host Config Root:** `C:\MediastackConfig\transmission`
- **Active Database File:** `settings.json`
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
[migrations] started [migrations] no migrations found ───────────────────────────────────────        ██╗     ███████╗██╗ ██████╗       ██║     ██╔════╝██║██╔═══██╗       ██║     ███████╗██║██║   ██║       ██║     ╚════██║██║██║   ██║       ███████╗███████║██║╚██████╔╝       ╚══════╝╚══════╝╚═╝ ╚═════╝     Brought to you by linuxserver.io ───────────────────────────────────────  To support LSIO projects visit: https://www.linuxserver.io/donate/  ─────────────────────────────────────── GID/UID ───────────────────────────────────────  User UID:    1000 User GID:    1000 ─────────────────────────────────────── Linuxserver.io version: 4.1.3-r0-ls357 Build-date: 2026-08-04T12:22:56+00:00 ───────────────────────────────────────      [custom-init] No custom files found, skipping... Connection to localhost (::1) 9091 port [tcp/*] succeeded! [ls.io-init] done.
`

---

## 5. Architectural Recommendations & Maintenance Tips
1. **Auto-Recovery:** If degraded, execute `.\Repair-transmission.ps1` or `.\Repair-MediaStackFleet.ps1 -Service Downloader`.
2. **Backup Strategy:** Included in atomic hot backup snapshot via `.\Backup-MediaStackFleet.ps1`.
3. **Replication Strategy:** Synchronized across Voltaire nodes via `.\Replicate-MediaStackCluster.ps1`.

---
*Generated autonomously by MediaStack Deep Analysis Engine.*
