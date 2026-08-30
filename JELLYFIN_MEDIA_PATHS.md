# Jellyfin Media Path Configuration

## Primary Source (Local VoltaireDeux)
- **Container Path:** `/media/music`
- **Windows Local Path:** `C:\Users\Public\Music`
- **Network Share:** `//VoltaireDeux/Users/Public/Music`
- **Status:** Currently mapped and active

## Fallback Source (Remote OrdinateurdeVolt)
- **Container Path:** `/media/music_remote`
- **Windows Remote Path:** `//OrdinateurdeVolt/Users/waltda/Music`
- **Status:** Available but commented out (requires SMB mount)

## Setup Instructions

### If serving from VoltaireDeux (local - current default):
- No additional setup needed; the local path `C:\Users\Public\Music` is mounted directly
- Jellyfin accesses music at `/media/music` inside the container

### If switching to OrdinateurdeVolt (remote):

**Option A: Mount as SMB share on Windows**
1. Open File Explorer → "Map network drive"
2. Folder: `\\OrdinateurdeVolt\Users\waltda\Music`
3. Assign to drive letter (e.g., `Z:`)
4. In docker-compose.yml, uncomment the `media_music_remote` volume
5. Update the path if using a different drive letter
6. Run: `docker compose up -d jellyfin`

**Option B: Use SMB mount inside container**
Replace the commented volume with:
```yaml
- type: bind
  source: //OrdinateurdeVolt/Users/waltda/Music
  target: /media/music
  read_only: true
```
(Note: This requires the SMB share to be mounted on the Docker host first)

## Syncthing Sync
If you enable Syncthing to sync music between machines:
1. Configure Syncthing to watch `C:\Users\Public\Music` (VoltaireDeux)
2. Share the folder with OrdinateurdeVolt
3. Music will automatically sync and be available on both machines
