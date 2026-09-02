# MediaStack SSL/TLS Pathway & HTTPS Viability Audit Report

| Metric | Value |
| :--- | :--- |
| **Timestamp** | 2026-09-01 16:33:12 |
| **Viability Score** | **85%** (VIABLE (B)) |
| **Viable for Serving HTTPS** | **YES (Active & Secure)** |
| **Primary Domain** | $PrimaryDomain |
| **Certificate Valid Until** | 2036-08-29 15:44:08 (3649 days remaining) |
| **Key Strength** | 4096-bit RSA (sha256RSA) |
| **Windows Trust Store** | NOT INSTALLED |
| **Live HTTPS :443 Handshake** | HTTP 302 (99.1 ms) |

### Pathway Mappings Matrix
* **Host Certs Directory**: $(System.Collections.Specialized.OrderedDictionary.Pathways.HostCertDirectory.Path)
* **Caddy Container Cert**: $(System.Collections.Specialized.OrderedDictionary.Pathways.CaddyContainerCert.Path)
* **Caddy Container Key**: $(System.Collections.Specialized.OrderedDictionary.Pathways.CaddyContainerKey.Path)
* **Jellyfin PKCS#12 Bundle**: $(System.Collections.Specialized.OrderedDictionary.Pathways.JellyfinPkcs12Path.Path) (Password: mediastack)
* **Docker Compose Mount**: $(System.Collections.Specialized.OrderedDictionary.Pathways.DockerComposeVolume.Mount)
* **Caddyfile TLS Directives**: $(System.Collections.Specialized.OrderedDictionary.Pathways.CaddyfileTlsSnippet.Snippet)

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
