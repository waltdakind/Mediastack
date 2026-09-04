# Expert Operational Handoff: Jellyseerr Request Portal

| Architectural Parameter | Runtime Specification |
| :--- | :--- |
| **Service Key** | jellyseerr |
| **Display Name** | Jellyseerr Request Portal |
| **Service Category** | Requests |
| **Container Name** | jellyseerr |
| **Image Tag** | ghcr.io/seerr-team/seerr:v3.4.1 |
| **Primary Ingress Port** | 5055 |
| **Associated Storage/DB**| db.sqlite |
| **Container Status** | **RUNNING** |
| **Restart Count** | 0 |
| **Container Started** | 2026-09-04T00:26:09.573454877Z |
| **L7 Response Code** | HTTP 307 |
| **TTFB Latency** | 438 ms |
| **Vault Secrets Status**| SECURED IN VAULT |
| **Error Lines Detected**| 4 |
| **Audit Timestamp** | 2026-09-03 20:39:20 |

---

## 1. Network & Reverse-Proxy Topology
- **Local Ingress Endpoint:** `http://localhost:5055/`
- **Caddy Virtual Host Route:** `http://jellyseerr.voltairedeux.local/`
- **Peer Cluster Gateway:** `http://192.168.4.30:5055/`
- **Security Policy:** TLS 1.3 / Reverse-Proxy Ingress isolated via Caddy network.

---

## 2. Storage & Database Layout
- **Host Config Root:** `C:\MediastackConfig\jellyseerr`
- **Active Database File:** `db.sqlite`
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
2026-09-03T12:55:00.005Z [[32minfo[39m][Jobs]: Starting scheduled job: Jellyfin Recently Added Scan  2026-09-03T12:55:00.005Z [[32minfo[39m][Jellyfin Sync]: Scan starting {"sessionId":"6b3a2027-16c9-4029-ab4d-831e319bf22d"} 2026-09-03T12:55:00.039Z [[32minfo[39m][Jellyfin Sync]: Beginning to process recently added for library: Downloads  2026-09-03T12:55:00.052Z [[31merror[39m][Jellyfin API]: Something went wrong while getting library content from the Jellyfin server: Request failed with status code 401 {"error":401} 2026-09-03T12:55:00.053Z [[31merror[39m][Jellyfin Sync]: Sync interrupted {"errorMessage":""} 2026-09-03T12:56:00.001Z [[34mdebug[39m][Jobs]: Starting scheduled job: Download Sync   > seerr@3.4.1 start > NODE_ENV=production node dist/index.js  2026-09-04T00:27:57.251Z [[32minfo[39m]: Commit Tag: 69f73a6f1486fdb51b8ddae9a94a8dfb629f461c  2026-09-04T00:28:29.531Z [[32minfo[39m]: Starting Seerr version 3.4.1  2026-09-04T00:30:18.683Z [[34mdebug[39m][Settings Migrator]: Checking migration '0001_migrate_hostname.js'...  2026-09-04T00:30:18.793Z [[34mdebug[39m][Settings Migrator]: Checking migration '0002_migrate_apitokens.js'...  2026-09-04T00:30:18.886Z [[34mdebug[39m][Settings Migrator]: Checking migration '0003_emby_media_server_type.js'...  2026-09-04T00:30:18.935Z [[34mdebug[39m][Settings Migrator]: Checking migration '0004_migrate_region_setting.js'...  2026-09-04T00:30:18.988Z [[34mdebug[39m][Settings Migrator]: Checking migration '0005_migrate_network_settings.js'...  2026-09-04T00:30:19.099Z [[34mdebug[39m][Settings Migrator]: Checking migration '0006_remove_lunasea.js'...  2026-09-04T00:30:19.152Z [[34mdebug[39m][Settings Migrator]: Checking migration '0007_migrate_arr_tags.js'...  2026-09-04T00:30:19.222Z [[34mdebug[39m][Settings Migrator]: Checking migration '0008_migrate_blacklist_to_blocklist.js'...  2026-09-04T00:30:20.947Z [[32minfo[39m][Notifications]: Registered notification agents  2026-09-04T00:30:21.758Z [[32minfo[39m][Jobs]: Scheduled jobs loaded  2026-09-04T00:30:23.081Z [[32minfo[39m][Server]: Server ready on port 5055  2026-09-04T00:31:00.014Z [[34mdebug[39m][Jobs]: Starting scheduled job: Download Sync  2026-09-04T00:32:00.036Z [[34mdebug[39m][Jobs]: Starting scheduled job: Download Sync  2026-09-04T00:33:00.111Z [[34mdebug[39m][Jobs]: Starting scheduled job: Download Sync  2026-09-04T00:34:00.022Z [[34mdebug[39m][Jobs]: Starting scheduled job: Download Sync  2026-09-04T00:35:00.011Z [[34mdebug[39m][Jobs]: Starting scheduled job: Download Sync  2026-09-04T00:35:00.029Z [[32minfo[39m][Jobs]: Starting scheduled job: Jellyfin Recently Added Scan  2026-09-04T00:35:00.043Z [[32minfo[39m][Jellyfin Sync]: Scan starting {"sessionId":"1318db02-cfb1-4032-a89c-c3c819040379"} 2026-09-04T00:35:00.222Z [[32minfo[39m][Anime-List Sync]: Downloading latest mapping file  2026-09-04T00:35:00.702Z [[32minfo[39m][Anime-List Sync]: Loading mapping file  2026-09-04T00:35:01.928Z [[32minfo[39m][Anime-List Sync]: Loaded 10735 AniDB items from mapping file  2026-09-04T00:35:01.929Z [[32minfo[39m][Jellyfin Sync]: Beginning to process recently added for library: Downloads  2026-09-04T00:35:01.979Z [[31merror[39m][Jellyfin API]: Something went wrong while getting library content from the Jellyfin server: connect ECONNREFUSED 172.21.0.17:8096 {} 2026-09-04T00:35:01.981Z [[31merror[39m][Jellyfin Sync]: Sync interrupted {"errorMessage":""} 2026-09-04T00:36:00.014Z [[34mdebug[39m][Jobs]: Starting scheduled job: Download Sync  2026-09-04T00:37:00.011Z [[34mdebug[39m][Jobs]: Starting scheduled job: Download Sync  2026-09-04T00:38:00.009Z [[34mdebug[39m][Jobs]: Starting scheduled job: Download Sync  2026-09-04T00:39:00.006Z [[34mdebug[39m][Jobs]: Starting scheduled job: Download Sync 
`

---

## 5. Architectural Recommendations & Maintenance Tips
1. **Auto-Recovery:** If degraded, execute `.\Repair-jellyseerr.ps1` or `.\Repair-MediaStackFleet.ps1 -Service Requests`.
2. **Backup Strategy:** Included in atomic hot backup snapshot via `.\Backup-MediaStackFleet.ps1`.
3. **Replication Strategy:** Synchronized across Voltaire nodes via `.\Replicate-MediaStackCluster.ps1`.

---
*Generated autonomously by MediaStack Deep Analysis Engine.*
