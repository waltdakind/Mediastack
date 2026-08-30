# MediaStack Service Setup & Configuration Guide

This document provides step-by-step setup directions for all MediaStack services using their standardized default ports.

---

## 1. Service Port & Configuration Reference

### Prowlarr (Unified Indexer Manager)
* **Default Port:** `9696`
* **Direct Web UI:** `http://<SERVER_IP>:9696`
* **Internal Docker URL:** `http://prowlarr:9696`
* **Setup Instructions:**
  1. Navigate to **Settings → Apps**.
  2. Add Sonarr (`http://sonarr:8989`) and Radarr (`http://radarr:7878`).
  3. Enter the respective API keys harvested from Sonarr and Radarr.
  4. Add indexers in **Indexers → Add**; Prowlarr will automatically sync them to Sonarr and Radarr.

### Sonarr (TV Show Automation)
* **Default Port:** `8989`
* **Direct Web UI:** `http://<SERVER_IP>:8989`
* **Internal Docker URL:** `http://sonarr:8989`
* **Setup Instructions:**
  1. Navigate to **Settings → Download Clients → Add → Transmission**.
  2. Set Host to `transmission` and Port to `9091`.
  3. Navigate to **Media Management → Root Folders** and add `/data/TV` (or `/data/Videos`).
  4. Ensure Prowlarr is connected under **Settings → Indexers**.

### Radarr (Movie Automation)
* **Default Port:** `7878`
* **Direct Web UI:** `http://<SERVER_IP>:7878`
* **Internal Docker URL:** `http://radarr:7878`
* **Setup Instructions:**
  1. Navigate to **Settings → Download Clients → Add → Transmission**.
  2. Set Host to `transmission` and Port to `9091`.
  3. Navigate to **Media Management → Root Folders** and add `/data/Movies` (or `/data/Videos`).
  4. Ensure Prowlarr is connected under **Settings → Indexers**.

### Bazarr (Subtitle Manager)
* **Default Port:** `6767`
* **Direct Web UI:** `http://<SERVER_IP>:6767`
* **Internal Docker URL:** `http://bazarr:6767`
* **Setup Instructions:**
  1. Navigate to **Settings → Sonarr**:
     * Address: `sonarr`, Port: `8989`, API Key: `<Sonarr_API_Key>`.
  2. Navigate to **Settings → Radarr**:
     * Address: `radarr`, Port: `7878`, API Key: `<Radarr_API_Key>`.
  3. Add Subtitle Providers (OpenSubtitles, Subscene, etc.) and configure language profiles.

### Jellyfin (Media Server)
* **Default Port:** `8096` (HTTP), `8920` (HTTPS)
* **Direct Web UI:** `http://<SERVER_IP>:8096`
* **Internal Docker URL:** `http://jellyfin:8096`
* **Setup Instructions:**
  1. Complete initial admin account creation.
  2. Add Media Libraries:
     * **Music:** `/data/music` (or `/music`)
     * **Movies:** `/data/movies` (or `/data/Videos`)
     * **TV Shows:** `/data/tv` (or `/data/Videos`)
  3. Enable MusicBrainz and AudioDB metadata plugins.

### Jellyseerr (Media Request Portal)
* **Default Port:** `5055`
* **Direct Web UI:** `http://<SERVER_IP>:5055`
* **Internal Docker URL:** `http://jellyseerr:5055`
* **Setup Instructions:**
  1. Sign in with Jellyfin administrator credentials.
  2. Set Jellyfin Server URL to `http://jellyfin:8096`.
  3. Under **Settings → Services**:
     * Add Sonarr Server: `http://sonarr:8989` with Sonarr API Key.
     * Add Radarr Server: `http://radarr:7878` with Radarr API Key.

### Transmission (BitTorrent Client)
* **Default Ports:** `9091` (Web UI & RPC), `51413` (Peer TCP/UDP)
* **Direct Web UI:** `http://<SERVER_IP>:9091/transmission/web/`
* **Internal Docker URL:** `http://transmission:9091`
* **Setup Instructions:**
  1. Verify download folder is mapped to `/data` or `/downloads`.
  2. Ensure peer port `51413` is forwarded on your router if external seeding is enabled.

### TVHeadend (Live TV & DVR)
* **Default Ports:** `9981` (Web UI), `9982` (HTSP Protocol)
* **Direct Web UI:** `http://<SERVER_IP>:9981`
* **Internal Docker URL:** `http://tvheadend:9981`
* **Setup Instructions:**
  1. Configure DVB/ATSC tuner hardware or IPTV automatic network.
  2. Set EPG grabber and map channels.
  3. Set recording directory to `/data/TVHeadend`.

### Syncthing (Continuous File & Theme Synchronization)
* **Default Ports:** `8384` (Web GUI), `22000` (Sync Protocol), `21027` (Local Discovery UDP)
* **Direct Web UI:** `http://<SERVER_IP>:8384`
* **Setup Instructions:**
  1. Open Syncthing Web GUI on Primary node (`192.168.4.21:8384`) and Secondary node (`192.168.4.30:8384`).
  2. Exchange Device IDs between nodes.
  3. Share `jellyfin-theme` and configuration folders across the network.

### MusicBrainz Local Mirror (Metadata API)
* **Default Port:** `5000` (Primary Node `192.168.4.21:5000`), `5001` (Secondary Node `127.0.0.1:5001`)
* **WebService v2 Endpoint:** `http://<SERVER_IP>:<PORT>/ws/2/`
* **Picard Configuration:** In Picard options, set **Server Host** to `<SERVER_IP>` and **Server Port** to `5000` (or `5001`).

---

## 2. Docker Compose Port Publishing Standards

In `docker-compose.yml` and `docker-compose.x64.yml`, all services must declare their explicit default host-to-container port bindings:

```yaml
services:
  caddy:
    ports:
      - "80:80"          # HTTP Gateway
      - "443:443"        # HTTPS Gateway
      - "8096:8096"      # Direct Jellyfin Proxy
      - "8080:8080"      # Direct DB Proxy

  jellyfin:
    ports:
      - "8096:8096"      # Jellyfin Streaming

  sonarr:
    ports:
      - "8989:8989"      # Sonarr TV

  radarr:
    ports:
      - "7878:7878"      # Radarr Movies

  prowlarr:
    ports:
      - "9696:9696"      # Prowlarr Indexers

  bazarr:
    ports:
      - "6767:6767"      # Bazarr Subtitles

  jellyseerr:
    ports:
      - "5055:5055"      # Jellyseerr Requests

  transmission:
    ports:
      - "9091:9091"      # Transmission Web
      - "51413:51413"    # Torrent TCP
      - "51413:51413/udp"# Torrent UDP

  tvheadend:
    ports:
      - "9981:9981"      # TVHeadend Web
      - "9982:9982"      # TVHeadend HTSP

  syncthing:
    ports:
      - "8384:8384"      # Syncthing GUI
      - "22000:22000"    # Syncthing TCP
      - "22000:22000/udp"# Syncthing UDP
      - "21027:21027/udp"# Discovery Broadcast

  mediastack-db:
    ports:
      - "8080:8080"      # SQLite Explorer

  api-gateway:
    ports:
      - "3000:3000"      # REST API Gateway
```
