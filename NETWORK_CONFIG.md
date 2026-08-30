# MediaStack Network Configuration & Default Port Directory

This guide details all internal network ports, Docker bridge communications, reverse proxy mappings, and router port forwarding rules for the MediaStack architecture.

---

## 1. Complete Default Port Directory

Every container in the stack operates on its standardized default port.

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
| **MusicBrainz** | `5000` / `5001` | `http://musicbrainz:5000`| `5001:5000` / `5000:5000` | MusicBrainz Mirror API |
| **HDHomeRun Tuner**| `80` | `http://192.168.4.45:80` | Hardware Physical IP | Network TV Tuner Lineup |

---

## 2. Internal Network Topology

### Node Architecture
* **Primary Node (`OrdinateurdeVol`):** `192.168.4.21`
  * Active media libraries, primary MusicBrainz mirror (`:5000`), primary Servarr automation suite.
* **Secondary Node (`VoltaireDeux`):** `192.168.4.30`
  * Gateway L7 Caddy proxy (`:80`), failover Servarr containers, secondary MusicBrainz mirror (`:5001`).

### Subdomain Routing via Caddy (Port 80)
Traffic reaching Caddy is routed dynamically to upstream container default ports based on the `Host` header:
* `http://jellyfin.voltairedeux.local` → `jellyfin:8096`
* `http://sonarr.voltairedeux.local` → `sonarr:8989`
* `http://radarr.voltairedeux.local` → `radarr:7878`
* `http://prowlarr.voltairedeux.local` → `prowlarr:9696`
* `http://bazarr.voltairedeux.local` → `bazarr:6767`
* `http://jellyseerr.voltairedeux.local` → `jellyseerr:5055`
* `http://transmission.voltairedeux.local` → `transmission:9091`
* `http://tvheadend.voltairedeux.local` → `tvheadend:9981`
* `http://homepage.voltairedeux.local` → `homepage:3000`
* `http://api.voltairedeux.local` → `api-gateway:3000`
* `http://db.voltairedeux.local` → `mediastack-db:8080`
* `http://musicbrainz.voltairedeux.local` → `musicbrainz-docker-musicbrainz-1:5000` / `192.168.4.21:5000`
* `http://hdhomerun.voltairedeux.local` → `192.168.4.45:80`

---

## 3. Router Port Forwarding & NAT Checklist

For external WAN connectivity via Dynamic DNS (`waltdakind.xubi.org` -> `73.178.82.157`), configure the following forwarding rules on the local router (`192.168.4.1`):

| External WAN Port | Protocol | Target LAN IP | Target Internal Port | Service Description |
| :--- | :--- | :--- | :--- | :--- |
| **80** | TCP | `192.168.4.21` (or `.30`) | **80** | Caddy HTTP Gateway & ACME Challenge |
| **443** | TCP / UDP | `192.168.4.21` (or `.30`) | **443** | Caddy HTTPS (Auto TLS / HTTP/3) |
| **8096** | TCP | `192.168.4.21` (or `.30`) | **8096** | Jellyfin Direct Client Streaming |
| **51413** | TCP & UDP | `192.168.4.21` (or `.30`) | **51413** | Transmission BitTorrent Peer Traffic |
| **22000** | TCP & UDP | `192.168.4.21` (or `.30`) | **22000** | Syncthing Cross-Node Peer Sync |
