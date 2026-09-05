# MediaStack SSL/TLS Pathway & HTTPS Viability Audit Report

| Metric | Value |
| :--- | :--- |
| **Timestamp** | 2026-09-05 11:20:09 |
| **Viability Score** | **100%** (OPTIMAL (A+)) |
| **Viable for Serving HTTPS** | **YES (Active & Secure)** |
| **Primary Domain** | `waltdakind.xubi.org` |
| **Certificate Valid Until** | 2036-08-29 15:44:08 (3646 days remaining) |
| **Key Strength** | 4096-bit RSA (sha256RSA) |
| **Windows Trust Store** | INSTALLED & TRUSTED |
| **Live HTTPS :443 Handshake** | HTTP 302 (126.3 ms) |

### Pathway Mappings Matrix
* **Host Certs Directory**: `C:\Users\waltd\OneDrive\Mediastack\certs`
* **Caddy Container Cert**: `/etc/caddy/certs/cert.pem`
* **Caddy Container Key**: `/etc/caddy/certs/key.pem`
* **Jellyfin PKCS#12 Bundle**: `C:\Users\waltd\OneDrive\Mediastack\certs\server.pfx` (Password: `mediastack`)
* **Docker Compose Mount**: `./certs:/etc/caddy/certs:ro`
* **Caddyfile TLS Directives**: `(custom_tls) { tls /etc/caddy/certs/cert.pem /etc/caddy/certs/key.pem }`

### Subject Alternative Names (SANs)
* `waltdakind.xubi.org`
* `*.waltdakind.xubi.org`
* `jellyfin.waltdakind.xubi.org`
* `jellyseerr.waltdakind.xubi.org`
* `sonarr.waltdakind.xubi.org`
* `radarr.waltdakind.xubi.org`
* `prowlarr.waltdakind.xubi.org`
* `bazarr.waltdakind.xubi.org`
* `musicbrainz.waltdakind.xubi.org`
* `voltaireun.local`
* `*.voltaireun.local`
* `voltairedeux.local`
* `*.voltairedeux.local`
* `localhost`
* `*.localhost`
* `127.0.0.1`
* `192.168.4.30`
* `192.168.4.21`
* `192.168.4.1`
