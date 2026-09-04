# MediaStack Complete Services Overview & Default Port Specifications

This guide provides explicit directions for the default network ports, internal container ports, host port bindings, and Docker DNS communication across the entire MediaStack fleet.

---

## 1. Primary Service & Default Port Matrix

All services in the MediaStack ecosystem are pre-configured to use their official, industry-standard default ports. Whether communicating through Docker's internal bridge network or accessing services directly via the host LAN IP, refer to the table below:

| Service | Role / Category | Default Container Port | Host Port Mapping | Protocol | Direct LAN Access URL | Reverse Proxy Ingress (`.local`) |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Caddy** | L7 Reverse Proxy & Gateway | `80` (HTTP), `443` (HTTPS) | `80:80`, `443:443` | TCP / UDP | `http://<HOST_IP>:80` | `http://voltairedeux.local` |
| **Jellyfin** | Media & Music Streaming Server | `8096` (HTTP), `8920` (HTTPS) | `8096:8096` | TCP | `http://<HOST_IP>:8096` | `http://jellyfin.voltairedeux.local` |
| **Sonarr** | TV Series Management & Automation | `8989` | `8989:8989` | TCP | `http://<HOST_IP>:8989` | `http://sonarr.voltairedeux.local` |
| **Radarr** | Movie Management & Automation | `7878` | `7878:7878` | TCP | `http://<HOST_IP>:7878` | `http://radarr.voltairedeux.local` |
| **Prowlarr** | Unified Usenet & Torrent Indexer | `9696` | `9696:9696` | TCP | `http://<HOST_IP>:9696` | `http://prowlarr.voltairedeux.local` |
| **Bazarr** | Subtitle Automation (Sonarr/Radarr) | `6767` | `6767:6767` | TCP | `http://<HOST_IP>:6767` | `http://bazarr.voltairedeux.local` |
| **Jellyseerr** | Media Request & Discovery Portal | `5055` | `5055:5055` | TCP | `http://<HOST_IP>:5055` | `http://jellyseerr.voltairedeux.local` |
| **Transmission** | BitTorrent Client & RPC Daemon | `9091` (Web), `51413` (Peer) | `9091:9091`, `51413:51413` | TCP / UDP | `http://<HOST_IP>:9091/transmission/web/` | `http://transmission.voltairedeux.local` |
| **TVHeadend** | Live TV Streamer & DVR Backend | `9981` (Web), `9982` (HTSP) | `9981:9981`, `9982:9982` | TCP | `http://<HOST_IP>:9981` | `http://tvheadend.voltairedeux.local` |
| **Syncthing** | Continuous Theme & Config Sync | `8384` (GUI), `22000` (Sync) | `8384:8384`, `22000:22000` | TCP / UDP | `http://<HOST_IP>:8384` | `http://syncthing.voltairedeux.local` |
| **API Gateway** | Fleet Management REST API | `3000` | `3000:3000` | TCP | `http://<HOST_IP>:3000` | `http://api.voltairedeux.local` |
| **JellyWatch Requests** | Media Discovery & Requests Server | `3000` / `80` | `3000:3000`, `80/443` | TCP | `http://<HOST_IP>:80/requests` | `https://requests.voltaireun.local` |
| **JellyWatch Issues** | Playback & Defect Triage Server | `3000` / `80` | `3000:3000`, `80/443` | TCP | `http://<HOST_IP>:80/issues` | `https://issues.voltaireun.local` |
| **Homepage** | Unified Media Dashboard | `3000` (Internal) | `3000` or Caddy Proxy | TCP | `http://<HOST_IP>:80` | `http://homepage.voltairedeux.local` |
| **Mediastack-DB** | SQLite Web Database Explorer | `8080` | `8080:8080` | TCP | `http://<HOST_IP>:8080` | `http://db.voltairedeux.local` |
| **Portainer** | Container & Cluster Management Web UI | `9000` (HTTP), `9443` (HTTPS) | `9000:9000`, `9443:9443` | TCP | `http://<HOST_IP>:9000` | `http://portainer.voltairedeux.local` |
| **MusicBrainz** | Local Music Metadata Mirror API | `5000` (Primary), `5001` (Sec) | `5001:5000` / `5000:5000` | TCP | `http://<HOST_IP>:5001` | `http://musicbrainz.voltairedeux.local` |
| **HDHomeRun** | Physical Hardware Tuner (LAN) | `80` (Discovery / Lineup) | `80` (Direct Hardware IP) | TCP | `http://192.168.4.45:80` | `http://hdhomerun.voltairedeux.local` |

---

## 2. Explicit Container Port Configuration Rules

### Rule 1: Service-to-Service Internal Communication
When configuring connections inside Docker (e.g. Sonarr connecting to Prowlarr, or Bazarr connecting to Radarr), **always use the container name with its default internal port**:
* **Sonarr to Prowlarr:** `http://prowlarr:9696`
* **Radarr to Prowlarr:** `http://prowlarr:9696`
* **Sonarr / Radarr to Transmission:** `http://transmission:9091`
* **Bazarr to Sonarr:** `http://sonarr:8989`
* **Bazarr to Radarr:** `http://radarr:7878`
* **Jellyseerr to Jellyfin:** `http://jellyfin:8096`
* **Jellyseerr to Sonarr:** `http://sonarr:8989`
* **Jellyseerr to Radarr:** `http://radarr:7878`
* **Caddy Upstreams:**
  * `reverse_proxy sonarr:8989`
  * `reverse_proxy radarr:7878`
  * `reverse_proxy prowlarr:9696`
  * `reverse_proxy bazarr:6767`
  * `reverse_proxy jellyseerr:5055`
  * `reverse_proxy jellyfin:8096`
  * `reverse_proxy transmission:9091`
  * `reverse_proxy tvheadend:9981`
  * `reverse_proxy mediastack-db:8080`
  * `reverse_proxy api-gateway:3000`
  * `reverse_proxy portainer:9000`


### Rule 2: Host Port Publishing (`docker-compose.yml`)
When publishing container ports to the host operating system, always map the **host port directly to the identical container default port** in `"HOST_PORT:CONTAINER_PORT"` format:

```yaml
services:
  sonarr:
    ports:
      - "8989:8989"      # Sonarr Web UI & REST API v3

  radarr:
    ports:
      - "7878:7878"      # Radarr Web UI & REST API v3

  prowlarr:
    ports:
      - "9696:9696"      # Prowlarr Web UI & REST API v1

  bazarr:
    ports:
      - "6767:6767"      # Bazarr Web UI & REST API

  jellyseerr:
    ports:
      - "5055:5055"      # Jellyseerr Web UI & REST API v1

  jellyfin:
    ports:
      - "8096:8096"      # Jellyfin HTTP & Web Client

  transmission:
    ports:
      - "9091:9091"      # Transmission Web UI & RPC
      - "51413:51413"    # Torrent Peer Listening Port (TCP)
      - "51413:51413/udp"# Torrent Peer Listening Port (UDP)

  tvheadend:
    ports:
      - "9981:9981"      # TVHeadend Web UI / HTTP Stream
      - "9982:9982"      # TVHeadend HTSP Streaming Protocol

  mediastack-db:
    ports:
      - "8080:8080"      # SQLite-Web GUI

  api-gateway:
    ports:
      - "3000:3000"      # MediaStack Express API Gateway
```

---

## 3. Storage & Configuration Path Standards

All application configurations and persistent SQLite databases are consolidated under the standardized root directory (`C:\MediastackConfig` or `./config`):

```
C:\MediastackConfig\ (or ./config/)
├── sonarr\config.xml          # Sonarr API keys & settings
├── radarr\config.xml          # Radarr API keys & settings
├── prowlarr\config.xml        # Prowlarr indexer configurations
├── bazarr\config\config.yaml  # Bazarr credentials & subtitle languages
├── jellyseerr\settings.json   # Jellyseerr users & server bindings
├── jellyfin\data\data\        # Jellyfin library SQLite database (jellyfin.db)
├── transmission\settings.json # Transmission download limits & watch dirs
├── tvheadend\                 # TVHeadend channels & muxes
├── db-backup\                 # Primary SQLite archive (mediastack_backup.db)
└── homepage\                  # Dashboard widgets & layout configurations
```

---

## 4. Multi-Node Deployment Specifics

* **Node 1 - Primary (OrdinateurdeVol - `192.168.4.21`):**
  * Hosts primary Jellyfin (`:8096`), core Servarr suite, and primary MusicBrainz server (`:5000`).
* **Node 2 - Secondary / Satellite (VoltaireDeux - `192.168.4.30`):**
  * Hosts full failover fleet, Caddy gateway (`:80`), secondary MusicBrainz mirror (`:5001`), and Syncthing sync client (`:8384`).
