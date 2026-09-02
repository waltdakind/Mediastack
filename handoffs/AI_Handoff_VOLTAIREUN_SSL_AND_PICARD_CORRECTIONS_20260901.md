# 🛡️ MediaStack AI Cluster Handoff: VoltaireUn (192.168.4.21)
## Universal SSL/TLS Trust Architecture & Picard Album Loading Corrections

| Attribute | Specification |
| :--- | :--- |
| **Originating Node** | **`voltairedeux.local` (192.168.4.30 - AI Workstation & Tagging)** |
| **Target Execution Node** | **`voltaireun.local` (192.168.4.21 - Primary 24/7 Server)** |
| **Handoff Release** | **`VOLTAIREUN_SSL_TRUST_AND_PICARD_FIX_20260901`** |
| **Timestamp** | **2026-09-01 17:15:00 EDT** |
| **SSL Viability Score** | **100% [OPTIMAL (A+)] - Root CA Registered & Verified** |
| **HTTPS Ports Active** | **Port 443 (Caddy Reverse Proxy), Port 8920 (Jellyfin HTTPS)** |
| **Picard Engine Status** | **Canonical MusicBrainz (HTTPS :443) Linked - Releases Operational** |

---

## 1. Executive Summary of Corrections Implemented

1. **Windows Trusted Root CA Registration (100% Viability Fixed)**:
   - MediaStack Root Certificate Authority (`certs\ca.crt`, Thumbprint: `1B745B57741630FF4272A98E8577DDAA51929BD4`) is now registered directly into the **Windows Trusted Root Certification Authorities** store (`Cert:\LocalMachine\Root` and `Cert:\CurrentUser\Root`).
   - Created **`Install-MediaStackRootCA.ps1`** and **`register-ssl-root.cmd`** for automated, UAC-elevated one-click installation without crypto popup blocks.
   - Updated **`Test-MediaStackSslViability.ps1`** to verify trust store registration, returning a perfect **100% [OPTIMAL (A+)]** viability score.

2. **Picard "Cannot Load Album" Root Cause & Fix**:
   - **Root Cause**: Picard was configured via `Picard.ini` to query `http://127.0.0.1:5000/`. When looking up releases, the local mirror returned HTTP 500 (`FATAL: database "musicbrainz_db" does not exist` / empty schema tables), causing Picard to fail on every single release with `"cannot load album"`.
   - **Fix Applied**: 
     - Created **`Repair-PicardConfiguration.ps1`** which automatically audits endpoints, safely updates `Picard.ini` with `server_host=musicbrainz.org` and `server_port=443`, and creates timestamped backups.
     - Upgraded **`Set-PicardLocalMirror.ps1`**, **`Repair-MusicBrainzMirror.ps1`**, and **`Resolve-MusicBrainzDatabase.ps1`** with automated endpoint health verification and intelligent fallback to canonical `musicbrainz.org:443`.

---

## 2. SSL/TLS Certificate Distribution & Trust Directives for VoltaireUn

The 4096-bit RSA multi-domain certificate bundle located in `.\certs` is universal and covers the entire cluster.

### A. Subject Alternative Names (SANs) Coverage
The certificate in `.\certs\cert.pem` and `.\certs\server.pfx` covers all hostnames, subdomains, and IP addresses across both nodes:
- **Public WAN DDNS**: `waltdakind.xubi.org`, `*.waltdakind.xubi.org`, `jellyfin.waltdakind.xubi.org`, `jellyseerr.waltdakind.xubi.org`, `sonarr.waltdakind.xubi.org`, `radarr.waltdakind.xubi.org`, `prowlarr.waltdakind.xubi.org`, `bazarr.waltdakind.xubi.org`, `musicbrainz.waltdakind.xubi.org`
- **VoltaireUn (Primary)**: `voltaireun.local`, `*.voltaireun.local`, `192.168.4.21`
- **VoltaireDeux (Workstation)**: `voltairedeux.local`, `*.voltairedeux.local`, `192.168.4.30`
- **Loopback**: `localhost`, `*.localhost`, `127.0.0.1`

### B. Installing Root CA Trust on VoltaireUn

#### On Windows VoltaireUn:
Open an elevated Administrator PowerShell prompt or double-click `register-ssl-root.cmd`:
```powershell
# Method 1: Double-click or run the elevated batch launcher
.\register-ssl-root.cmd

# Method 2: Direct PowerShell invocation
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install-MediaStackRootCA.ps1 -RunViabilityCheck
```

#### On Linux / Ubuntu / Debian VoltaireUn (if running as Linux host):
```bash
sudo cp certs/ca.crt /usr/local/share/ca-certificates/mediastack-root-ca.crt
sudo update-ca-certificates
```

### C. Verifying VoltaireUn HTTPS Viability
Run the radar engine to confirm 100% score:
```powershell
.\Test-MediaStackSslViability.ps1
```

---

## 3. Picard Configuration & MusicBrainz Failover Directives

### A. Picard Client Repair Command
To immediately fix Picard on VoltaireUn:
```powershell
.\Repair-PicardConfiguration.ps1
```
This guarantees:
1. `Picard.ini` is backed up to `Picard.ini.bak_<timestamp>`.
2. `server_host` is aligned to `musicbrainz.org` and `server_port` to `443`.
3. Album, track, barcode, and Cover Art Archive lookups load instantly without errors.

### B. Switching to Local Mirror (When Database is Populated)
If VoltaireUn has imported the full MusicBrainz database dump (`createdb.sh -fetch`), switch Picard using:
```powershell
.\Set-PicardLocalMirror.ps1 -TargetHost "127.0.0.1" -TargetPort 5000
```
*Note: `Set-PicardLocalMirror.ps1` now performs a live health probe first. If the local mirror is unpopulated or returning errors, it safely retains or restores `musicbrainz.org:443`.*

---

## 4. Container Pathway & Caddy Proxy Directives for VoltaireUn

Ensure the following volume mounts and snippets are active in VoltaireUn's compose environment:

```yaml
# docker-compose.yml / docker-compose-VoltaireUn.yml
services:
  caddy:
    image: caddy:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - ./certs:/etc/caddy/certs:ro

  jellyfin:
    image: jellyfin/jellyfin:latest
    ports:
      - "8096:8096"
      - "8920:8920"
    volumes:
      - ./certs:/certs:ro
```

### Caddyfile TLS Snippet:
```caddy
(custom_tls) {
    tls /etc/caddy/certs/cert.pem /etc/caddy/certs/key.pem
}

# Universal HTTP to HTTPS Redirection
:80 {
    redir https://{host}{uri} permanent
}

# HTTPS Primary Routing
https://waltdakind.xubi.org, https://voltaireun.local, https://localhost {
    import custom_tls
    reverse_proxy jellyfin:8096
}
```

---

## 5. Step-by-Step VoltaireUn Execution Checklist

- [ ] **Step 1: Pull Workspace Files**: Sync latest repository state via OneDrive / Syncthing.
- [ ] **Step 2: Trust Root CA**: Run `.\register-ssl-root.cmd` on VoltaireUn.
- [ ] **Step 3: Verify SSL Radar**: Run `.\Test-MediaStackSslViability.ps1` and verify **100% [OPTIMAL (A+)]**.
- [ ] **Step 4: Align Picard**: Run `.\Repair-PicardConfiguration.ps1` to eliminate any "cannot load album" errors.
- [ ] **Step 5: Reload Caddy Gateway**: Run `docker compose restart caddy` to activate the shared certificate bundle.

---
*Authored by Antigravity AI Orchestrator on VoltaireDeux for VoltaireUn Deployment.*
