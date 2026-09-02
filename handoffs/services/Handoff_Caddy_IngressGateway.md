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
| **Container Started** | 2026-09-01T19:57:44.398313839Z |
| **L7 Response Code** | HTTP 301 |
| **TTFB Latency** | 3 ms |
| **Vault Secrets Status**| SYSTEM MANAGED |
| **Error Lines Detected**| 0 |
| **Audit Timestamp** | 2026-09-01 17:53:17 |

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
{"level":"info","ts":1788292665.7326198,"logger":"http.auto_https","msg":"skipping automatic certificate management because one or more matching certificates are already loaded","domain":"home.voltaireun.local","server_name":"srv0"} {"level":"info","ts":1788292665.7326236,"logger":"http.auto_https","msg":"skipping automatic certificate management because one or more matching certificates are already loaded","domain":"sonarr.waltdakind.xubi.org","server_name":"srv0"} {"level":"info","ts":1788292665.732626,"logger":"http.auto_https","msg":"skipping automatic certificate management because one or more matching certificates are already loaded","domain":"radarr.waltdakind.xubi.org","server_name":"srv0"} {"level":"info","ts":1788292665.7326276,"logger":"http.auto_https","msg":"skipping automatic certificate management because one or more matching certificates are already loaded","domain":"diun.voltaireun.local","server_name":"srv0"} {"level":"info","ts":1788292665.7326298,"logger":"http.auto_https","msg":"skipping automatic certificate management because one or more matching certificates are already loaded","domain":"db.voltaireun.local","server_name":"srv0"} {"level":"info","ts":1788292665.732632,"logger":"http.auto_https","msg":"skipping automatic certificate management because one or more matching certificates are already loaded","domain":"musicbrainz.waltdakind.xubi.org","server_name":"srv0"} {"level":"info","ts":1788292665.7326396,"logger":"http.auto_https","msg":"skipping automatic certificate management because one or more matching certificates are already loaded","domain":"jellyseerr.waltdakind.xubi.org","server_name":"srv0"} {"level":"info","ts":1788292665.732643,"logger":"http.auto_https","msg":"skipping automatic certificate management because one or more matching certificates are already loaded","domain":"voltairedeux.local","server_name":"srv0"} {"level":"info","ts":1788292665.7326453,"logger":"http.auto_https","msg":"skipping automatic certificate management because one or more matching certificates are already loaded","domain":"musicbrainz.voltaireun.local","server_name":"srv0"} {"level":"info","ts":1788292665.7326474,"logger":"http.auto_https","msg":"skipping automatic certificate management because one or more matching certificates are already loaded","domain":"192.168.4.30","server_name":"srv0"} {"level":"info","ts":1788292665.7326496,"logger":"http.auto_https","msg":"skipping automatic certificate management because one or more matching certificates are already loaded","domain":"hub.voltaireun.local","server_name":"srv0"} {"level":"info","ts":1788292665.7326515,"logger":"http.auto_https","msg":"skipping automatic certificate management because one or more matching certificates are already loaded","domain":"homepage.waltdakind.xubi.org","server_name":"srv0"} {"level":"info","ts":1788292665.7326534,"logger":"http.auto_https","msg":"skipping automatic certificate management because one or more matching certificates are already loaded","domain":"radarr.voltairedeux.local","server_name":"srv0"} {"level":"info","ts":1788292665.732655,"logger":"http.auto_https","msg":"skipping automatic certificate management because one or more matching certificates are already loaded","domain":"bazarr.voltaireun.local","server_name":"srv0"} {"level":"info","ts":1788292665.7326572,"logger":"http.auto_https","msg":"skipping automatic certificate management because one or more matching certificates are already loaded","domain":"diun.voltairedeux.local","server_name":"srv0"} {"level":"info","ts":1788292665.7326589,"logger":"http.auto_https","msg":"skipping automatic certificate management because one or more matching certificates are already loaded","domain":"musicbrainz.voltairedeux.local","server_name":"srv0"} {"level":"info","ts":1788292665.7326612,"logger":"http.auto_https","msg":"skipping automatic certificate management because one or more matching certificates are already loaded","domain":"jellyfin.waltdakind.xubi.org","server_name":"srv0"} {"level":"info","ts":1788292665.732665,"logger":"http.auto_https","msg":"skipping automatic certificate management because one or more matching certificates are already loaded","domain":"home.voltairedeux.local","server_name":"srv0"} {"level":"info","ts":1788292665.7326732,"logger":"http.auto_https","msg":"skipping automatic certificate management because one or more matching certificates are already loaded","domain":"prowlarr.waltdakind.xubi.org","server_name":"srv0"} {"level":"info","ts":1788292665.7326765,"logger":"http.auto_https","msg":"skipping automatic certificate management because one or more matching certificates are already loaded","domain":"tvheadend.voltairedeux.local","server_name":"srv0"} {"level":"info","ts":1788292665.7326787,"logger":"http.auto_https","msg":"skipping automatic certificate management because one or more matching certificates are already loaded","domain":"sonarr.voltaireun.local","server_name":"srv0"} {"level":"info","ts":1788292665.7326808,"logger":"http.auto_https","msg":"skipping automatic certificate management because one or more matching certificates are already loaded","domain":"jellyseerr.voltaireun.local","server_name":"srv0"} {"level":"info","ts":1788292665.7326827,"logger":"http.auto_https","msg":"skipping automatic certificate management because one or more matching certificates are already loaded","domain":"192.168.4.21","server_name":"srv0"} {"level":"info","ts":1788292665.7326849,"logger":"http.auto_https","msg":"skipping automatic certificate management because one or more matching certificates are already loaded","domain":"dashboard.voltaireun.local","server_name":"srv0"} {"level":"info","ts":1788292665.732687,"logger":"http.auto_https","msg":"skipping automatic certificate management because one or more matching certificates are already loaded","domain":"tvheadend.voltaireun.local","server_name":"srv0"} {"level":"info","ts":1788292665.7326896,"logger":"http.auto_https","msg":"skipping automatic certificate management because one or more matching certificates are already loaded","domain":"bazarr.waltdakind.xubi.org","server_name":"srv0"} {"level":"info","ts":1788292665.7326913,"logger":"http.auto_https","msg":"enabling automatic HTTP->HTTPS redirects","server_name":"srv0"} {"level":"warn","ts":1788292665.7327092,"logger":"http.auto_https","msg":"server is listening only on the HTTP port, so no automatic HTTPS will be applied to this server","server_name":"srv1","http_port":80} {"level":"info","ts":1788292665.7912242,"logger":"http","msg":"enabling HTTP/3 listener","addr":":443"} {"level":"info","ts":1788292665.793653,"logger":"http.log","msg":"server running","name":"srv0","protocols":["h1","h2","h3"]} {"level":"warn","ts":1788292665.7937615,"logger":"http","msg":"HTTP/2 skipped because it requires TLS","network":"tcp","addr":":80"} {"level":"warn","ts":1788292665.7937646,"logger":"http","msg":"HTTP/3 skipped because it requires TLS","network":"tcp","addr":":80"} {"level":"info","ts":1788292665.7937667,"logger":"http.log","msg":"server running","name":"srv1","protocols":["h1","h2","h3"]} {"level":"warn","ts":1788292665.793785,"logger":"http","msg":"HTTP/2 skipped because it requires TLS","network":"tcp","addr":":8096"} {"level":"warn","ts":1788292665.7937865,"logger":"http","msg":"HTTP/3 skipped because it requires TLS","network":"tcp","addr":":8096"} {"level":"info","ts":1788292665.7937882,"logger":"http.log","msg":"server running","name":"srv2","protocols":["h1","h2","h3"]} {"level":"info","ts":1788292665.8869824,"logger":"pki.ca.local","msg":"root certificate is already trusted by system","path":"storage:pki/authorities/local/root.crt"} {"level":"info","ts":1788292665.8873255,"msg":"serving initial configuration"} {"level":"info","ts":1788292665.9717264,"logger":"tls","msg":"storage cleaning happened too recently; skipping for now","storage":"FileStorage:/data/caddy","instance":"8091df43-ad33-4557-983b-b97fb6b356ec","try_again":1788379065.9717135,"try_again_in":86399.999998599} {"level":"info","ts":1788292666.031316,"logger":"tls","msg":"finished cleaning storage units"}
`

---

## 5. Architectural Recommendations & Maintenance Tips
1. **Auto-Recovery:** If degraded, execute `.\Repair-caddy.ps1` or `.\Repair-MediaStackFleet.ps1 -Service Ingress`.
2. **Backup Strategy:** Included in atomic hot backup snapshot via `.\Backup-MediaStackFleet.ps1`.
3. **Replication Strategy:** Synchronized across Voltaire nodes via `.\Replicate-MediaStackCluster.ps1`.

---
*Generated autonomously by MediaStack Deep Analysis Engine.*
