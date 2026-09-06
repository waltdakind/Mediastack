# MediaStack Library Architecture & Path Configuration

This document outlines the recommended filesystem architecture and container volume mappings for MediaStack services (Jellyfin, Radarr, Sonarr, Transmission, and Seerr).

> [!NOTE]
> **Repository Decoupling**: To keep the Git repository lean and prevent tracking large binary files, media libraries are stored in directories external to the repository (e.g. `C:\Media` or external drive root) and mounted into Docker containers via environment variables.

---

## 1. Environment Variable Configuration

Media paths are controlled dynamically via the root `.env` file:

```dotenv
# Root storage path for media libraries
MEDIA_DIR=C:\Media

# Dedicated root paths for external libraries
MUSIC_ROOT=C:\Media\Music
TV_ROOT=C:\Media\TV
MOVIES_ROOT=C:\Media\Movies
VIDEOS_ROOT=C:\Media\Videos
DOWNLOADS_ROOT=C:\Media\Downloads
```

---

## 2. Recommended Directory Structure

```text
C:\Media\
├── Movies/
│   └── Sample Movie (2024)/
│       └── Sample Movie (2024) [1080p].mkv
├── Shows/
│   └── Sample Show/
│       └── Season 01/
│           └── Sample Show - S01E01.mkv
├── TV/ (Alternative / Synced TV Root)
├── Music/
│   └── Artist/
│       └── [Year] Album/
│           └── 01 - Track.flac
├── Videos/ (Home Videos & Recordings)
└── Downloads/
    ├── complete/
    └── incomplete/
```

---

## 3. Container Volume Mappings

| Service | Host Path Example | Container Mount | Description |
| :--- | :--- | :--- | :--- |
| **Jellyfin** | `${MEDIA_DIR}` | `/data` | Top-level media root (MBLink support) |
| **Jellyfin** | `${MUSIC_ROOT}` | `/data/music` & `/music` | High-performance audio streaming |
| **Radarr** | `${MOVIES_ROOT}` | `/movies` | Automated movie management |
| **Sonarr** | `${TV_ROOT}` | `/tv` | Automated episodic series management |
| **Transmission** | `${DOWNLOADS_ROOT}` | `/downloads` | Active torrent ingestion pipeline |

---

## 4. Network SMB Sharing & Peer Mounting

Network shares allow multi-node synchronization and remote client playback:

| Share Name | Default Relative Path | Example UNC Path |
| :--- | :--- | :--- |
| `MediaStack-Movies` | `Movies` | `\\<Node-IP>\MediaStack-Movies` |
| `MediaStack-Shows` | `Shows` | `\\<Node-IP>\MediaStack-Shows` |
| `MediaStack-TV` | `TV` | `\\<Node-IP>\MediaStack-TV` |
| `MediaStack-Music` | `Music` (or `$MUSIC_ROOT`) | `\\<Node-IP>\MediaStack-Music` |
| `MediaStack-Videos` | `Videos` | `\\<Node-IP>\MediaStack-Videos` |
| `MediaStack-Downloads` | `downloads` | `\\<Node-IP>\MediaStack-Downloads` |

### Audit & Provisioning Scripts
To audit and re-align network shares on a node:
```powershell
.\repair-files\Fix-MediaStackNetworkShares.ps1 -CheckOnly
```

To automatically provision missing shares (run as Administrator or with `-Elevate`):
```powershell
.\repair-files\Fix-MediaStackNetworkShares.ps1 -Elevate
```

To mount network shares across peer cluster nodes:
```powershell
.\Mount-MediaStackNetworkShares.ps1 -PeerIP "192.168.4.21"
```
