# Update-Hosts.ps1 - Automated Windows Hosts File Manager for MediaStack
param(
    [string]$LanIp = "192.168.4.30",
    [switch]$IncludeLoopback = $true
)

$hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"

if (-not (Test-Path $hostsPath)) {
    Write-Error "Hosts file not found at $hostsPath"
    exit 1
}

$services = @(
    "ordinateur.local",
    "mediaserver.local",
    "jellyfin.ordinateur.local",
    "jellyfin.mediaserver.local",
    "radarr.ordinateur.local",
    "radarr.mediaserver.local",
    "sonarr.ordinateur.local",
    "sonarr.mediaserver.local",
    "jellyseerr.ordinateur.local",
    "jellyseerr.mediaserver.local",
    "prowlarr.ordinateur.local",
    "prowlarr.mediaserver.local",
    "bazarr.ordinateur.local",
    "bazarr.mediaserver.local",
    "transmission.ordinateur.local",
    "transmission.mediaserver.local",
    "tvheadend.ordinateur.local",
    "tvheadend.mediaserver.local",
    "hdhomerun.ordinateur.local",
    "hdhomerun.mediaserver.local",
    "db.ordinateur.local",
    "db.mediaserver.local",
    "api.ordinateur.local",
    "api.mediaserver.local",
    "homepage.ordinateur.local",
    "homepage.mediaserver.local",
    "musicbrainz.ordinateur.local",
    "musicbrainz.mediaserver.local"
)

$blockHeader = "# --- MediaStack Routing Block ---"
$blockFooter = "# --- End MediaStack Routing Block ---"

$newEntries = @()
$newEntries += $blockHeader
$newEntries += "# Generated at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$newEntries += ""
$newEntries += "# Loopback Mappings (for local processes and health checks)"
if ($IncludeLoopback) {
    foreach ($s in $services) {
        $newEntries += "127.0.0.1`t$s"
    }
}
$newEntries += ""
$newEntries += "# LAN Mappings (for other devices on local network)"
foreach ($s in $services) {
    $newEntries += "$LanIp`t$s"
}
$newEntries += $blockFooter

$blockString = $newEntries -join "`r`n"

try {
    $currentContent = Get-Content -Path $hostsPath -Raw -ErrorAction Stop

    # Remove existing MediaStack block if present
    $pattern = "(?s)# --- MediaStack Routing Block ---.*?# --- End MediaStack Routing Block ---"
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
    Write-Host "[SUCCESS] Hosts file successfully updated! Backup created at $backupPath" -ForegroundColor Green
} catch {
    Write-Warning "Could not write directly to $hostsPath (requires Administrator privileges)."
    Write-Host "`nTo apply automatically, run PowerShell as Administrator and execute:" -ForegroundColor Yellow
    Write-Host "Set-Content -Path '$hostsPath' -Value @'`n$blockString`n'@ -Encoding ASCII -Force`n" -ForegroundColor Cyan
}
