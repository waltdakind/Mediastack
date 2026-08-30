# ==============================================================================
# Add-HostsEntries.ps1 - Intelligent Windows Hosts File Provisioner & Domain Resolver
# Adds voltairedeux.local, voltaireun.local, ordinateur.local & mediaserver.local domain mappings
# ==============================================================================
param(
    [string]$HostsPath = "$env:SystemRoot\System32\drivers\etc\hosts",
    [string]$TargetIp = "127.0.0.1",
    [string]$VoltaireUnIp = "192.168.4.21",
    [string]$VoltaireDeuxIp = "192.168.4.30"
)

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::InputEncoding  = [System.Text.Encoding]::UTF8

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$fileTimestamp = Get-Date -Format "yyyyMMdd_HHmmss"

Write-Host "`n================================================================================" -ForegroundColor DarkCyan
Write-Host "     H O S T S   F I L E   D O M A I N   P R O V I S I O N E R" -ForegroundColor Cyan
Write-Host ("     Target File: {0} | Timestamp: {1}" -f $HostsPath, $timestamp) -ForegroundColor DarkGray
Write-Host "================================================================================" -ForegroundColor DarkCyan

if (-not (Test-Path $HostsPath)) {
    Write-Host "  [CRITICAL] Hosts file not found at $HostsPath" -ForegroundColor Red
    exit 1
}

# 1. Backup Hosts File
$backupPath = "$HostsPath.bak_$fileTimestamp"
try {
    Copy-Item -Path $HostsPath -Destination $backupPath -Force
    Write-Host ("  [OK] Hosts file safely backed up to: {0}" -f $backupPath) -ForegroundColor Green
} catch {
    Write-Host ("  [WARN] Failed to create backup: {0}" -f $_.Exception.Message) -ForegroundColor Yellow
}

# 2. Define Full Matrix of Local Domain Mappings
$domainsToAdd = @(
    # Cluster Peer Host Resolution
    @{ IP=$VoltaireUnIp;   Domain="voltaireun.lan" },
    @{ IP=$VoltaireDeuxIp; Domain="voltairedeux.lan" },

    # VoltaireUn Local Domains
    @{ IP="127.0.0.1"; Domain="voltaireun.local" },
    @{ IP="127.0.0.1"; Domain="jellyfin.voltaireun.local" },
    @{ IP="127.0.0.1"; Domain="sonarr.voltaireun.local" },
    @{ IP="127.0.0.1"; Domain="radarr.voltaireun.local" },
    @{ IP="127.0.0.1"; Domain="prowlarr.voltaireun.local" },
    @{ IP="127.0.0.1"; Domain="bazarr.voltaireun.local" },
    @{ IP="127.0.0.1"; Domain="jellyseerr.voltaireun.local" },
    @{ IP="127.0.0.1"; Domain="transmission.voltaireun.local" },
    @{ IP="127.0.0.1"; Domain="tvheadend.voltaireun.local" },
    @{ IP="127.0.0.1"; Domain="musicbrainz.voltaireun.local" },
    @{ IP="127.0.0.1"; Domain="db.voltaireun.local" },
    @{ IP="127.0.0.1"; Domain="api.voltaireun.local" },
    @{ IP="127.0.0.1"; Domain="homepage.voltaireun.local" },
    @{ IP="127.0.0.1"; Domain="hdhomerun.voltaireun.local" },

    # VoltaireDeux Local Domains
    @{ IP="127.0.0.1"; Domain="voltairedeux.local" },
    @{ IP="127.0.0.1"; Domain="jellyfin.voltairedeux.local" },
    @{ IP="127.0.0.1"; Domain="sonarr.voltairedeux.local" },
    @{ IP="127.0.0.1"; Domain="radarr.voltairedeux.local" },
    @{ IP="127.0.0.1"; Domain="prowlarr.voltairedeux.local" },
    @{ IP="127.0.0.1"; Domain="bazarr.voltairedeux.local" },
    @{ IP="127.0.0.1"; Domain="jellyseerr.voltairedeux.local" },
    @{ IP="127.0.0.1"; Domain="transmission.voltairedeux.local" },
    @{ IP="127.0.0.1"; Domain="tvheadend.voltairedeux.local" },
    @{ IP="127.0.0.1"; Domain="musicbrainz.voltairedeux.local" },
    @{ IP="127.0.0.1"; Domain="db.voltairedeux.local" },
    @{ IP="127.0.0.1"; Domain="api.voltairedeux.local" },
    @{ IP="127.0.0.1"; Domain="homepage.voltairedeux.local" },
    @{ IP="127.0.0.1"; Domain="hdhomerun.voltairedeux.local" },

    # Ordinateur Local Domains
    @{ IP="127.0.0.1"; Domain="ordinateur.local" },
    @{ IP="127.0.0.1"; Domain="jellyfin.ordinateur.local" },
    @{ IP="127.0.0.1"; Domain="sonarr.ordinateur.local" },
    @{ IP="127.0.0.1"; Domain="radarr.ordinateur.local" },
    @{ IP="127.0.0.1"; Domain="prowlarr.ordinateur.local" },
    @{ IP="127.0.0.1"; Domain="bazarr.ordinateur.local" },
    @{ IP="127.0.0.1"; Domain="jellyseerr.ordinateur.local" },
    @{ IP="127.0.0.1"; Domain="transmission.ordinateur.local" },
    @{ IP="127.0.0.1"; Domain="tvheadend.ordinateur.local" },
    @{ IP="127.0.0.1"; Domain="musicbrainz.ordinateur.local" },
    @{ IP="127.0.0.1"; Domain="db.ordinateur.local" },
    @{ IP="127.0.0.1"; Domain="api.ordinateur.local" },
    @{ IP="127.0.0.1"; Domain="homepage.ordinateur.local" },
    @{ IP="127.0.0.1"; Domain="hdhomerun.ordinateur.local" },

    # MediaServer Local Domains
    @{ IP="127.0.0.1"; Domain="db.mediaserver.local" },
    @{ IP="127.0.0.1"; Domain="api.mediaserver.local" },
    @{ IP="127.0.0.1"; Domain="homepage.mediaserver.local" },
    @{ IP="127.0.0.1"; Domain="musicbrainz.mediaserver.local" },
    @{ IP="127.0.0.1"; Domain="hdhomerun.mediaserver.local" }
)

# 3. Read Current Content and Append Missing Entries
$currentContent = Get-Content -Path $HostsPath -Raw -ErrorAction Stop
$newEntriesAdded = 0
$linesToAppend = [System.Collections.ArrayList]::new()

[void]$linesToAppend.Add("`r`n# --- MediaStack Multi-Domain Cluster Routing (Added $timestamp) ---")

foreach ($item in $domainsToAdd) {
    $ip = $item.IP
    $dom = $item.Domain
    $pattern = "(?m)^\s*[\d\.:]+\s+.*\b" + [regex]::Escape($dom) + "\b"
    
    if ($currentContent -notmatch $pattern) {
        $entryLine = "{0,-16} {1}" -f $ip, $dom
        [void]$linesToAppend.Add($entryLine)
        Write-Host ("  [ADDED]   {0,-16} -> {1}" -f $ip, $dom) -ForegroundColor Green
        $newEntriesAdded++
    } else {
        Write-Host ("  [EXISTS]  {0}" -f $dom) -ForegroundColor DarkGray
    }
}

# 4. Write back to Hosts file if new entries found
if ($newEntriesAdded -gt 0) {
    $appendix = ($linesToAppend -join "`r`n") + "`r`n"
    Add-Content -Path $HostsPath -Value $appendix -Encoding UTF8
    Write-Host ("`n  [OK] Successfully added {0} domain entries to hosts file" -f $newEntriesAdded) -ForegroundColor Green
} else {
    Write-Host "`n  [OK] All requested domains are already registered in hosts file." -ForegroundColor Green
}

# 5. Flush Local DNS Cache
Write-Host "`n[FLUSHING DNS RESOLVER CACHE]..." -ForegroundColor Yellow
try {
    Clear-DnsClientCache -ErrorAction SilentlyContinue
    cmd.exe /c "ipconfig /flushdns >nul 2>&1"
    Write-Host "  [OK] Windows DNS Resolver Cache flushed successfully." -ForegroundColor Green
} catch {
    Write-Host "  [WARN] Could not flush DNS cache automatically." -ForegroundColor Yellow
}

Write-Host "`n================================================================================" -ForegroundColor DarkCyan
Write-Host "     H O S T S   P R O V I S I O N I N G   C O M P L E T E" -ForegroundColor Cyan
Write-Host "================================================================================`n" -ForegroundColor DarkCyan
