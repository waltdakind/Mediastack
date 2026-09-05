<#
.SYNOPSIS
    Restores the MediaStack and Caddy reverse proxy to the verified working configuration.

.DESCRIPTION
    This script restores critical configuration files (Caddyfile, .env, docker-compose.yml, directory hierarchy)
    needed for jellyfin.waltdakind.xubi.org and the entire MediaStack fleet.
    It can restore from an existing backup archive, or use its built-in golden configuration templates
    if files were deleted. It then starts and validates the stack.

.PARAMETER FromBackup
    Optional path to a .zip backup created by Export-MediaStack.ps1 or Backup-MediaStackConfig.ps1.

.PARAMETER Force
    Overwrites existing configuration files with the known working configuration without prompting.

.PARAMETER SkipDockerStart
    Only restores configuration files and directories without invoking 'docker compose up -d'.

.EXAMPLE
    .\Restore-MediaStackConfig.ps1 -Force
    .\Restore-MediaStackConfig.ps1 -FromBackup .\backups\MediaStack_Backup_Latest.zip
#>

[CmdletBinding()]
param (
    [string]$FromBackup = "",
    [switch]$Force,
    [switch]$SkipDockerStart
)

$ErrorActionPreference = "Stop"
$BaseDir = if (Test-Path (Join-Path $PSScriptRoot "..\docker-compose.yml")) { (Resolve-Path (Join-Path $PSScriptRoot "..")).Path } else { $PSScriptRoot }
$ScriptDir = $BaseDir
Set-Location -Path $ScriptDir

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   MediaStack Configuration Restore & Recovery Suite" -ForegroundColor White
Write-Host "==========================================================" -ForegroundColor Cyan

# -----------------------------------------------------------------------------
# 1. Restore from Backup Archive (if provided or latest available)
# -----------------------------------------------------------------------------
if ($FromBackup -and (Test-Path $FromBackup)) {
    Write-Host "`n[1/5] Restoring from specified backup archive: $FromBackup" -ForegroundColor Yellow
    Expand-Archive -Path $FromBackup -DestinationPath $ScriptDir -Force
    Write-Host "  -> Archive extracted successfully." -ForegroundColor Green
} else {
    $backupsDir = Join-Path $ScriptDir "backups"
    $latestBackup = Get-ChildItem -Path $backupsDir -Filter "MediaStack_Backup_*.zip" -ErrorAction SilentlyContinue |
                    Sort-Object LastWriteTime -Descending |
                    Select-Object -First 1

    if ($latestBackup -and -not $Force) {
        Write-Host "`n[INFO] Found recent backup archive: $($latestBackup.FullName)" -ForegroundColor Cyan
        $choice = Read-Host "Would you like to restore from this backup archive? (Y/N, default: N)"
        if ($choice -match "^[yY]") {
            Write-Host "Restoring from $($latestBackup.FullName)..." -ForegroundColor Yellow
            Expand-Archive -Path $latestBackup.FullName -DestinationPath $ScriptDir -Force
            Write-Host "  -> Archive restored successfully." -ForegroundColor Green
        }
    }
}

# -----------------------------------------------------------------------------
# 2. Directory Hierarchy Provisioning
# -----------------------------------------------------------------------------
Write-Host "`n[2/5] Ensuring directory tree structure..." -ForegroundColor Yellow
$RequiredDirs = @(
    "config\jellyfin",
    "config\caddy_data",
    "config\caddy_config",
    "config\sonarr",
    "config\radarr",
    "config\bazarr",
    "config\jellyseerr",
    "config\prowlarr",
    "config\transmission",
    "config\tvheadend",
    "config\diun",
    "config\homepage",
    "config\db-backup",
    "transmission\config",
    "dashboard",
    "downloads",
    "certs",
    "handoffs",
    "backups"
)

foreach ($dir in $RequiredDirs) {
    $targetPath = Join-Path $ScriptDir $dir
    if (-not (Test-Path $targetPath)) {
        New-Item -ItemType Directory -Path $targetPath -Force | Out-Null
        Write-Host "  [+] Created directory: $dir" -ForegroundColor Green
    }
}

# -----------------------------------------------------------------------------
# 3. Restore Known-Good Configuration Files (Golden Templates)
# -----------------------------------------------------------------------------
Write-Host "`n[3/5] Verifying and restoring configuration files..." -ForegroundColor Yellow

# --- .env Template ---
$envPath = Join-Path $ScriptDir ".env"
if ((-not (Test-Path $envPath)) -or $Force) {
    Write-Host "  -> Writing verified .env configuration..." -ForegroundColor Cyan
    $envContent = @'
PUID=1000
PGID=1000
TZ=America/New_York

# Configuration directory
CONFIG_DIR=C:\MediastackConfig
CONFIG_ROOT=C:\MediastackConfig

# Unified Media Root for hardlinking
MEDIA_ROOT=C:\Users\waltd\OneDrive\Mediastack
MEDIA_DIR=C:\Users\waltd\OneDrive
MUSIC_ROOT=C:\Users\waltd\OneDrive\Mediastack\Music
VIDEO_ROOT=C:\Users\waltd\OneDrive\Mediastack\Videos
TV_ROOT=C:\Users\waltd\OneDrive\Mediastack\TV
LIVESTREAM_ROOT=C:\Users\waltd\OneDrive\Mediastack\LiveStream
MAIN_SERVER_HOST=192.168.4.21
LAN_DOMAIN=voltairedeux.local
'@
    Set-Content -Path $envPath -Value $envContent -Encoding UTF8
    Write-Host "  [OK] .env restored." -ForegroundColor Green
} else {
    Write-Host "  [SKIP] .env already exists." -ForegroundColor DarkGray
}

# --- Caddyfile Template ---
$caddyfilePath = Join-Path $ScriptDir "Caddyfile"
if ((-not (Test-Path $caddyfilePath)) -or $Force) {
    Write-Host "  -> Writing verified Caddyfile (DDNS & Cluster Failover)..." -ForegroundColor Cyan
    $caddyContent = @'
# =============================================================================
# Caddyfile - MediaStack Primary Reverse Proxy
# Supports Multi-Server Load Balancing, Failover, LAN (*.voltaireun.local) & DDNS (waltdakind.xubi.org)
# =============================================================================

# --- Common Snippets ---
(security_headers) {
    header {
        X-Content-Type-Options        nosniff
        X-Frame-Options               SAMEORIGIN
        Referrer-Policy               strict-origin-when-cross-origin
        -Server
    }
}

# --- Multi-Server Jellyfin Cluster with Auto-Failover & Custom Offline Page ---
(jellyfin_cluster) {
    import security_headers
    encode gzip zstd

    reverse_proxy jellyfin:8096 192.168.4.30:8096 {
        # Efficiency & Priority: Routes to primary container first, fails over to VoltaireDeux
        lb_policy first
        lb_retries 2
        lb_try_duration 4s

        # Passive health checking (quarantines failed backend for 15s)
        fail_duration 15s
        max_fails 2

        # WebSocket support
        header_up Connection {>Connection}
        header_up Upgrade {>Upgrade}
    }

    # Error handling: If all Jellyfin servers are down, serve modern status page
    handle_errors {
        @down `{err.status_code} in [502, 503, 504]`
        respond @down `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>MediaStack - All Jellyfin Servers Offline</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; }
        body { background: #0b0e14; color: #e2e8f0; display: flex; align-items: center; justify-content: center; min-height: 100vh; padding: 20px; }
        .card { background: rgba(22, 27, 34, 0.85); backdrop-filter: blur(16px); border: 1px solid rgba(255, 255, 255, 0.1); border-radius: 16px; padding: 40px; max-width: 580px; width: 100%; text-align: center; box-shadow: 0 20px 40px rgba(0,0,0,0.6); }
        .icon { font-size: 54px; margin-bottom: 20px; display: inline-block; }
        h1 { font-size: 26px; font-weight: 700; margin-bottom: 12px; color: #f8fafc; }
        p { color: #94a3b8; font-size: 15px; line-height: 1.6; margin-bottom: 24px; }
        .server-status { background: #131922; border-radius: 10px; padding: 16px; margin-bottom: 24px; text-align: left; font-size: 13px; font-family: monospace; border: 1px solid #1e293b; }
        .server-item { display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px; }
        .server-item:last-child { margin-bottom: 0; }
        .badge { padding: 3px 8px; border-radius: 6px; font-size: 11px; font-weight: 600; text-transform: uppercase; }
        .badge-fail { background: rgba(239, 68, 68, 0.2); color: #ef4444; }
        .btn { display: inline-block; background: #0284c7; color: #fff; text-decoration: none; padding: 12px 28px; border-radius: 8px; font-weight: 600; font-size: 14px; transition: 0.2s; cursor: pointer; border: none; }
        .btn:hover { background: #0369a1; }
    </style>
</head>
<body>
    <div class="card">
        <div class="icon">📡</div>
        <h1>Media Servers Offline</h1>
        <p>No active Jellyfin server could be reached on the network. Caddy attempted routing to both the primary and fallback servers, but all upstreams are currently offline or initializing.</p>
        <div class="server-status">
            <div class="server-item">
                <span>Primary (OrdinateurdeVol - 192.168.4.21:8096):</span>
                <span class="badge badge-fail">Unreachable</span>
            </div>
            <div class="server-item">
                <span>Fallback (VoltaireDeux - 192.168.4.30:8096):</span>
                <span class="badge badge-fail">Unreachable</span>
            </div>
        </div>
        <button class="btn" onclick="window.location.reload()">Retry Connection</button>
    </div>
</body>
</html>` 503
    }
}

# --- Direct Port Listeners ---
:8096 {
    import jellyfin_cluster
}

# --- External DDNS Domain (waltdakind.xubi.org) ---
http://waltdakind.xubi.org, https://waltdakind.xubi.org {
    import jellyfin_cluster
}

http://jellyfin.waltdakind.xubi.org, https://jellyfin.waltdakind.xubi.org {
    import jellyfin_cluster
}

http://jellyseerr.waltdakind.xubi.org, https://jellyseerr.waltdakind.xubi.org {
    import security_headers
    encode gzip zstd
    reverse_proxy jellyseerr:5055
}

http://sonarr.waltdakind.xubi.org, https://sonarr.waltdakind.xubi.org {
    import security_headers
    reverse_proxy sonarr:8989
}

http://radarr.waltdakind.xubi.org, https://radarr.waltdakind.xubi.org {
    import security_headers
    reverse_proxy radarr:7878
}

http://musicbrainz.waltdakind.xubi.org, https://musicbrainz.waltdakind.xubi.org {
    import security_headers
    encode gzip zstd
    reverse_proxy 192.168.4.21:5000
}

# --- Local LAN Access (*.voltaireun.local) ---
http://voltaireun.local {
    import security_headers
    encode gzip zstd
    reverse_proxy homepage:3000
}

http://jellyfin.voltaireun.local {
    import jellyfin_cluster
}

http://radarr.voltaireun.local {
    import security_headers
    reverse_proxy radarr:7878
}

http://sonarr.voltaireun.local {
    import security_headers
    reverse_proxy sonarr:8989
}

http://jellyseerr.voltaireun.local {
    import security_headers
    encode gzip zstd
    reverse_proxy jellyseerr:5055
}

http://prowlarr.voltaireun.local {
    import security_headers
    reverse_proxy prowlarr:9696
}

http://bazarr.voltaireun.local {
    import security_headers
    reverse_proxy bazarr:6767
}

http://transmission.voltaireun.local {
    import security_headers
    reverse_proxy transmission:9091 {
        header_up X-Transmission-Session-Id {http.request.header.X-Transmission-Session-Id}
    }
}

http://tvheadend.voltaireun.local {
    import security_headers
    reverse_proxy tvheadend:9981
}

http://hdhomerun.voltaireun.local {
    import security_headers
    reverse_proxy 192.168.4.45:80
}

http://musicbrainz.voltaireun.local {
    import security_headers
    encode gzip zstd
    reverse_proxy 192.168.4.21:5000
}

http://db.voltaireun.local {
    import security_headers
    reverse_proxy mediastack-db:8080
}
'@
    Set-Content -Path $caddyfilePath -Value $caddyContent -Encoding UTF8
    Write-Host "  [OK] Caddyfile restored." -ForegroundColor Green
} else {
    Write-Host "  [SKIP] Caddyfile already exists." -ForegroundColor DarkGray
}

# -----------------------------------------------------------------------------
# 4. Start Stack with Docker Compose
# -----------------------------------------------------------------------------
if (-not $SkipDockerStart) {
    Write-Host "`n[4/5] Starting Docker containers..." -ForegroundColor Yellow
    
    if (-not (Get-Command "docker" -ErrorAction SilentlyContinue)) {
        Write-Host "  [ERROR] Docker is not installed or not in PATH." -ForegroundColor Red
        return
    }

    try {
        docker compose up -d
        Write-Host "  [OK] Containers deployed." -ForegroundColor Green
    } catch {
        Write-Host "  [WARN] docker compose encountered an issue: $_" -ForegroundColor Yellow
    }
} else {
    Write-Host "`n[4/5] Skipping Docker start (-SkipDockerStart specified)." -ForegroundColor DarkGray
}

# -----------------------------------------------------------------------------
# 5. Route & Connectivity Verification
# -----------------------------------------------------------------------------
Write-Host "`n[5/5] Testing Jellyfin routes..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

$testEndpoints = @(
    @{ Name = "Local Loopback (Port 80)"; Url = "http://localhost:80"; Host = "jellyfin.waltdakind.xubi.org" },
    @{ Name = "Local Direct Jellyfin (Port 8096)"; Url = "http://localhost:8096/health"; Host = "" },
    @{ Name = "Public Route (DDNS HTTPS)"; Url = "https://jellyfin.waltdakind.xubi.org/System/Info/Public"; Host = "" }
)

foreach ($ep in $testEndpoints) {
    try {
        if ($ep.Host) {
            $code = curl.exe -s -o NUL -w "%{http_code}" --max-time 5 -H "Host: $($ep.Host)" $ep.Url
        } else {
            $code = curl.exe -s -o NUL -w "%{http_code}" --max-time 5 $ep.Url
        }
        
        if ($code -match "^(200|302|301)$") {
            Write-Host "  [OK] $($ep.Name) returned HTTP $code" -ForegroundColor Green
        } else {
            Write-Host "  [WARN] $($ep.Name) returned HTTP $code" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "  [FAIL] $($ep.Name) failed connection test" -ForegroundColor Red
    }
}

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host "   Restore & Verification Complete!" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan
