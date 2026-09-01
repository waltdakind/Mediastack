# Update-Hosts.ps1 - Automated Windows Hosts File Manager for MediaStack Cluster
[CmdletBinding()]
param(
    [string]$PrimaryIp = "192.168.4.21",
    [string]$SecondaryIp = "192.168.4.30",
    [switch]$SkipLoopback
)

$hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"

if (-not (Test-Path $hostsPath)) {
    Write-Error "Hosts file not found at $hostsPath"
    exit 1
}

# Core Cluster Node Hostnames & Services
$primaryServices = @(
    "voltaireun",
    "voltaireun.local",
    "jellyfin.voltaireun.local",
    "sonarr.voltaireun.local",
    "radarr.voltaireun.local",
    "prowlarr.voltaireun.local",
    "bazarr.voltaireun.local",
    "jellyseerr.voltaireun.local",
    "transmission.voltaireun.local",
    "tvheadend.voltaireun.local",
    "hdhomerun.voltaireun.local",
    "musicbrainz.voltaireun.local",
    "db.voltaireun.local",
    "api.voltaireun.local",
    "homepage.voltaireun.local",
    "dashboard.voltaireun.local",
    "noc.voltaireun.local",
    "portal.voltaireun.local",
    "hub.voltaireun.local",
    "mediaserver.local"
)

$secondaryServices = @(
    "voltairedeux",
    "voltairedeux.local",
    "jellyfin.voltairedeux.local",
    "musicbrainz.voltairedeux.local",
    "dashboard.voltairedeux.local",
    "syncthing.voltairedeux.local"
)

$blockHeader = "# --- MediaStack Cluster Routing Block (Voltaire Naming Convention) ---"
$blockFooter = "# --- End MediaStack Cluster Routing Block ---"

$newEntries = @()
$newEntries += $blockHeader
$newEntries += "# Generated at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$newEntries += ""
$newEntries += "# Primary Node: VoltaireUn (192.168.4.21 - Formerly VOLTAIREUN / voltaireun)"
foreach ($s in $primaryServices) {
    $newEntries += "$PrimaryIp`t$s"
}
$newEntries += ""
$newEntries += "# Secondary Node: VoltaireDeux (192.168.4.30 - AI Workstation & MusicBrainz Mirror)"
foreach ($s in $secondaryServices) {
    $newEntries += "$SecondaryIp`t$s"
}

if (-not $SkipLoopback) {
    $newEntries += ""
    $newEntries += "# Local Node Loopback Shortcuts"
    $newEntries += "127.0.0.1`tvoltairedeux.local"
    $newEntries += "127.0.0.1`tmusicbrainz.local"
    $newEntries += "127.0.0.1`tmediastack.local"
}

$newEntries += $blockFooter
$blockString = $newEntries -join "`r`n"

try {
    $currentContent = Get-Content -Path $hostsPath -Raw -ErrorAction Stop

    # Remove existing MediaStack block if present
    $pattern = "(?s)# --- MediaStack.*?# --- End MediaStack.*?(?:\r?\n|$)"
    if ($currentContent -match $pattern) {
        $cleanedContent = [regex]::Replace($currentContent, $pattern, "").Trim()
    } else {
        $cleanedContent = $currentContent.Trim()
    }

    $finalContent = "$cleanedContent`r`n`r`n$blockString`r`n"

    # Try to write with backup
    $backupPath = "$hostsPath.bak.$(Get-Date -Format 'yyyyMMddHHmmss')"
    Copy-Item -Path $hostsPath -Destination $backupPath -Force
    Set-Content -Path $hostsPath -Value $finalContent -Encoding ASCII -Force
    Write-Host "[SUCCESS] Hosts file successfully updated with Voltaire cluster topology! Backup created at $backupPath" -ForegroundColor Green
} catch {
    Write-Warning "Could not write directly to $hostsPath (requires Administrator privileges)."
    Write-Host "`nTo apply automatically, run PowerShell as Administrator and execute:" -ForegroundColor Yellow
    Write-Host "Set-Content -Path '$hostsPath' -Value @'`n$blockString`n'@ -Encoding ASCII -Force`n" -ForegroundColor Cyan
}
