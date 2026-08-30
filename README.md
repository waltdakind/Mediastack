# MediaStack

A fully self-hosted media server running on Docker Compose.

## Services

| Service      | URL (local)                    | Purpose                         |
|--------------|--------------------------------|---------------------------------|
| Jellyfin     | http://HOST:8096               | Media server & streaming        |
| Radarr       | http://HOST:7878               | Movie automation                |
| Sonarr       | http://HOST:8989               | TV show automation              |
| Prowlarr     | http://HOST:9696               | Indexer manager (*arr native)   |
| Transmission | http://HOST:9091               | BitTorrent client               |
| TVHeadend    | http://HOST:9981               | TV streaming, EPG, recording    |
|       | http://HOST:8866               | DVR server                      |
| Syncthing    | http://HOST:8384               | File synchronisation            |
| Caddy        | https://CADDY_DOMAIN           | Reverse proxy + auto HTTPS      |
| Watchtower   | (background)                   | Automatic container updates     |

## Quick Start

```bash
# 1. Clone / copy this stack
cd /opt/mediastack

# 2. Configure environment
cp .env.example .env
nano .env   # fill in PUID, PGID, TZ, paths, credentials, domain

# 3. Create media directories (adjust for your storage layout)
mkdir -p /mnt/media/{movies,tv,music,photos,recordings,downloads}
mkdir -p /opt/mediastack/config/{jellyfin,radarr,sonarr,prowlarr,transmission,tvheadend,,syncthing}

# 4. Launch
docker compose up -d

# 5. Check health
docker compose ps
```

## Directory Layout

```
/opt/mediastack/
+-- config/
¦   +-- jellyfin/
¦   +-- radarr/
¦   +-- sonarr/
¦   +-- prowlarr/
¦   +-- transmission/
¦   +-- tvheadend/
¦   +-- /
¦   +-- syncthing/
+-- docker-compose.yml
+-- Caddyfile
+-- .env              ? secrets (not in git)
+-- .env.example      ? template (safe to commit)

/mnt/media/
+-- movies/
+-- tv/
+-- music/
+-- photos/
+-- recordings/       ? TVHeadend +  live recordings
+-- downloads/        ? Transmission working directory
    +-- watch/        ? Transmission watch folder
```

## Connecting Prowlarr ? Radarr/Sonarr

1. Open Prowlarr ? Settings ? Apps ? Add Application
2. Select **Radarr** (or **Sonarr**)
3. Prowlarr will auto-push all your indexers — no manual Torznab URL copying.

## Networking Notes

- **IPv6** is explicitly disabled on all containers via `sysctls`.
- All services share an isolated **`medianet`** bridge (172.28.0.0/16).
- **TVHeadend** and **** use `network_mode: host` for tuner hardware discovery.
- **Caddy** exposes ports 80/443 — ensure your router forwards both to this host.

## Updating

```bash
docker compose pull
docker compose up -d
```

Watchtower also handles this automatically on the schedule in your `.env`.

## Hardware Transcoding (Intel iGPU)

Ensure your host user (PUID) is in the `render` and `video` groups:

```bash
sudo usermod -aG render,video $(whoami)
```

Then verify: `ls -l /dev/dri` — the `renderD128` device should be accessible.
