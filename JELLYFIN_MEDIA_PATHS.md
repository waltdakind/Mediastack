# Jellyfin & Servarr Media Library Path Configuration

All media libraries are structured as direct subfolders under `C:\Users\waltd\OneDrive\Mediastack\`.

---

## Media Library Mappings

| Library Type | Host Path (Local Node) | Container Path | Network UNC Share | Status / Available Titles |
| :--- | :--- | :--- | :--- | :--- |
| **Movies** | `C:\Users\waltd\OneDrive\Mediastack\Movies` | `/media/movies` (Jellyfin)<br>`/movies` (Radarr) | `\\<Node>\MediaStack-Movies` | - *Marcel the Shell with Shoes On (2022)* (4K HDR)<br>- *Supergirl (2026)* (4K DV/HDR) |
| **Shows / TV** | `C:\Users\waltd\OneDrive\Mediastack\Shows`<br>`C:\Users\waltd\OneDrive\Mediastack\TV` | `/media/shows` (Jellyfin)<br>`/tv` (Sonarr) | `\\<Node>\MediaStack-Shows`<br>`\\<Node>\MediaStack-TV` | - *Lanterns (Season 01)* |
| **Music** | `C:\Users\waltd\OneDrive\Mediastack\Music` | `/media/music` (Jellyfin) | `\\<Node>\MediaStack-Music` | Local & Syncthing synced |
| **Personal Videos** | `C:\Users\waltd\OneDrive\Mediastack\Videos` | `/media/videos` (Jellyfin) | `\\<Node>\MediaStack-Videos` | - *French Midterm: A Day in France*<br>- *Special Education Presentation*<br>- *Zoom recordings* |
| **Downloads** | `C:\Users\waltd\OneDrive\Mediastack\downloads` | `/downloads` (Transmission / Servarr) | `\\<Node>\MediaStack-Downloads` | Active download pipeline |

---

## Peer Reciprocal SMB Mounting

To mount shares from the peer machine (e.g., `192.168.4.21` or `192.168.4.30`):
```powershell
.\Mount-MediaStackNetworkShares.ps1 -PeerIP "192.168.4.21"
```

To re-align or audit local SMB shares:
```powershell
.\Fix-MediaStackNetworkShares.ps1 -CheckOnly
```

