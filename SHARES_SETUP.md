# MediaStack Windows SMB Network Shares Setup

## Overview
This guide enables multi-node cluster synchronization and Docker containers to access Windows directories through reciprocal SMB shares. Nodes and containers access data via `\\<hostname_or_ip>\share_name`.

## Directory Structure & Mount Points

All paths resolve relative to the primary repository root (`C:\Users\waltd\OneDrive\Mediastack\`):

| Share Name | Local Path | Container Mount | Access Type |
| :--- | :--- | :--- | :--- |
| `MediaStack-Movies` | `C:\Users\waltd\OneDrive\Mediastack\Movies` | `/media/movies` or `/movies` | Read-Write |
| `MediaStack-Shows` | `C:\Users\waltd\OneDrive\Mediastack\Shows` | `/media/shows` or `/tv` | Read-Write |
| `MediaStack-Music` | `C:\Users\waltd\OneDrive\Mediastack\Music` | `/data/music` or `/music` | Read-Write |
| `MediaStack-TV` | `C:\Users\waltd\OneDrive\Mediastack\TV` | `/data/TV` | Read-Write |
| `MediaStack-Videos` | `C:\Users\waltd\OneDrive\Mediastack\Videos` | `/data/Videos` | Read-Write |
| `MediaStack-Radio` | `C:\Users\waltd\OneDrive\Mediastack\Radio` | `/data/Radio` | Read-Write |
| `MediaStack-Podcasts` | `C:\Users\waltd\OneDrive\Mediastack\Podcasts` | `/data/Podcasts` | Read-Write |
| `MediaStack-Downloads` | `C:\Users\waltd\OneDrive\Mediastack\downloads` | `/downloads` | Read-Write |
| `MediaStack-Documents` | `C:\Users\waltd\OneDrive\Mediastack\documents` | `/media/documents` | Read-Write |

---

## Automated Provisioning

To automatically create, permission, and publish all network shares, run:

```powershell
# From Administrator PowerShell:
.\Fix-MediaStackNetworkShares.ps1 -Elevate
# Or:
.\Set-MediaStackNetworkUsers.ps1
```

To verify and mount from the peer node:
```powershell
.\Mount-MediaStackNetworkShares.ps1 -PeerIP "192.168.4.21" -TestWrite
```

---

## Manual Windows SMB Share Setup

### Step 1: Enable Network Discovery & File Sharing
1. Open **Settings** → **Network & internet** → **Advanced network settings**
2. Click **Advanced sharing settings**
3. Turn **ON** **Network discovery** and **File and printer sharing** for Private Networks.

### Step 2: Allow Through Windows Defender Firewall
```powershell
Enable-NetFirewallRule -DisplayGroup "File and Printer Sharing"
Enable-NetFirewallRule -DisplayGroup "Network Discovery"
```

### Step 3: Verify Shares via PowerShell
```powershell
Get-SmbShare | Where-Object { $_.Name -like "MediaStack-*" }
```
Expected output:
```text
Name                 ScopeName Path                                       Description
----                 --------- ----                                       -----------
MediaStack-Movies    *         C:\Users\waltd\OneDrive\Mediastack\Movies     
MediaStack-Shows     *         C:\Users\waltd\OneDrive\Mediastack\Shows      
MediaStack-Music     *         C:\Users\waltd\OneDrive\Mediastack\Music     
MediaStack-TV        *         C:\Users\waltd\OneDrive\Mediastack\TV        
MediaStack-Videos    *         C:\Users\waltd\OneDrive\Mediastack\Videos    
MediaStack-Radio     *         C:\Users\waltd\OneDrive\Mediastack\Radio     
MediaStack-Podcasts  *         C:\Users\waltd\OneDrive\Mediastack\Podcasts  
MediaStack-Downloads *         C:\Users\waltd\OneDrive\Mediastack\downloads 
MediaStack-Documents *         C:\Users\waltd\OneDrive\Mediastack\documents 
```

---

## Docker Access via SMB

Containers on remote cluster nodes access the host using:
```yaml
transmission:
  image: linuxserver/transmission:latest
  volumes:
    - \\\\192.168.4.21\\MediaStack-Downloads:/downloads
    - \\\\192.168.4.21\\MediaStack-Downloads/watch:/watch
```

---

## Troubleshooting & Verification Checklist

- [ ] Network discovery and File sharing enabled on Private profile
- [ ] Media directories exist under `C:\Users\waltd\OneDrive\Mediastack\`
- [ ] SMB shares created with `MediaStack-` prefix
- [ ] Cluster service user (`mediasync`) has ChangeAccess / Read-Write permissions
- [ ] `Mount-MediaStackNetworkShares.ps1` passes canary read-write test
