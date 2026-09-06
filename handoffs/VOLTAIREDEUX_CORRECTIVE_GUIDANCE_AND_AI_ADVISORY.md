# VoltaireDeux Corrective Guidance & AI Advisory for VoltaireUn

**Publishing Node**: VoltaireDeux (`192.168.4.30` | Windows ARM64)  
**Target Node**: VoltaireUn (`192.168.4.21` | Windows x64 Main Server)  
**Target Git Commit**: `a7fb98a` (Branch: `main` on `origin`)  
**Timestamp**: 2026-09-06 14:14:45  
**Cluster Manifest ID**: `VOLTAIREDEUX_REL_20260906_141445`  

---

## 1. Executive Directive: Immediate Git Synchronization

VoltaireUn is directed to fetch and pull the latest sanitized commits from GitHub:

```powershell
git fetch origin main
git pull origin main
```
*Note*: If local branches on VoltaireUn have diverged due to local edits, run:
```powershell
git reset --hard origin/main
```

---

## 2. Decoupled Media Architecture (Zero Git Bloat)

1. **Storage Decoupling**: All heavy media libraries (Movies, TV Shows, Music, Personal Videos, Downloads) must remain stored **outside** the Git repository directory (e.g. in external folders such as `C:\Media` or external drive/OneDrive storage).
2. **Hardened Git Ignore**: The newly pushed `.gitignore` completely excludes all variations of media folder names (`[Mm]ovies/`, `[Ss]hows/`, `[Tt][Vv]/`, `[Vv]ideos/`, `[Mm]usic/`, `[Dd]ownloads/`, etc.) and all media audio/video extensions (`*.mkv`, `*.mp4`, `*.flac`, `*.mp3`, `*.wav`, `*.alac`, `*.m4a`, etc.). Never bypass these rules or force-add binary files.
3. **Environment Variables**: Configure local media paths in `.env` (`MEDIA_DIR`, `MUSIC_ROOT`, `TV_ROOT`, `MOVIES_ROOT`).
4. **Volume Mounts**: In `docker-compose.yml`, Jellyfin is configured to mount:
   - `${MEDIA_DIR:-C:/Media}:/data`
   - `${MUSIC_ROOT:-C:/Media/Music}:/data/music`
   - `${MUSIC_ROOT:-C:/Media/Music}:/music`

---

## 3. SQLite Database Health & Crash-Loop Prevention

1. **Sonarr Command Queue Integrity**:
   - VoltaireDeux identified and repaired an issue where Sonarr's internal `Commands` table btree page became malformed during background task trimming (`MessagingCleanup`).
   - If VoltaireUn encounters SQLite error code 11 (`database disk image is malformed`), do not wipe the configuration. The series, episodes, quality profiles, and naming rules are intact.
   - Run a WAL checkpoint or clear the ephemeral `Commands` table.
2. **Lock File Sanitation**:
   - Always verify that stale SQLite journal and lock files (`*.db-journal`, `*.db-wal`, `*.db-shm`) are not locked by dangling processes before launching the Servarr stack.
   - VoltaireUn should execute:
     ```powershell
     .\repair-files\Repair-MediaStackFleet.ps1 -AutoFix
     ```

---

## 4. UI Aesthetics: Cyberpunk Neon Custom Theme

VoltaireDeux has deployed a high-performance Cyberpunk Neon custom stylesheet (`jellyfin-neon-cyberpunk.css`):
- **Palette**: Electric Cyan/Blue (`#00f0ff`, `#0072ff`) and Neon Yellow (`#ffe600`, `#fff238`).
- **Features**: Frosted glassmorphism, glowing card hover effects, cyber scrollbars, and styled audio player.
- **Activation**: Copy stylesheet content into **Jellyfin Dashboard -> General / Branding -> Custom CSS**.

---

## 5. Verification & Fleet Health Check

After pulling changes and reconciling, verify all services:
```powershell
# 1. Re-align and verify media libraries & user profile visibility:
.\repair-files\Repair-MediaLibraries.ps1 -AutoFix

# 2. Run master fleet diagnostics and self-healing:
.\repair-files\Repair-MediaStackFleet.ps1 -AutoFix

# 3. Confirm network SMB shares:
.\repair-files\Fix-MediaStackNetworkShares.ps1 -CheckOnly
```

*Generated autonomously by VoltaireDeux AI Acceleration & Sentinel Engine.*
