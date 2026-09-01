# Expert Operational Handoff: Caddy Ingress Gateway

| Architectural Parameter | Runtime Specification |
| :--- | :--- |
| **Service Key** | caddy |
| **Display Name** | Caddy Ingress Gateway |
| **Service Category** | Ingress |
| **Container Name** | caddy |
| **Image Tag** | caddy:latest |
| **Primary Ingress Port** | 80 |
| **Associated Storage/DB**| N/A |
| **Container Status** | **RUNNING** |
| **Restart Count** | 0 |
| **Container Started** | 2026-08-31T23:38:27.954200722Z |
| **L7 Response Code** | HTTP 301 |
| **TTFB Latency** | 3.1 ms |
| **Vault Secrets Status**| SYSTEM MANAGED |
| **Error Lines Detected**| 0 |
| **Audit Timestamp** | 2026-08-31 20:00:15 |

---

## 1. Network & Reverse-Proxy Topology
- **Local Ingress Endpoint:** `http://localhost:80/`
- **Caddy Virtual Host Route:** `http://caddy.voltairedeux.local/`
- **Peer Cluster Gateway:** `http://192.168.4.30:80/`
- **Security Policy:** TLS 1.3 / Reverse-Proxy Ingress isolated via Caddy network.

---

## 2. Storage & Database Layout
- **Host Config Root:** `C:\MediastackConfig\caddy`
- **Active Database File:** `N/A`
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
{"level":"info","ts":1788219508.3661702,"logger":"http.auto_https","msg":"skipping automatic certificate management because one or more matching certificates are already loaded","domain":"bazarr.voltaireun.local","server_name":"srv0"} {"level":"info","ts":1788219508.366172,"logger":"http.auto_https","msg":"skipping automatic certificate management because one or more matching certificates are already loaded","domain":"sonarr.ordinateur.local","server_name":"srv0"} {"level":"info","ts":1788219508.366174,"logger":"http.auto_https","msg":"skipping automatic certificate management because one or more matching certificates are already loaded","domain":"ordinateur.local","server_name":"srv0"} {"level":"info","ts":1788219508.3661764,"logger":"http.auto_https","msg":"skipping automatic certificate management because one or more matching certificates are already loaded","domain":"sonarr.waltdakind.xubi.org","server_name":"srv0"} {"level":"info","ts":1788219508.366178,"logger":"http.auto_https","msg":"skipping automatic certificate management because one or more matching certificates are already loaded","domain":"musicbrainz.waltdakind.xubi.org","server_name":"srv0"} {"level":"info","ts":1788219508.3661802,"logger":"http.auto_https","msg":"skipping automatic certificate management because one or more matching certificates are already loaded","domain":"dashboard.voltairedeux.local","server_name":"srv0"} {"level":"info","ts":1788219508.366182,"logger":"http.auto_https","msg":"skipping automatic certificate management because one or more matching certificates are already loaded","domain":"radarr.ordinateur.local","server_name":"srv0"} {"level":"info","ts":1788219508.366184,"logger":"http.auto_https","msg":"skipping automatic certificate management because one or more matching certificates are already loaded","domain":"radarr.voltaireun.local","server_name":"srv0"} {"level":"info","ts":1788219508.3661873,"logger":"http.auto_https","msg":"skipping automatic certificate management because one or more matching certificates are already loaded","domain":"radarr.voltairedeux.local","server_name":"srv0"} {"level":"info","ts":1788219508.366189,"logger":"http.auto_https","msg":"skipping automatic certificate management because one or more matching certificates are already loaded","domain":"db.voltairedeux.local","server_name":"srv0"} {"level":"info","ts":1788219508.3661916,"logger":"http.auto_https","msg":"skipping automatic certificate management because one or more matching certificates are already loaded","domain":"transmission.ordinateur.local","server_name":"srv0"} {"level":"info","ts":1788219508.3661933,"logger":"http.auto_https","msg":"skipping automatic certificate management because one or more matching certificates are already loaded","domain":"musicbrainz.voltairedeux.local","server_name":"srv0"} {"level":"info","ts":1788219508.366195,"logger":"http.auto_https","msg":"skipping automatic certificate management because one or more matching certificates are already loaded","domain":"voltaireun.local","server_name":"srv0"} {"level":"info","ts":1788219508.366197,"logger":"http.auto_https","msg":"skipping automatic certificate management because one or more matching certificates are already loaded","domain":"dashboard.ordinateur.local","server_name":"srv0"} {"level":"info","ts":1788219508.366199,"logger":"http.auto_https","msg":"skipping automatic certificate management because one or more matching certificates are already loaded","domain":"prowlarr.waltdakind.xubi.org","server_name":"srv0"} {"level":"info","ts":1788219508.3662026,"logger":"http.auto_https","msg":"skipping automatic certificate management because one or more matching certificates are already loaded","domain":"tvheadend.ordinateur.local","server_name":"srv0"} {"level":"info","ts":1788219508.3662052,"logger":"http.auto_https","msg":"skipping automatic certificate management because one or more matching certificates are already loaded","domain":"voltairedeux.local","server_name":"srv0"} {"level":"info","ts":1788219508.366207,"logger":"http.auto_https","msg":"skipping automatic certificate management because one or more matching certificates are already loaded","domain":"noc.voltaireun.local","server_name":"srv0"} {"level":"info","ts":1788219508.3662088,"logger":"http.auto_https","msg":"skipping automatic certificate management because one or more matching certificates are already loaded","domain":"hdhomerun.ordinateur.local","server_name":"srv0"} {"level":"info","ts":1788219508.3662107,"logger":"http.auto_https","msg":"skipping automatic certificate management because one or more matching certificates are already loaded","domain":"db.ordinateur.local","server_name":"srv0"} {"level":"info","ts":1788219508.3662128,"logger":"http.auto_https","msg":"skipping automatic certificate management because one or more matching certificates are already loaded","domain":"musicbrainz.ordinateur.local","server_name":"srv0"} {"level":"info","ts":1788219508.3662148,"logger":"http.auto_https","msg":"skipping automatic certificate management because one or more matching certificates are already loaded","domain":"musicbrainz.voltaireun.local","server_name":"srv0"} {"level":"info","ts":1788219508.366217,"logger":"http.auto_https","msg":"skipping automatic certificate management because one or more matching certificates are already loaded","domain":"hdhomerun.voltairedeux.local","server_name":"srv0"} {"level":"info","ts":1788219508.3662188,"logger":"http.auto_https","msg":"enabling automatic HTTP->HTTPS redirects","server_name":"srv0"} {"level":"warn","ts":1788219508.366266,"logger":"http.auto_https","msg":"server is listening only on the HTTP port, so no automatic HTTPS will be applied to this server","server_name":"srv1","http_port":80} {"level":"warn","ts":1788219508.545425,"logger":"pki.ca.local","msg":"installing root certificate (you might be prompted for password)","path":"storage:pki/authorities/local/root.crt"} {"level":"info","ts":1788219508.5491858,"msg":"warning: \"certutil\" is not available, install \"certutil\" with \"apt install libnss3-tools\" or \"yum install nss-tools\" and try again"} {"level":"info","ts":1788219508.5492897,"msg":"define JAVA_HOME environment variable to use the Java trust"} {"level":"info","ts":1788219508.5947142,"msg":"certificate installed properly in linux trusts"} {"level":"info","ts":1788219508.5985024,"logger":"http","msg":"enabling HTTP/3 listener","addr":":443"} {"level":"info","ts":1788219508.5993652,"logger":"http.log","msg":"server running","name":"srv0","protocols":["h1","h2","h3"]} {"level":"warn","ts":1788219508.59947,"logger":"http","msg":"HTTP/2 skipped because it requires TLS","network":"tcp","addr":":80"} {"level":"warn","ts":1788219508.5994735,"logger":"http","msg":"HTTP/3 skipped because it requires TLS","network":"tcp","addr":":80"} {"level":"info","ts":1788219508.5994751,"logger":"http.log","msg":"server running","name":"srv1","protocols":["h1","h2","h3"]} {"level":"warn","ts":1788219508.5995088,"logger":"http","msg":"HTTP/2 skipped because it requires TLS","network":"tcp","addr":":8096"} {"level":"warn","ts":1788219508.5995104,"logger":"http","msg":"HTTP/3 skipped because it requires TLS","network":"tcp","addr":":8096"} {"level":"info","ts":1788219508.599512,"logger":"http.log","msg":"server running","name":"srv2","protocols":["h1","h2","h3"]} {"level":"info","ts":1788219508.5995495,"msg":"serving initial configuration"} {"level":"info","ts":1788219508.6112304,"logger":"tls","msg":"cleaning storage unit","storage":"FileStorage:/data/caddy"} {"level":"info","ts":1788219509.2234457,"logger":"tls","msg":"finished cleaning storage units"}
`

---

## 5. Architectural Recommendations & Maintenance Tips
1. **Auto-Recovery:** If degraded, execute `.\Repair-caddy.ps1` or `.\Repair-MediaStackFleet.ps1 -Service Ingress`.
2. **Backup Strategy:** Included in atomic hot backup snapshot via `.\Backup-MediaStackFleet.ps1`.
3. **Replication Strategy:** Synchronized across Voltaire nodes via `.\Replicate-MediaStackCluster.ps1`.

---
*Generated autonomously by MediaStack Deep Analysis Engine.*
