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
| **Container Started** | 2026-09-04T00:26:13.104936685Z |
| **L7 Response Code** | HTTP 302 |
| **TTFB Latency** | 18.4 ms |
| **Vault Secrets Status**| SECURED IN VAULT |
| **Error Lines Detected**| 0 |
| **Audit Timestamp** | 2026-09-03 20:39:20 |

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
2026-09-03 20:27:16.896 [   INFO] epggrab: module nz_freeview2 created 2026-09-03 20:27:16.896 [   INFO] epggrab: module nz_freeview1 created 2026-09-03 20:27:16.896 [   INFO] epggrab: module viasat_baltic created 2026-09-03 20:27:16.896 [   INFO] epggrab: module Bulsatcom_39E created 2026-09-03 20:27:16.896 [   INFO] epggrab: module uk_cable_virgin created 2026-09-03 20:27:16.896 [   INFO] epggrab: module eit created 2026-09-03 20:27:16.896 [   INFO] epggrab: module psip created 2026-09-03 20:27:17.181 [   INFO] epggrab: module opentv-skyit created 2026-09-03 20:27:17.182 [   INFO] epggrab: module opentv-ausat created 2026-09-03 20:27:17.182 [   INFO] epggrab: module opentv-skyuk created 2026-09-03 20:27:17.182 [   INFO] epggrab: module opentv-skynz created 2026-09-03 20:27:17.182 [   INFO] epggrab: module xmltv created 2026-09-03 20:27:17.241 [   INFO] spawn: Executing "/usr/bin/tv_find_grabbers" 2026-09-03 20:27:25.024 [   INFO] epggrab: module /usr/bin/tv_grab_wg created 2026-09-03 20:27:25.024 [   INFO] epggrab: module /usr/bin/tv_grab_url created 2026-09-03 20:27:25.024 [   INFO] epggrab: module /usr/bin/tv_grab_file created 2026-09-03 20:27:25.024 [   INFO] epggrab: module /usr/bin/tv_grab_combiner created 2026-09-03 20:27:25.024 [   INFO] epggrab: module /usr/bin/tv_grab_it created 2026-09-03 20:27:25.024 [   INFO] epggrab: module /usr/bin/tv_grab_fi_sv created 2026-09-03 20:27:25.024 [   INFO] epggrab: module /usr/bin/tv_grab_ch_search created 2026-09-03 20:27:25.024 [   INFO] epggrab: module /usr/bin/tv_grab_huro created 2026-09-03 20:27:25.024 [   INFO] epggrab: module /usr/bin/tv_grab_na_tvmedia created 2026-09-03 20:27:25.024 [   INFO] epggrab: module /usr/bin/tv_grab_zz_sdjson_sqlite created 2026-09-03 20:27:25.024 [   INFO] epggrab: module /usr/bin/tv_grab_zz_sdjson created 2026-09-03 20:27:25.024 [   INFO] epggrab: module /usr/bin/tv_grab_fi created 2026-09-03 20:27:25.024 [   INFO] epggrab: module /usr/bin/tv_grab_fr created 2026-09-03 20:27:25.047 [   INFO] tbl-eit: module eit - scraper disabled by config 2026-09-03 20:27:25.270 [   INFO] epgdb: gzip format detected, inflating (ratio 138.6% deflated size 79) 2026-09-03 20:27:25.270 [   INFO] epgdb: parsing 57 bytes 2026-09-03 20:27:25.270 [   INFO] epgdb: loaded v3 2026-09-03 20:27:25.270 [   INFO] epgdb:   config     1 2026-09-03 20:27:25.270 [   INFO] epgdb:   broadcasts 0 2026-09-03 20:27:25.374 [   INFO] dvr: Purging obsolete autorec entries for current schedule 2026-09-03 20:27:25.374 [ NOTICE] START: HTS Tvheadend version 4.3-2735~gfcd987f0b started, running as PID:147 UID:1000 GID:1000, CWD:/run/s6-rc:s6-rc-init:oEiLMl/servicedirs/svc-tvheadend CNF:/config 2026-09-03 20:29:29.031 [   INFO] scanfile: DVB-S - loaded 1 regions with 257 networks 2026-09-03 20:29:29.031 [   INFO] scanfile: DVB-T - loaded 46 regions with 1171 networks 2026-09-03 20:29:29.031 [   INFO] scanfile: DVB-C - loaded 23 regions with 93 networks 2026-09-03 20:29:29.031 [   INFO] scanfile: ATSC-T - loaded 2 regions with 16 networks 2026-09-03 20:29:29.031 [   INFO] scanfile: ATSC-C - loaded 2 regions with 6 networks 2026-09-03 20:29:29.032 [   INFO] scanfile: ISDB-T - loaded 2 regions with 4210 networks
`

---

## 5. Architectural Recommendations & Maintenance Tips
1. **Auto-Recovery:** If degraded, execute `.\Repair-tvheadend.ps1` or `.\Repair-MediaStackFleet.ps1 -Service LiveTV`.
2. **Backup Strategy:** Included in atomic hot backup snapshot via `.\Backup-MediaStackFleet.ps1`.
3. **Replication Strategy:** Synchronized across Voltaire nodes via `.\Replicate-MediaStackCluster.ps1`.

---
*Generated autonomously by MediaStack Deep Analysis Engine.*
