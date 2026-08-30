$hostsPath = "C:\Windows\System32\drivers\etc\hosts"

# Ensure we are running as Administrator
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "This script needs to run as Administrator. Restarting with elevated privileges..."
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

$domains = @(
    "ordinateur.local",
    "jellyfin.ordinateur.local",
    "radarr.ordinateur.local",
    "sonarr.ordinateur.local",
    "jellyseerr.ordinateur.local",
    "prowlarr.ordinateur.local",
    "bazarr.ordinateur.local",
    "transmission.ordinateur.local",
    "tvheadend.ordinateur.local",
    "hdhomerun.ordinateur.local"
)

$block = @"

# =========================================
# MEDIASTACK HOSTS
# To switch machines, uncomment (remove #) from the active IP block
# and comment out (add #) to the inactive IPs.
# =========================================

# --- Option 1: LAPTOP / WSL (Localhost) ---
# 192.168.4.30 ordinateur.local jellyfin.ordinateur.local radarr.ordinateur.local sonarr.ordinateur.local jellyseerr.ordinateur.local prowlarr.ordinateur.local bazarr.ordinateur.local transmission.ordinateur.local tvheadend.ordinateur.local hdhomerun.ordinateur.local

# --- Option 2: MINI-PC (Primary) ---
192.168.4.21 ordinateur.local jellyfin.ordinateur.local radarr.ordinateur.local sonarr.ordinateur.local jellyseerr.ordinateur.local prowlarr.ordinateur.local bazarr.ordinateur.local transmission.ordinateur.local tvheadend.ordinateur.local hdhomerun.ordinateur.local

# --- Option 3: RASPBERRY PI (Future) ---
# 192.168.4.XX ordinateur.local jellyfin.ordinateur.local radarr.ordinateur.local sonarr.ordinateur.local jellyseerr.ordinateur.local prowlarr.ordinateur.local bazarr.ordinateur.local transmission.ordinateur.local tvheadend.ordinateur.local hdhomerun.ordinateur.local

# =========================================
"@

# Clean up any old MediaStack lines if they exist
$currentHosts = Get-Content $hostsPath -Raw
if ($currentHosts -match "# MEDIASTACK HOSTS") {
    Write-Host "MediaStack hosts configuration already exists. Please edit C:\Windows\System32\drivers\etc\hosts manually." -ForegroundColor Yellow
    Start-Sleep -Seconds 5
    exit
}

Add-Content -Path $hostsPath -Value $block
Write-Host "Hosts file successfully updated! Traffic is now routing to the Mini-PC (192.168.4.21)." -ForegroundColor Green
Write-Host "You can edit C:\Windows\System32\drivers\etc\hosts in Notepad (as Admin) to switch endpoints later."
Start-Sleep -Seconds 5
