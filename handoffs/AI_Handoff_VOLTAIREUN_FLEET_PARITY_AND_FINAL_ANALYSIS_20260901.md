# 🛡️ MediaStack Master AI Architecture Handoff & Fleet Parity Blueprint
## VoltaireDeux (192.168.4.30) ➔ VoltaireUn (192.168.4.21) Master Synchronization

| Directive Attribute | Specification |
| :--- | :--- |
| **Originating Node** | **`voltairedeux.local` (192.168.4.30 - AI Acceleration & Workstation)** |
| **Target Execution Node** | **`voltaireun.local` (192.168.4.21 - Primary 24/7 Server & Ingress)** |
| **Release Identifier** | **`MEDIASTACK_FLEET_PARITY_AND_FINAL_DEEP_ANALYSIS_20260901`** |
| **Timestamp** | **2026-09-01 19:20:00 EDT** |
| **SSL Viability Score** | **100% [OPTIMAL (A+)] on VoltaireDeux / Staged for VoltaireUn** |
| **Ingress Protocols Active** | **Port 80 (HTTP -> HTTPS 301 Redirect), Port 443 (Custom TLS Ingress)** |
| **Universal Path Ingress** | **Active (`/sonarr/`, `/radarr/`, `/jellyseerr/`, `/transmission/`, etc.)** |
| **Port + 1 Failover** | **Active (VoltaireDeux High-Availability Automatic Fallback)** |

---

## 1. Executive Deep Analysis & Health Telemetry

A comprehensive multi-dimensional analysis was executed across the MediaStack fleet (`Invoke-MediaStackDeepAnalysis.ps1`):

### A. Host Hardware & Kernel Performance
- **RAM Allocation**: 14.2 GB / 15.6 GB utilized (91%).
- **System Storage (C:)**: **30.21 GB Free** (Exceeds the 15 GB minimum health threshold).
- **TCP Network Stack**: Windows Kernel TCP AutoTuning = `Normal`, Congestion Provider = `CUBIC`, ECN = `Enabled`.
- **Secrets Vault**: All 13 service API tokens and passwords securely vaulted in `config\secrets\secrets.json`.

### B. Container & Service Liveness Matrix
| Service | Internal Port | Host Port | Status | Latency / Health | Operational Notes |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Caddy Gateway** | 80, 443, 8096 | `80:80`, `443:443` | **UP** | 3 ms | Custom TLS & Universal HTTP->HTTPS 301 Redirection |
| **Jellyfin Server** | 8096, 8920 | `8096:8096` | **UP** | 33.8 ms | Kestrel Media Engine, Direct & Proxy Ingress Active |
| **Sonarr TV** | 8989 | `8989:8989` | **UP** | 13.7 ms | Automated TV series management & calendar sync |
| **Radarr Movies** | 7878 | `7878:7878` | **UP** | 86.8 ms | Automated movie indexing & root folder scanning |
| **Prowlarr Indexers**| 9696 | `9696:9696` | **UP** | 173.7 ms | Syncs FlareSolverr & Torznab indexers to Servarr |
| **Bazarr Subtitles** | 6767 | `6767:6767` | **UP** | 445.9 ms | Multilingual subtitle auto-downloader |
| **Jellyseerr** | 5055 | `5055:5055` | **UP** | 414.4 ms | User media request & discovery portal |
| **Transmission** | 9091 | `9091:9091` | **UP** | 37.3 ms | RPC BitTorrent download engine |
| **TVHeadend** | 9981, 9982 | `9981:9981` | **UP** | 57.7 ms | IPTV / DVB Tuner & Live Stream Manager |
| **SQLite Web DB** | 8080 | `8080:8080` | **UP** | 351.8 ms | Web-based database management & schema viewer |
| **Syncthing Mesh** | 8384 | `8384:8384` | **UP** | 13.9 ms | Real-time P2P folder synchronization |
| **MusicBrainz** | 5000 | `5000:5000` | **STANDBY** | - | Bootstrap schema; Picard failover routed to cloud |

---

## 2. Key Architecture Issues Analyzed & Resolved

### Issue 1: Picard "Cannot Load Album"
* **Root Cause**: `Picard.ini` pointed to `127.0.0.1:5000`. The unpopulated local mirror returned HTTP 500 (`"database \"musicbrainz_db\" does not exist"`), failing all lookups.
* **Resolution**: Created `Repair-PicardConfiguration.ps1` which points Picard to `musicbrainz.org:443` (HTTPS) and updated helper scripts (`Set-PicardLocalMirror.ps1`, `Repair-MusicBrainzMirror.ps1`) to automatically probe endpoints and safely fall back to the cloud API.

### Issue 2: Windows Untrusted Root CA (85% Viability Score)
* **Root Cause**: The 4096-bit MediaStack Root CA (`ca.crt`) was not registered in the Windows Trusted Root Certification Authorities store on all nodes.
* **Resolution**: Created `Install-MediaStackRootCA.ps1`, `Install-VoltaireUnRootCA.ps1`, and elevated `.cmd` launchers (`register-ssl-root.cmd`, `Install-VoltaireUnRootCA.cmd`) that import `ca.crt` to `Cert:\LocalMachine\Root` and `Cert:\CurrentUser\Root`, elevating the HTTPS Viability Score to **100% [OPTIMAL (A+)]**.

### Issue 3: Local Network HTTPS Routing & Port Failovers
* **Root Cause**: Local clients typing `https://192.168.4.21/sonarr` were previously caught in default Jellyfin routing; while direct subdomains like `https://sonarr.voltairedeux.local` failed without local hosts resolution.
* **Resolution**:
  1. Configured Caddy with **Universal Path-Based Ingress** (`/sonarr*`, `/radarr*`, `/prowlarr*`, `/bazarr*`, `/jellyseerr*`, `/transmission*`, `/tvheadend*`, `/db*`, `/dashboard*`) so all services are directly reachable over HTTPS without needing DNS setups.
  2. Implemented **Automated Port + 1 Failover on VoltaireDeux**: If primary port `P` on VoltaireUn (`192.168.4.21:[P]`) goes down, Caddy instantly routes to `192.168.4.30:[P]` and `192.168.4.30:[P+1]`.
  3. Created `update-hosts.cmd` and `Update-MediaStackHostsFile.ps1` to register all `.voltaireun.local` and `.voltairedeux.local` domain mappings in Windows `hosts`.

---

## 3. VoltaireUn Complete Feature Parity Engine

We have authored a dedicated, all-in-one parity and provisioning engine for VoltaireUn:

### Primary Parity Files:
1. **[Sync-VoltaireUnFeatureParity.ps1](file:///c:/Users/waltd/OneDrive/Mediastack/Sync-VoltaireUnFeatureParity.ps1)**
2. **[sync-voltaireun-parity.cmd](file:///c:/Users/waltd/OneDrive/Mediastack/sync-voltaireun-parity.cmd)**
3. **[update-hosts.cmd](file:///c:/Users/waltd/OneDrive/Mediastack/update-hosts.cmd)**

### What `Sync-VoltaireUnFeatureParity.ps1` Executes on VoltaireUn:
1. **Windows Root CA Trust**: Registers `ca.crt` in `Cert:\LocalMachine\Root` to achieve 100% SSL Viability.
2. **Picard Client Repair**: Updates `Picard.ini` to `musicbrainz.org:443` to ensure albums load instantly.
3. **Blueprint & Secret Sync**: Syncs `Caddyfile`, `docker-compose.yml`, and `secrets.json` to `C:\MediastackConfig`.
4. **Local DNS Hosts Sync**: Synchronizes all `.local` virtual hosts in Windows `hosts` file and flushes DNS.
5. **Caddy Gateway Restart**: Applies custom TLS certificates, universal path ingress, and Port + 1 failovers.
6. **24/7 Always-On Safeguards**: Sets Windows power schemes to prevent sleep/hibernation and enforces `restart: unless-stopped` on Docker containers.
7. **Fleet Verification**: Probes all 11 core service ports and runs the SSL Viability Radar.

---

## 4. Execution Directives for VoltaireUn Administrator

To bring VoltaireUn to 100% full feature parity with VoltaireDeux:

```cmd
:: Option 1: Double-click or run the elevated batch provisioner (Recommended)
.\sync-voltaireun-parity.cmd

:: Option 2: Run via PowerShell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Sync-VoltaireUnFeatureParity.ps1
```

---

## 5. Verification Checklist

- [ ] **1. Execute Parity Script**: Run `.\sync-voltaireun-parity.cmd` on VoltaireUn.
- [ ] **2. Verify SSL Viability**: Confirm output shows `100% [OPTIMAL (A+)]`.
- [ ] **3. Verify Picard**: Open MusicBrainz Picard on VoltaireUn and test loading an album.
- [ ] **4. Verify Fleet Dashboard**: Check `https://waltdakind.xubi.org` and `https://voltaireun.local` in browser.
- [ ] **5. Run Multi-Server Sweep**: Run `.\Deploy-MediaStackFleetCertificates.ps1` to confirm green status across both nodes.

---
*Authored by Antigravity AI Orchestrator on VoltaireDeux for VoltaireUn Node.*
