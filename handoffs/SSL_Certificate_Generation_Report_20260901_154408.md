# MediaStack SSL/TLS Certificate Provisioning Report

| Metric | Value |
| :--- | :--- |
| **Generation Timestamp** | 2026-09-01 15:44:02 |
| **Primary Domain** | waltdakind.xubi.org |
| **Validity Period** | 3650 Days (10 Years) |
| **Key Algorithm** | RSA 4096-bit (SHA-256) |
| **Certificate Path (PEM)** | \$srvCrtPath\ |
| **Private Key Path (PEM)** | \$srvKeyPath\ |
| **PKCS#12 Bundle (PFX)** | \$srvPfxPath\ (Password: \mediastack\) |
| **Root CA Certificate** | \$caCrtPath\ |
| **Status** | **ACTIVE & VERIFIED (Valid Across WAN, LAN & Localhost)** |

### Subject Alternative Names (SANs) Covered
* **WAN / External DDNS**: waltdakind.xubi.org, *.waltdakind.xubi.org, jellyfin.waltdakind.xubi.org
* **Local LAN Nodes**: oltaireun.local, *.voltaireun.local, oltairedeux.local, *.voltairedeux.local
* **Loopback & Host IPs**: localhost, 127.0.0.1, 192.168.4.30, 192.168.4.21, 192.168.4.1

### Usage in MediaStack Components
1. **Caddy Reverse Proxy Gateway**: Configured via /etc/caddy/certs/cert.pem and /etc/caddy/certs/key.pem.
2. **Jellyfin Native HTTPS**: Load server.pfx with password mediastack in Jellyfin Dashboard > Networking.
3. **Browser & WAN Security**: Validated TLS encryption serving WAN & LAN traffic with full wildcard coverage.
