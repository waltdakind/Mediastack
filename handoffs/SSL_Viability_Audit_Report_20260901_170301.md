# MediaStack SSL/TLS Pathway & HTTPS Viability Audit Report

| Metric | Value |
| :--- | :--- |
| **Timestamp** | 2026-09-01 17:03:01 |
| **Viability Score** | **100%** (OPTIMAL (A+)) |
| **Viable for Serving HTTPS** | **YES (Active & Secure)** |
| **Primary Domain** | $PrimaryDomain |
| **Certificate Valid Until** | 2036-08-29 15:44:08 (3649 days remaining) |
| **Key Strength** | 4096-bit RSA (sha256RSA) |
| **Windows Trust Store** | INSTALLED & TRUSTED |
| **Live HTTPS :443 Handshake** | HTTP 302 (109.3 ms) |

### Pathway Mappings Matrix
* **Host Certs Directory**: $hostPath
* **Caddy Container Cert**: $caddyCrt
* **Caddy Container Key**: $caddyKey
* **Jellyfin PKCS#12 Bundle**: $jellyPfx (Password: `mediastack`)
* **Docker Compose Mount**: $dockVol
* **Caddyfile TLS Directives**: $cadSnip

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
