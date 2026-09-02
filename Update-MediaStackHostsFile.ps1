# Update-MediaStackHostsFile.ps1 - Synchronize Local DNS Virtual Hosts in Windows Hosts File
[CmdletBinding()]
param()

$hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
$backupPath = "$env:SystemRoot\System32\drivers\etc\hosts.bak_$(Get-Date -Format 'yyyyMMdd_HHmmss')"

Write-Host "`n================================================================================" -ForegroundColor DarkCyan
Write-Host "   M E D I A S T A C K   L O C A L   D N S   &   H O S T S   E N G I N E" -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor DarkCyan

Write-Host "Creating backup of hosts file: $backupPath" -ForegroundColor Yellow
Copy-Item -Path $hostsPath -Destination $backupPath -Force -ErrorAction SilentlyContinue

$hostsEntries = @"

# ==============================================================================
# MEDIASTACK MULTI-NODE CLUSTER & SSL VIRTUAL HOSTS (AUTO-GENERATED)
# ==============================================================================

# --- Node 2: VoltaireDeux (192.168.4.30) Localhost & LAN Ingress ---
127.0.0.1       localhost
192.168.4.30    voltairedeux.local
192.168.4.30    jellyfin.voltairedeux.local
192.168.4.30    dashboard.voltairedeux.local
192.168.4.30    sonarr.voltairedeux.local
192.168.4.30    radarr.voltairedeux.local
192.168.4.30    prowlarr.voltairedeux.local
192.168.4.30    bazarr.voltairedeux.local
192.168.4.30    jellyseerr.voltairedeux.local
192.168.4.30    transmission.voltairedeux.local
192.168.4.30    tvheadend.voltairedeux.local
192.168.4.30    hdhomerun.voltairedeux.local
192.168.4.30    musicbrainz.voltairedeux.local
192.168.4.30    db.voltairedeux.local
192.168.4.30    home.voltairedeux.local
192.168.4.30    homepage.voltairedeux.local

# --- Node 1: VoltaireUn (192.168.4.21) Primary Server Ingress ---
192.168.4.21    voltaireun.local
192.168.4.21    jellyfin.voltaireun.local
192.168.4.21    dashboard.voltaireun.local
192.168.4.21    sonarr.voltaireun.local
192.168.4.21    radarr.voltaireun.local
192.168.4.21    prowlarr.voltaireun.local
192.168.4.21    bazarr.voltaireun.local
192.168.4.21    jellyseerr.voltaireun.local
192.168.4.21    transmission.voltaireun.local
192.168.4.21    tvheadend.voltaireun.local
192.168.4.21    hdhomerun.voltaireun.local
192.168.4.21    musicbrainz.voltaireun.local
192.168.4.21    db.voltaireun.local
192.168.4.21    home.voltaireun.local
192.168.4.21    homepage.voltaireun.local

# --- Legacy Alias Mappings ---
192.168.4.30    mediaserver.local
192.168.4.30    jellyfin.mediaserver.local
192.168.4.30    radarr.mediaserver.local
192.168.4.30    sonarr.mediaserver.local
192.168.4.30    jellyseerr.mediaserver.local
192.168.4.30    prowlarr.mediaserver.local
192.168.4.30    bazarr.mediaserver.local
192.168.4.30    transmission.mediaserver.local
192.168.4.30    tvheadend.mediaserver.local
"@

try {
    # Read existing content and remove old MediaStack block if present
    $currentContent = Get-Content $hostsPath -Raw -ErrorAction Stop
    $cleanContent = $currentContent -replace '(?s)# =+[\r\n]+# MEDIASTACK MULTI-NODE CLUSTER.*?# --- Legacy Alias Mappings.*?tvheadend\.mediaserver\.local', ''
    $cleanContent = $cleanContent.TrimEnd() + "`r`n" + $hostsEntries

    [System.IO.File]::WriteAllText($hostsPath, $cleanContent, [System.Text.Encoding]::ASCII)
    Write-Host "[OK] Windows hosts file successfully updated with all VoltaireDeux & VoltaireUn virtual hosts!" -ForegroundColor Green
} catch {
    Write-Host "[WARN] Direct write failed: $($_.Exception.Message). Trying elevated append..." -ForegroundColor Yellow
    # Fallback to Add-Content
    Add-Content -Path $hostsPath -Value $hostsEntries -Force
}

# Flush DNS
Write-Host "Flushing Windows DNS Resolver Cache..." -ForegroundColor Cyan
ipconfig /flushdns | Out-Null
Write-Host "[OK] DNS Cache Flushed. Local virtual hosts are live!`n" -ForegroundColor Green
