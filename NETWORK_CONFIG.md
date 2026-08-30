# MediaStack Dual-Node Network Configuration & Cluster Topology

This guide details all internal network ports, Docker bridge communications, reverse proxy mappings, dual-node synchronization pipelines, and self-healing sentinels across **VoltaireUn** (Main 24/7 Server) and **VoltaireDeux** (AI Acceleration & Push Node).

---

## 1. Dual-Node Cluster Roles & Topology

| Node Identity | Primary LAN IP | Operational Role | Key Workloads |
| :--- | :--- | :--- | :--- |
| **VoltaireUn** | `192.168.4.21` (`voltaireun.local`) | **Main 24/7 Server** | Primary media streaming, 24/7 Servarr automation, MusicBrainz mirror (`:5000`), daily update poller & sync. |
| **VoltaireDeux** | `192.168.4.30` (`voltairedeux.local`) | **AI Acceleration & Push Node** | AI model acceleration, development workstation, update staging & GitHub push publisher. |

---

## 2. Complete Canonical Port Directory

| Container / Service | Default Port | Internal Docker DNS | Host Binding | Function |
| :--- | :--- | :--- | :--- | :--- |
| **Caddy** | `80` / `443` | `http://caddy:80` | `80:80`, `443:443` | HTTP & HTTPS Gateway |
| **Jellyfin** | `8096` / `8920` | `http://jellyfin:8096` | `8096:8096` | Media Streaming Server |
| **Sonarr** | `8989` | `http://sonarr:8989` | `8989:8989` | TV Management & API |
| **Radarr** | `7878` | `http://radarr:7878` | `7878:7878` | Movie Management & API |
| **Prowlarr** | `9696` | `http://prowlarr:9696` | `9696:9696` | Indexer Aggregator & API |
| **Bazarr** | `6767` | `http://bazarr:6767` | `6767:6767` | Subtitle Automation |
| **Jellyseerr** | `5055` | `http://jellyseerr:5055` | `5055:5055` | User Requests & API |
| **Transmission** | `9091` / `51413` | `http://transmission:9091`| `9091:9091`, `51413:51413` | Torrent Client & Peer Port |
| **TVHeadend** | `9981` / `9982` | `http://tvheadend:9981` | `9981:9981`, `9982:9982` | Live TV Streamer & HTSP |
| **Syncthing** | `8384` / `22000` | `http://syncthing:8384` | `8384:8384`, `22000:22000` | Sync GUI & Transfer Protocol |
| **API Gateway** | `3000` | `http://api-gateway:3000`| `3000:3000` | Express REST Proxy |
| **Homepage** | `3000` | `http://homepage:3000` | Routed via Caddy / `3000` | Central Dashboard UI |
| **Mediastack-DB** | `8080` | `http://mediastack-db:8080`| `8080:8080` | SQLite Web GUI |
| **MusicBrainz** | `5000` / `5001` | `http://musicbrainz:5000`| `5000:5000` (Un) / `5001:5000` (Deux) | MusicBrainz Mirror API |
| **HDHomeRun Tuner**| `80` | `http://192.168.4.45:80` | Hardware Physical IP | Network TV Tuner Lineup |

---

## 3. Subdomain Routing via Caddy (Port 80 / 443)

Traffic reaching Caddy is dynamically routed to upstream containers based on the `Host` header:
- `http://jellyfin.voltaireun.local` / `http://jellyfin.voltairedeux.local` → `jellyfin:8096`
- `http://sonarr.voltaireun.local` / `http://sonarr.voltairedeux.local` → `sonarr:8989`
- `http://radarr.voltaireun.local` / `http://radarr.voltairedeux.local` → `radarr:7878`
- `http://prowlarr.voltaireun.local` / `http://prowlarr.voltairedeux.local` → `prowlarr:9696`
- `http://bazarr.voltaireun.local` / `http://bazarr.voltairedeux.local` → `bazarr:6767`
- `http://jellyseerr.voltaireun.local` / `http://jellyseerr.voltairedeux.local` → `jellyseerr:5055`
- `http://transmission.voltaireun.local` / `http://transmission.voltairedeux.local` → `transmission:9091`
- `http://tvheadend.voltaireun.local` / `http://tvheadend.voltairedeux.local` → `tvheadend:9981`
- `http://api.voltaireun.local` / `http://api.voltairedeux.local` → `api-gateway:3000`
- `http://db.voltaireun.local` / `http://db.voltairedeux.local` → `mediastack-db:8080`
- `http://musicbrainz.voltaireun.local` / `http://musicbrainz.voltairedeux.local` → `192.168.4.21:5000` / `192.168.4.30:5001`
- `http://hdhomerun.voltaireun.local` / `http://hdhomerun.voltairedeux.local` → `192.168.4.45:80`

---

## 4. Cluster Synchronization & Lifecycle Pipeline

```
  VOLTAIREDEUX (AI Node)                           VOLTAIREUN (Main 24/7 Server)
  ======================                           =============================
  [Publish-VoltaireDeuxUpdates.ps1]                [Invoke-VoltaireUnDailyPoller.ps1]
  1. Pre-push DB Snapshot (SHA-256)                1. Polls GitHub & OneDrive Daily
  2. Test Ports & Proxies                          2. Mandatory Pre-Pull DB Snapshot
  3. Git Commit + Push to GitHub                   3. Pulls Git Commits & Merges Configs
  4. Emit cluster_update_manifest.json             4. Synchronizes Databases safely
  5. Sync shared OneDrive folder   ──────────────> 5. Tests & Auto-Heals Ports/Proxies
                                                   6. Writes Executive Audit Report
```

### Lifecycle Execution Commands:
- **Publish Updates from VoltaireDeux:** `.\Publish-VoltaireDeuxUpdates.ps1 -Message "Update description"`
- **Execute Daily Poller on VoltaireUn:** `.\Invoke-VoltaireUnDailyPoller.ps1 -Once`
- **Register Daily Schedule on VoltaireUn:** `.\Install-VoltaireUnDailySchedule.ps1 -DailyTime "04:00"`
- **Run Proxy/Port Self-Healing Diagnostic:** `.\Test-MediaStackProxyAndPorts.ps1 -AutoRepair`
- **Clean Start Stack:** `.\Invoke-MediaStackCleanStart.ps1` (or `.\start.ps1 -CleanStart`)
- **Clean Shutdown Stack:** `.\Invoke-MediaStackCleanShutdown.ps1` (or `.\start.ps1 -CleanShutdown`)
