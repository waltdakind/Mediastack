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
| **Container Started** | 2026-09-04T00:35:59.940967527Z |
| **L7 Response Code** | HTTP 301 |
| **TTFB Latency** | 6 ms |
| **Vault Secrets Status**| SYSTEM MANAGED |
| **Error Lines Detected**| 1 |
| **Audit Timestamp** | 2026-09-03 20:39:20 |

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
{"level":"info","ts":1788482163.6133468,"logger":"http.auto_https","msg":"skipping automatic certificate management because one or more matching certificates are already loaded","domain":"sonarr.waltdakind.xubi.org","server_name":"srv0"} {"level":"info","ts":1788482163.6133907,"logger":"http.auto_https","msg":"skipping automatic certificate management because one or more matching certificates are already loaded","domain":"radarr.waltdakind.xubi.org","server_name":"srv0"} {"level":"info","ts":1788482163.6134067,"logger":"http.auto_https","msg":"skipping automatic certificate management because one or more matching certificates are already loaded","domain":"radarr.voltairedeux.local","server_name":"srv0"} {"level":"info","ts":1788482163.6134224,"logger":"http.auto_https","msg":"skipping automatic certificate management because one or more matching certificates are already loaded","domain":"192.168.4.30","server_name":"srv0"} {"level":"info","ts":1788482163.6134393,"logger":"http.auto_https","msg":"skipping automatic certificate management because one or more matching certificates are already loaded","domain":"voltairedeux.local","server_name":"srv0"} {"level":"info","ts":1788482163.6134799,"logger":"http.auto_https","msg":"skipping automatic certificate management because one or more matching certificates are already loaded","domain":"noc.voltaireun.local","server_name":"srv0"} {"level":"info","ts":1788482163.6135197,"logger":"http.auto_https","msg":"skipping automatic certificate management because one or more matching certificates are already loaded","domain":"homepage.waltdakind.xubi.org","server_name":"srv0"} {"level":"info","ts":1788482163.6135352,"logger":"http.auto_https","msg":"skipping automatic certificate management because one or more matching certificates are already loaded","domain":"requests.voltaireun.local","server_name":"srv0"} {"level":"info","ts":1788482163.6135623,"logger":"http.auto_https","msg":"skipping automatic certificate management because one or more matching certificates are already loaded","domain":"prowlarr.voltairedeux.local","server_name":"srv0"} {"level":"info","ts":1788482163.6135788,"logger":"http.auto_https","msg":"skipping automatic certificate management because one or more matching certificates are already loaded","domain":"bazarr.voltairedeux.local","server_name":"srv0"} {"level":"info","ts":1788482163.6135821,"logger":"http.auto_https","msg":"skipping automatic certificate management because one or more matching certificates are already loaded","domain":"db.voltaireun.local","server_name":"srv0"} {"level":"info","ts":1788482163.6135855,"logger":"http.auto_https","msg":"skipping automatic certificate management because one or more matching certificates are already loaded","domain":"bazarr.waltdakind.xubi.org","server_name":"srv0"} {"level":"info","ts":1788482163.6135886,"logger":"http.auto_https","msg":"skipping automatic certificate management because one or more matching certificates are already loaded","domain":"bazarr.voltaireun.local","server_name":"srv0"} {"level":"info","ts":1788482163.613592,"logger":"http.auto_https","msg":"skipping automatic certificate management because one or more matching certificates are already loaded","domain":"localhost","server_name":"srv0"} {"level":"info","ts":1788482163.6135945,"logger":"http.auto_https","msg":"skipping automatic certificate management because one or more matching certificates are already loaded","domain":"requests.voltairedeux.local","server_name":"srv0"} {"level":"info","ts":1788482163.6135979,"logger":"http.auto_https","msg":"skipping automatic certificate management because one or more matching certificates are already loaded","domain":"transmission.voltaireun.local","server_name":"srv0"} {"level":"info","ts":1788482163.6136007,"logger":"http.auto_https","msg":"skipping automatic certificate management because one or more matching certificates are already loaded","domain":"transmission.voltairedeux.local","server_name":"srv0"} {"level":"info","ts":1788482163.6136038,"logger":"http.auto_https","msg":"skipping automatic certificate management because one or more matching certificates are already loaded","domain":"musicbrainz.voltairedeux.local","server_name":"srv0"} {"level":"info","ts":1788482163.6136074,"logger":"http.auto_https","msg":"skipping automatic certificate management because one or more matching certificates are already loaded","domain":"jellyseerr.voltaireun.local","server_name":"srv0"} {"level":"info","ts":1788482163.6136105,"logger":"http.auto_https","msg":"skipping automatic certificate management because one or more matching certificates are already loaded","domain":"voltaireun.local","server_name":"srv0"} {"level":"info","ts":1788482163.6136136,"logger":"http.auto_https","msg":"skipping automatic certificate management because one or more matching certificates are already loaded","domain":"issues.waltdakind.xubi.org","server_name":"srv0"} {"level":"info","ts":1788482163.613622,"logger":"http.auto_https","msg":"skipping automatic certificate management because one or more matching certificates are already loaded","domain":"jellyseerr.waltdakind.xubi.org","server_name":"srv0"} {"level":"info","ts":1788482163.6136734,"logger":"http.auto_https","msg":"skipping automatic certificate management because one or more matching certificates are already loaded","domain":"homepage.voltaireun.local","server_name":"srv0"} {"level":"info","ts":1788482163.6136837,"logger":"http.auto_https","msg":"skipping automatic certificate management because one or more matching certificates are already loaded","domain":"requests.waltdakind.xubi.org","server_name":"srv0"} {"level":"info","ts":1788482163.613686,"logger":"http.auto_https","msg":"enabling automatic HTTP->HTTPS redirects","server_name":"srv0"} {"level":"warn","ts":1788482163.6138284,"logger":"http.auto_https","msg":"server is listening only on the HTTP port, so no automatic HTTPS will be applied to this server","server_name":"srv1","http_port":80} {"level":"info","ts":1788482163.658941,"logger":"http","msg":"enabling HTTP/3 listener","addr":":443"} {"level":"info","ts":1788482163.6595645,"msg":"failed to sufficiently increase receive buffer size (was: 208 kiB, wanted: 7168 kiB, got: 416 kiB). See https://github.com/quic-go/quic-go/wiki/UDP-Buffer-Sizes for details."} {"level":"info","ts":1788482163.6597185,"logger":"http.log","msg":"server running","name":"srv0","protocols":["h1","h2","h3"]} {"level":"warn","ts":1788482163.6597943,"logger":"http","msg":"HTTP/2 skipped because it requires TLS","network":"tcp","addr":":80"} {"level":"warn","ts":1788482163.6597977,"logger":"http","msg":"HTTP/3 skipped because it requires TLS","network":"tcp","addr":":80"} {"level":"info","ts":1788482163.6597998,"logger":"http.log","msg":"server running","name":"srv1","protocols":["h1","h2","h3"]} {"level":"warn","ts":1788482163.659828,"logger":"http","msg":"HTTP/2 skipped because it requires TLS","network":"tcp","addr":":8096"} {"level":"warn","ts":1788482163.6598306,"logger":"http","msg":"HTTP/3 skipped because it requires TLS","network":"tcp","addr":":8096"} {"level":"info","ts":1788482163.6598327,"logger":"http.log","msg":"server running","name":"srv2","protocols":["h1","h2","h3"]} {"level":"info","ts":1788482163.659838,"logger":"http","msg":"enabling automatic TLS certificate management","domains":["mediaserver.local"]} {"level":"info","ts":1788482163.9152899,"logger":"tls","msg":"storage cleaning happened too recently; skipping for now","storage":"FileStorage:/data/caddy","instance":"8091df43-ad33-4557-983b-b97fb6b356ec","try_again":1788568563.9152846,"try_again_in":86399.999999208} {"level":"info","ts":1788482163.9206033,"logger":"tls","msg":"finished cleaning storage units"} {"level":"info","ts":1788482164.887177,"logger":"pki.ca.local","msg":"root certificate is already trusted by system","path":"storage:pki/authorities/local/root.crt"} {"level":"info","ts":1788482164.887313,"msg":"serving initial configuration"}
`

---

## 5. Architectural Recommendations & Maintenance Tips
1. **Auto-Recovery:** If degraded, execute `.\Repair-caddy.ps1` or `.\Repair-MediaStackFleet.ps1 -Service Ingress`.
2. **Backup Strategy:** Included in atomic hot backup snapshot via `.\Backup-MediaStackFleet.ps1`.
3. **Replication Strategy:** Synchronized across Voltaire nodes via `.\Replicate-MediaStackCluster.ps1`.

---
*Generated autonomously by MediaStack Deep Analysis Engine.*
