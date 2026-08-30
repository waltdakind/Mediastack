# MediaStack Windows SMB Shares Setup

## Overview
This guide enables Docker containers to access Windows directories through SMB shares. Containers access data via `\\host.docker.internal\share_name`.

## Directory Structure

All paths resolve from `C:\Users\Public\`:

| Directory | Purpose | Container Access |
|-----------|---------|-------------------|
| `MediaStack/` | Main project root | — |
| `Music/` | Music library | `/media/music` (read-only) |
| `Videos/` | TV shows & movies | `/media/videos` (read-only) |
| `Pictures/` | Photo library | `/media/pictures` (read-only) |
| `downloads/` | Torrent downloads | `/downloads` (read-write) |
| `MediaStack/documents/` | Documents | `/media/documents` (read-only) |

## Windows SMB Share Setup

### Step 1: Enable Network Discovery & File Sharing
1. Open **Settings** → **Network & internet** → **Advanced network settings**
2. Click **Network discovery** → turn **ON**
3. Click **File and printer sharing** → turn **ON**

### Step 2: Create SMB Shares (via File Explorer)

#### Share: `Public-Music`
1. Right-click `C:\Users\Public\Music` → **Properties**
2. Click **Sharing** tab → **Advanced Sharing**
3. Check ✓ **Share this folder**
4. Set **Share name:** `Public-Music`
5. Click **Permissions** → Select **Everyone** → Check ✓ **Read**
6. Click **Apply** → **OK**

#### Share: `Public-Videos`
1. Right-click `C:\Users\Public\Videos` → **Properties**
2. Click **Sharing** tab → **Advanced Sharing**
3. Check ✓ **Share this folder**
4. Set **Share name:** `Public-Videos`
5. Click **Permissions** → Select **Everyone** → Check ✓ **Read**
6. Click **Apply** → **OK**

#### Share: `Public-Pictures`
1. Right-click `C:\Users\Public\Pictures` → **Properties**
2. Click **Sharing** tab → **Advanced Sharing**
3. Check ✓ **Share this folder**
4. Set **Share name:** `Public-Pictures`
5. Click **Permissions** → Select **Everyone** → Check ✓ **Read**
6. Click **Apply** → **OK**

#### Share: `Public-Downloads`
1. Right-click `C:\Users\Public\downloads` → **Properties**
2. Click **Sharing** tab → **Advanced Sharing**
3. Check ✓ **Share this folder**
4. Set **Share name:** `Public-Downloads`
5. Click **Permissions** → Select **Everyone** → Check ✓ **Full Control** (read/write for downloads)
6. Click **Apply** → **OK**

#### Share: `MediaStack-Documents`
1. Right-click `C:\Users\Public\MediaStack\documents` → **Properties**
2. Click **Sharing** tab → **Advanced Sharing**
3. Check ✓ **Share this folder**
4. Set **Share name:** `MediaStack-Documents`
5. Click **Permissions** → Select **Everyone** → Check ✓ **Read**
6. Click **Apply** → **OK**

### Step 3: Verify Shares via PowerShell
```powershell
net share
```
Expected output includes:
```
Public-Music           C:\Users\Public\Music
Public-Videos          C:\Users\Public\Videos
Public-Pictures        C:\Users\Public\Pictures
Public-Downloads       C:\Users\Public\downloads
MediaStack-Documents   C:\Users\Public\MediaStack\documents
```

### Step 4: Allow through Windows Firewall

Open **Windows Defender Firewall** → **Allow an app through firewall**:
- ✓ **File and Printer Sharing (SMB-In)** — Private ✓
- ✓ **File and Printer Sharing (SMB-Out)** — Private ✓

Or via PowerShell (Admin):
```powershell
Enable-NetFirewallRule -DisplayGroup "File and Printer Sharing"
```

## Docker Access via SMB

### Host Name Resolution
Docker containers can access the host using:
- `host.docker.internal` (standard resolution)
- Windows hostname (if DNS is configured)

### Mounting SMB Shares in docker-compose.yml

**Example: Mount Public-Downloads for Transmission**
```yaml
transmission:
  image: linuxserver/transmission:latest
  volumes:
    - \\\\host.docker.internal\\Public-Downloads:/downloads
    - \\\\host.docker.internal\\Public-Downloads/watch:/watch
```

**Escaping Rules:**
- Windows paths use backslashes: `\\`
- In YAML, escape backslashes: `\\\\` (4 backslashes = 2 actual)
- Share names are case-insensitive: `public-downloads` = `Public-Downloads`

### Current Implementation

All services use **relative paths** by default:
- `./downloads` → `C:\Users\Public\MediaStack\downloads` (local bind mount)
- `../Videos` → `C:\Users\Public\Videos` (parent directory, Windows path)

**To switch to SMB shares** (if local paths are inaccessible), uncomment and modify in docker-compose.yml:
```yaml
volumes:
  - \\\\host.docker.internal\\Public-Downloads:/downloads
```

## Troubleshooting

### Test SMB Connectivity
```powershell
# From Windows command line or PowerShell
net view
net view \\<hostname>
```

### Test from Inside Container
```bash
# Inside container, test DNS resolution
nslookup host.docker.internal
ping host.docker.internal

# Test SMB access (if smbclient/mount.cifs available)
mount -t cifs //host.docker.internal/Public-Downloads /mnt/test
```

### Common Issues

| Issue | Solution |
|-------|----------|
| "File not found" in container | Verify SMB share exists via `net share`; check Windows Firewall |
| "Permission denied" | Increase share permissions to **Full Control**; check PUID/PGID |
| "Network path not found" | Verify hostname; test with `net view \\hostname` |
| Slow performance | SMB over docker has latency; local bind mounts (current setup) are faster |

## Performance Notes

**Recommendation:** Use local bind mounts (current docker-compose.yml) for best performance:
- Direct filesystem access (~1x speed)
- SMB shares add ~10-20% overhead on Windows

Only switch to SMB if:
- Local paths are on different physical drives
- Remote server storage is needed
- Disaster recovery/failover requires shared state

## Verification Checklist

- [ ] Network discovery enabled
- [ ] File sharing enabled  
- [ ] All 5 SMB shares created via Advanced Sharing
- [ ] Windows Firewall allows File/Printer Sharing
- [ ] `net share` command lists all 5 shares
- [ ] `docker ps` shows all containers running
- [ ] Container logs show successful mount: `docker logs <container_name>`
