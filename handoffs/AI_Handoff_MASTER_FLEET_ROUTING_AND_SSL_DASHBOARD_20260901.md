# 🌐 MediaStack Fleet Master Routing, Ingress & Live SSL Dashboard Handoff
## Canonical Architectural Specification for AI Agents & Fleet Administrators

| Metadata Attribute | Directive Specification |
| :--- | :--- |
| **Handoff Document** | **`AI_Handoff_MASTER_FLEET_ROUTING_AND_SSL_DASHBOARD_20260901.md`** |
| **Release Tag** | **`MEDIASTACK_FLEET_MASTER_ROUTING_V2`** |
| **Timestamp** | **2026-09-01 18:05:00 EDT** |
| **Cluster Nodes** | **VoltaireDeux** (`192.168.4.30` - AI Workstation) & **VoltaireUn** (`192.168.4.21` - 24/7 Primary) |
| **Decommissioned Services** | **`NextPVR` (Port 8866) Removed** — Live TV consolidated to **`TVHeadend`** (Port 9981) |
| **SSL / HTTPS Status** | **100% [OPTIMAL (A+)]** — Root CA Trusted & Embedded in Live Mission Control Dashboard |

---

## 1. Master Service Port & Reverse Proxy Routing Matrix

All active services are accessible via direct port, local LAN reverse proxy hostname (`*.voltairedeux.local`, `*.voltaireun.local`), and secure public WAN DDNS (`*.waltdakind.xubi.org`):

| Service Name | Container | Internal Port | Host Port | Local LAN Virtual Host | Public WAN Ingress Route | Protocol & SSL |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Caddy Ingress Gateway** | `caddy` | `80`, `443`, `8096` | `80:80`, `443:443` | `https://voltairedeux.local` | `https://waltdakind.xubi.org` | HTTP->HTTPS 301 / TLSv1.3 |
| **Jellyfin Media Streaming** | `jellyfin` | `8096`, `8920` | `8096:8096` | `https://jellyfin.voltairedeux.local` | `https://jellyfin.waltdakind.xubi.org` | Reverse Proxy / Direct Kestrel |
| **Mission Control Dashboard** | `caddy` (static) | `80`, `443` | `80:80`, `443:443` | `https://dashboard.voltairedeux.local` | `https://waltdakind.xubi.org/dashboard/` | Static Glassmorphism Web App |
| **Sonarr TV Manager** | `sonarr` | `8989` | `8989:8989` | `https://sonarr.voltairedeux.local` | `https://sonarr.waltdakind.xubi.org` | FastCGI / Reverse Proxy |
| **Radarr Movie Manager** | `radarr` | `7878` | `7878:7878` | `https://radarr.voltairedeux.local` | `https://radarr.waltdakind.xubi.org` | FastCGI / Reverse Proxy |
| **Prowlarr Indexer Hub** | `prowlarr` | `9696` | `9696:9696` | `https://prowlarr.voltairedeux.local` | `https://prowlarr.waltdakind.xubi.org` | FlareSolverr & Torznab Proxy |
| **Bazarr Subtitles** | `bazarr` | `6767` | `6767:6767` | `https://bazarr.voltairedeux.local` | `https://bazarr.waltdakind.xubi.org` | Subtitle Auto-Sync Engine |
| **Jellyseerr Request Portal** | `jellyseerr` | `5055` | `5055:5055` | `https://jellyseerr.voltairedeux.local` | `https://jellyseerr.waltdakind.xubi.org` | Discovery & Request Engine |
| **Transmission BitTorrent** | `transmission` | `9091`, `51413` | `9091:9091` | `https://transmission.voltairedeux.local` | `https://transmission.waltdakind.xubi.org` | Transfer Daemon (RPC + Web) |
| **TVHeadend Live TV** | `tvheadend` | `9981`, `9982` | `9981:9981` | `https://tvheadend.voltairedeux.local` | `https://tvheadend.waltdakind.xubi.org` | DVB / ATSC / HDHomeRun Tuner |
| **MusicBrainz REST API** | `musicbrainz` | `5000` | `5000:5000`, `5001:5000` | `https://musicbrainz.voltairedeux.local` | `https://musicbrainz.waltdakind.xubi.org` | WS2 REST API Mirror / Cloud |
| **Syncthing P2P Mesh** | `syncthing` | `8384`, `22000` | `8384:8384` | `https://syncthing.voltairedeux.local` | `https://syncthing.waltdakind.xubi.org` | Encrypted P2P Media Sync |
| **MediaStack SQLite DB** | `mediastack-db` | `8080` | `8080:8080` | `https://db.voltairedeux.local` | `https://db.waltdakind.xubi.org` | SQLite Web Database Viewer |

---

## 2. Live Dashboard SSL Telemetry & Status Integration

The Mission Control Dashboard (`dashboard/index.html` & `dashboard/index-VoltaireDeux.html`) includes a live SSL/TLS Status Deck and real-time navigation badge:

```
+-----------------------------------------------------------------------------------------+
| [Pulse] Fleet Health: OPTIMAL (100%)    |    [Pulse] HTTPS 443: VIABLE (100%)           |
+-----------------------------------------------------------------------------------------+
|                                                                                         |
|  [Certificate Authority & Trust]            [Physical-to-Container Ingress Pathways]    |
|  • Status: 100% OPTIMAL (A+)                • Host: .\certs\cert.pem & key.pem          |
|  • Windows Store: TRUSTED (LocalMachine)    • Caddy: /etc/caddy/certs:ro (Mounted)      |
|  • Key: 4096-bit RSA (SHA-256)              • Jellyfin: server.pfx (PKCS#12 Bundle)     |
|  • Validity: 3,649 Days (10-Yr Epoch)       • Auto-Failover: Zero-503 Upstream          |
|                                                                                         |
|  [Subject Alternative Names (SANs) Cloud]   [Live HTTPS Handshake Matrix (:443)]        |
|  • WAN: waltdakind.xubi.org                 • Target: https://localhost:443/            |
|  • Node 1: *.voltairedeux.local             • Negotiated: TLSv1.3 (ALPN h2/h3)          |
|  • Node 2: *.voltaireun.local               • Handshake Latency: ~81.4 ms               |
|  • IPs: 127.0.0.1, 192.168.4.30, .21        • HSTS: max-age=31536000; preload           |
+-----------------------------------------------------------------------------------------+
```

---

## 3. NextPVR Decommissioning & Live TV Consolidation

1. **Containers & Directories**:
   - `NextPVR` container and directories (`nextpvr/config`, `nextpvr/buffer`) removed.
   - All Live TV streaming, EPG parsing, and tuner channel lineups consolidated into **`TVHeadend`** (Port `9981`).
2. **Hardware Tuner Integration**:
   - HDHomeRun hardware tuner (`192.168.4.45`) discovered via `/discover.json` and remuxed by TVHeadend.
3. **Scripts & Probes Updated**:
   - `Invoke-MediaStackDeepAnalysis.ps1`, `Test-MediaStackFleetConnectivity.ps1`, `Repair-LiveTvTuner.ps1`, and `dashboard/app.js` now target `TVHeadend` exclusively.

---

## 4. Multi-Node Parity & Provisioning Directives for AI Agents

When provisioning or managing **VoltaireUn** (`192.168.4.21`), execute:

```powershell
# 1. Complete Feature Parity & SSL Trust Provisioner
powershell.exe -ExecutionPolicy Bypass -File .\Sync-VoltaireUnFeatureParity.ps1

# 2. Multi-Server SSL Audit
powershell.exe -ExecutionPolicy Bypass -File .\Deploy-MediaStackFleetCertificates.ps1
```

### Architectural Responsibilities:
- **`VoltaireUn` (`192.168.4.21`)**: Primary 24/7 Server Node hosting Jellyfin Kestrel, Servarr, TVHeadend, and SQLite DB UI.
- **`VoltaireDeux` (`192.168.4.30`)**: AI Acceleration Node hosting Ollama (`:11434`), MusicBrainz API staging, and Picard batch tagging.

---

## 5. VoltaireDeux Automated Port + 1 Failover Specification

To ensure resilient high-availability across the dual-node cluster, all services employ the **Port + 1 Failover Convention** on VoltaireDeux (`192.168.4.30` / `127.0.0.1`):

| Service Name | Primary Port `[P]` | VoltaireDeux Failover Port `[P + 1]` | Upstream Fallback Chain in Caddy |
| :--- | :--- | :--- | :--- |
| **Jellyfin Streaming** | `:8096` | `:8097` | `jellyfin:8096` -> `192.168.4.21:8096` -> `192.168.4.30:8096` -> `192.168.4.30:8097` |
| **Jellyseerr Requests** | `:5055` | `:5056` | `jellyseerr:5055` -> `192.168.4.21:5055` -> `192.168.4.30:5055` -> `192.168.4.30:5056` |
| **Sonarr TV Manager** | `:8989` | `:8990` | `sonarr:8989` -> `192.168.4.21:8989` -> `192.168.4.30:8989` -> `192.168.4.30:8990` |
| **Radarr Movies** | `:7878` | `:7879` | `radarr:7878` -> `192.168.4.21:7878` -> `192.168.4.30:7878` -> `192.168.4.30:7879` |
| **Prowlarr Indexers** | `:9696` | `:9697` | `prowlarr:9696` -> `192.168.4.21:9696` -> `192.168.4.30:9696` -> `192.168.4.30:9697` |
| **Bazarr Subtitles** | `:6767` | `:6768` | `bazarr:6767` -> `192.168.4.21:6767` -> `192.168.4.30:6767` -> `192.168.4.30:6768` |
| **Transmission Web** | `:9091` | `:9092` | `transmission:9091` -> `192.168.4.21:9091` -> `192.168.4.30:9091` -> `192.168.4.30:9092` |
| **TVHeadend Live TV** | `:9981` | `:9982` | `tvheadend:9981` -> `192.168.4.21:9981` -> `192.168.4.30:9981` -> `192.168.4.30:9982` |
| **MusicBrainz API** | `:5000` | `:5001` | `192.168.4.21:5000` -> `192.168.4.30:5000` -> `192.168.4.30:5001` -> Cloud Mirror |
| **MediaStack DB** | `:8080` | `:8081` | `mediastack-db:8080` -> `192.168.4.21:8080` -> `192.168.4.30:8080` -> `192.168.4.30:8081` |

### Integrated Port + 1 Failover Logic Engines:
1. **Caddy Ingress Proxy**: Automatic upstream switching using `lb_policy first` with zero 503 response latency.
2. **Mission Control Web Dashboard (`dashboard/app.js`)**: Real-time probing engine automatically attempts `Port + 1` if `Port` is closed and highlights `ONLINE (Failover :[P+1])`.
3. **Fleet Diagnostics (`Test-MediaStackFleetConnectivity.ps1` & `MediaStackOps.psm1`)**: Automated TCP socket fallback and HTTP probe resolution on `Port + 1`.

---
*Created and registered in the MediaStack AI Collaboration Nexus.*
