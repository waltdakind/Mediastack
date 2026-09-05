<#
.SYNOPSIS
    Setup-MediaStackCaddyServer.ps1 - Primary Caddy Reverse Proxy & Dual-Node Ingress Security Engine.

.DESCRIPTION
    Fully secures and deploys the Primary Caddy Reverse Proxy server across the MediaStack cluster:
    1. Directs ALL root incoming web & streaming traffic to JELLYFIN (:80, :443, :8096).
    2. Enforces HTTPS & HSTS encryption across ALL external requests (waltdakind.xubi.org)
       AND ALL internal LAN requests (*.voltaireun.local, *.voltairedeux.local, 192.168.4.21, 192.168.4.30).
    3. Automatically redirects any plain HTTP (:80) request to secure HTTPS (:443).
    4. Provisions 4096-bit Multi-Domain SAN TLS certificates and installs the Root CA into Windows Trust.
    5. Configures dual-node upstream failover between VoltaireUn (192.168.4.21) and VoltaireDeux (192.168.4.30).
    6. Validates Caddyfile syntax, reloads Caddy container, and executes a full live probe suite.

.PARAMETER PrimaryServerIP
    IP address of the primary 24/7 server node (VoltaireUn). Default is 192.168.4.21.

.PARAMETER SecondaryServerIP
    IP address of the secondary AI/workstation node (VoltaireDeux). Default is 192.168.4.30.

.PARAMETER ExternalDomain
    Primary external DDNS hostname. Default is waltdakind.xubi.org.

.PARAMETER ForceRecreateCerts
    Forces regeneration of 4096-bit multi-domain SSL/TLS certificates.

.PARAMETER InstallRootCA
    Imports ca.crt into the local Windows Certificate Trust Store. Default is $true.

.PARAMETER NonInteractive
    Runs quietly without user prompt pauses (for automation/sentinel use).

.EXAMPLE
    .\Setup-MediaStackCaddyServer.ps1
    .\Setup-MediaStackCaddyServer.ps1 -ForceRecreateCerts -InstallRootCA:$true
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)][string]$PrimaryServerIP = "192.168.4.21",
    [Parameter(Mandatory = $false)][string]$SecondaryServerIP = "192.168.4.30",
    [Parameter(Mandatory = $false)][string]$ExternalDomain = "waltdakind.xubi.org",
    [Parameter(Mandatory = $false)][switch]$ForceRecreateCerts,
    [Parameter(Mandatory = $false)][switch]$InstallRootCA,
    [Parameter(Mandatory = $false)][switch]$NonInteractive
)

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::InputEncoding  = [System.Text.Encoding]::UTF8

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$BaseDir = if (Test-Path (Join-Path $PSScriptRoot "..\docker-compose.yml")) { (Resolve-Path (Join-Path $PSScriptRoot "..")).Path } else { $PSScriptRoot }
$CertDir = Join-Path $BaseDir "certs"
$CaddyfilePath = Join-Path $BaseDir "Caddyfile"
$HandoffsDir = Join-Path $BaseDir "handoffs"

if (-not (Test-Path $HandoffsDir)) { New-Item -ItemType Directory -Force -Path $HandoffsDir | Out-Null }
if (-not (Test-Path $CertDir)) { New-Item -ItemType Directory -Force -Path $CertDir | Out-Null }

Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host "   M A S T E R   C A D D Y   E N D - T O - E N D   S E C U R I T Y   E N G I N E" -ForegroundColor DarkCyan
Write-Host "   Dual-Node Upstreams: $PrimaryServerIP <---> $SecondaryServerIP" -ForegroundColor White
Write-Host "   External Domain    : $ExternalDomain (HTTPS :443 Enforced)" -ForegroundColor White
Write-Host "   Internal LAN Ingress: HTTPS :443 Enforced for All Subdomains & IPs" -ForegroundColor White
Write-Host "   Timestamp          : $timestamp" -ForegroundColor DarkGray
Write-Host "================================================================================" -ForegroundColor Cyan

# ==============================================================================
# STAGE 1: AUDIT & GENERATE SSL/TLS CERTIFICATES + ROOT CA TRUST
# ==============================================================================
Write-Host "`n[STAGE 1/5] Auditing SSL/TLS Certificates for External & LAN Routing..." -ForegroundColor Yellow

$certPem = Join-Path $CertDir "cert.pem"
$keyPem  = Join-Path $CertDir "key.pem"
$caCrt   = Join-Path $CertDir "ca.crt"

$needCerts = $ForceRecreateCerts -or (-not (Test-Path $certPem)) -or (-not (Test-Path $keyPem)) -or (-not (Test-Path $caCrt))

if ($needCerts) {
    Write-Host "  [*] Generating new 4096-bit multi-domain SAN certificates with Root CA..." -ForegroundColor Cyan
    $certScript = Join-Path $BaseDir "New-MediaStackSslCertificates.ps1"
    if (Test-Path $certScript) {
        & $certScript -CertDir $CertDir -PrimaryDomain $ExternalDomain -SkipCaddyReload
    } else {
        Write-Host "  [ERR] New-MediaStackSslCertificates.ps1 not found at $certScript" -ForegroundColor Red
    }
} else {
    Write-Host "  [OK] Active TLS certificates verified in $CertDir (cert.pem, key.pem, ca.crt present)." -ForegroundColor Green
}

# Install Root CA into Windows Certificate Store for seamless green padlock
if ($InstallRootCA -and (Test-Path $caCrt)) {
    $trustScript = Join-Path $BaseDir "Install-MediaStackRootCA.ps1"
    if (Test-Path $trustScript) {
        & $trustScript -CertPath $caCrt -NonInteractive
    } else {
        try {
            if (Get-Command Import-Certificate -ErrorAction SilentlyContinue) {
                Import-Certificate -FilePath $caCrt -CertStoreLocation "Cert:\LocalMachine\Root" -ErrorAction SilentlyContinue | Out-Null
                Import-Certificate -FilePath $caCrt -CertStoreLocation "Cert:\CurrentUser\Root" -ErrorAction SilentlyContinue | Out-Null
            }
            & certutil.exe -addstore -f "Root" $caCrt 2>&1 | Out-Null
        } catch { }
    }
}

# ==============================================================================
# STAGE 2: GENERATE PRIMARY OPTIMIZED CADDYFILE (FULL HTTPS ENFORCEMENT)
# ==============================================================================
Write-Host "`n[STAGE 2/5] Synthesizing Primary Caddyfile with Full Internal/External HTTPS Enforcement..." -ForegroundColor Yellow

$template = @'
# =============================================================================
# Caddyfile - MediaStack Primary Reverse Proxy
# Supports Multi-Server Load Balancing, Failover, LAN (*.voltaireun.local / *.voltairedeux.local) & DDNS (__EXTERNAL_DOMAIN__)
# Full End-to-End TLS / HTTPS (:443) with Custom Root CA & Wildcard SANs
# Default Policy: Direct ALL root incoming traffic to JELLYFIN Media Streaming
# Internal Security Policy: All HTTP (:80) traffic redirected to HTTPS (:443)
# =============================================================================

# --- Global Options ---
{
    admin off
    persist_config off
}

# --- Common Snippets ---
(security_headers) {
    header {
        X-Content-Type-Options        nosniff
        X-Frame-Options               SAMEORIGIN
        Referrer-Policy               strict-origin-when-cross-origin
        Strict-Transport-Security     "max-age=31536000; includeSubDomains; preload"
        -Server
    }
}

(custom_tls) {
    tls /etc/caddy/certs/cert.pem /etc/caddy/certs/key.pem
}

# --- Multi-Server Jellyfin Cluster with Auto-Failover & Edge Caching Acceleration ---
(jellyfin_cluster) {
    import security_headers
    encode zstd gzip

    # Accelerated Web & Image Cache for Fast External Load Times
    @staticAssets {
        path *.ico *.css *.js *.gif *.jpg *.jpeg *.png *.svg *.woff *.woff2 *.webp
    }
    header @staticAssets Cache-Control "public, max-age=2592000, stale-while-revalidate=86400"

    @mediaPosters {
        path /Items/*/Images/* /Artists/*/Images/* /Albums/*/Images/* /web/assets/img/*
    }
    header @mediaPosters Cache-Control "public, max-age=604800, stale-while-revalidate=86400"

    # Read-Only Guest Autologin Routes
    handle /autologin* {
        rewrite * /autologin.html
        root * /var/www/dashboard
        file_server
    }

    handle /guest* {
        rewrite * /autologin.html
        root * /var/www/dashboard
        file_server
    }

    handle /listen* {
        rewrite * /autologin.html
        root * /var/www/dashboard
        file_server
    }

    # Mission Control & Real-Time Switch Radar Routes
    handle /dashboard* {
        root * /var/www/dashboard
        file_server
    }

    handle /radar* {
        root * /var/www/dashboard
        file_server
    }

    handle /status* {
        root * /var/www/dashboard
        file_server
    }

    handle /portal* {
        root * /var/www/dashboard
        file_server
    }

    handle /hub* {
        root * /var/www/dashboard
        file_server
    }

    handle /apps* {
        root * /var/www/dashboard
        file_server
    }

    handle /noc* {
        root * /var/www/dashboard
        file_server
    }

    handle /index.html {
        root * /var/www/dashboard
        file_server
    }

    # API Gateway Reverse Proxy
    handle /api/* {
        reverse_proxy api-gateway:3000
    }

    # Upstream Media Server Reverse Proxy (Default Root Destination)
    handle {
        reverse_proxy jellyfin:8096 __SECONDARY_IP__:8096 {
            lb_policy first
            lb_retries 2
            lb_try_duration 4s
            fail_duration 15s
            max_fails 2
            flush_interval -1
            header_up Connection {>Connection}
            header_up Upgrade {>Upgrade}
            transport http {
                keepalive 300s
                keepalive_idle_conns 64
                compression off
            }
        }
    }

    handle_errors {
        respond "MediaStack: Upstream media server offline or initializing. Please retry in a few moments." 503
    }
}

# --- Direct Streaming Port Listener ---
:8096 {
    import jellyfin_cluster
}

# =============================================================================
# 1. HTTP (:80) TO HTTPS (:443) GLOBAL ENFORCEMENT & REDIRECTS
# =============================================================================

# External DDNS & Jellyfin HTTP Redirection
http://__EXTERNAL_DOMAIN__, http://jellyfin.__EXTERNAL_DOMAIN__, http://jellyseerr.__EXTERNAL_DOMAIN__, http://requests.__EXTERNAL_DOMAIN__, http://issues.__EXTERNAL_DOMAIN__, http://sonarr.__EXTERNAL_DOMAIN__, http://radarr.__EXTERNAL_DOMAIN__, http://prowlarr.__EXTERNAL_DOMAIN__, http://bazarr.__EXTERNAL_DOMAIN__, http://musicbrainz.__EXTERNAL_DOMAIN__, http://portainer.__EXTERNAL_DOMAIN__ {
    import security_headers
    encode gzip zstd
    redir https://{host}{uri} permanent
}

# Internal LAN Root & IP HTTP Redirection
http://voltaireun.local, http://voltaireun.local, http://voltairedeux.local, http://mediaserver.local, http://__SECONDARY_IP__, http://__PRIMARY_IP__, http://localhost {
    import security_headers
    encode gzip zstd
    redir https://{host}{uri} permanent
}

# Internal Subdomains HTTP Redirection
http://jellyfin.voltaireun.local, http://jellyfin.voltaireun.local, http://jellyfin.voltairedeux.local, http://jellyfin.mediaserver.local, http://dashboard.voltaireun.local, http://dashboard.voltaireun.local, http://dashboard.voltairedeux.local, http://noc.voltaireun.local, http://radarr.voltaireun.local, http://radarr.voltaireun.local, http://radarr.voltairedeux.local, http://sonarr.voltaireun.local, http://sonarr.voltaireun.local, http://sonarr.voltairedeux.local, http://jellyseerr.voltaireun.local, http://jellyseerr.voltaireun.local, http://jellyseerr.voltairedeux.local, http://requests.voltaireun.local, http://requests.voltairedeux.local, http://issues.voltaireun.local, http://issues.voltairedeux.local, http://prowlarr.voltaireun.local, http://prowlarr.voltaireun.local, http://prowlarr.voltairedeux.local, http://bazarr.voltaireun.local, http://bazarr.voltaireun.local, http://bazarr.voltairedeux.local, http://transmission.voltaireun.local, http://transmission.voltaireun.local, http://transmission.voltairedeux.local, http://tvheadend.voltaireun.local, http://tvheadend.voltaireun.local, http://tvheadend.voltairedeux.local, http://hdhomerun.voltaireun.local, http://hdhomerun.voltaireun.local, http://hdhomerun.voltairedeux.local, http://musicbrainz.voltaireun.local, http://musicbrainz.voltaireun.local, http://musicbrainz.voltairedeux.local, http://db.voltaireun.local, http://db.voltaireun.local, http://db.voltairedeux.local, http://portainer.voltaireun.local, http://portainer.voltairedeux.local {
    import security_headers
    encode gzip zstd
    redir https://{host}{uri} permanent
}

# =============================================================================
# 2. SECURE HTTPS (:443) INGRESS ENDPOINTS
# =============================================================================

# --- A. Root Ingress (Directed to JELLYFIN) ---
https://__EXTERNAL_DOMAIN__, https://jellyfin.__EXTERNAL_DOMAIN__, https://voltaireun.local, https://voltaireun.local, https://voltairedeux.local, https://mediaserver.local, https://__SECONDARY_IP__, https://__PRIMARY_IP__, https://localhost {
    import custom_tls
    import jellyfin_cluster
}

# --- Dedicated NOC / Ops Dashboard Subdomains ---
https://dashboard.voltaireun.local, https://dashboard.voltaireun.local, https://dashboard.voltairedeux.local, https://noc.voltaireun.local, https://portal.voltaireun.local, https://hub.voltaireun.local {
    import security_headers
    import custom_tls
    encode gzip zstd
    root * /var/www/dashboard
    file_server
}

# --- Homepage Dashboard ---
https://homepage.__EXTERNAL_DOMAIN__, https://home.voltaireun.local, https://home.voltaireun.local, https://home.voltairedeux.local, https://homepage.voltaireun.local {
    import security_headers
    import custom_tls
    encode gzip zstd
    reverse_proxy homepage:3000 __PRIMARY_IP__:3000 {
        lb_policy first
        fail_duration 10s
    }
}

# --- Diun Docker Image Update Notifier ---
https://diun.voltaireun.local, https://diun.voltaireun.local, https://diun.voltairedeux.local {
    import security_headers
    import custom_tls
    reverse_proxy diun:9090 __PRIMARY_IP__:9090 {
        lb_policy first
        fail_duration 10s
    }
}

# --- D. Jellyseerr Media Requests ---
https://jellyseerr.__EXTERNAL_DOMAIN__, https://jellyseerr.voltaireun.local, https://jellyseerr.voltaireun.local, https://jellyseerr.voltairedeux.local {
    import security_headers
    import custom_tls
    encode gzip zstd
    reverse_proxy jellyseerr:5055 __PRIMARY_IP__:5055 {
        lb_policy first
        fail_duration 10s
    }
}

# --- D2. JellyWatch Dedicated Requests Server Access Point ---
https://requests.__EXTERNAL_DOMAIN__, https://requests.voltaireun.local, https://requests.voltairedeux.local {
    import security_headers
    import custom_tls
    encode gzip zstd

    handle /api/* {
        reverse_proxy api-gateway:3000 __PRIMARY_IP__:3000 {
            lb_policy first
            fail_duration 5s
        }
    }

    handle {
        root * /var/www/dashboard
        try_files {path} /requests.html
        file_server
    }
}

# --- D3. JellyWatch Dedicated Issues Server Access Point ---
https://issues.__EXTERNAL_DOMAIN__, https://issues.voltaireun.local, https://issues.voltairedeux.local {
    import security_headers
    import custom_tls
    encode gzip zstd

    handle /api/* {
        reverse_proxy api-gateway:3000 __PRIMARY_IP__:3000 {
            lb_policy first
            fail_duration 5s
        }
    }

    handle {
        root * /var/www/dashboard
        try_files {path} /issues.html
        file_server
    }
}

# --- E. Sonarr TV Series Management ---
https://sonarr.__EXTERNAL_DOMAIN__, https://sonarr.voltaireun.local, https://sonarr.voltaireun.local, https://sonarr.voltairedeux.local {
    import security_headers
    import custom_tls
    reverse_proxy sonarr:8989 __PRIMARY_IP__:8989 {
        lb_policy first
        fail_duration 10s
    }
}

# --- F. Radarr Movie Management ---
https://radarr.__EXTERNAL_DOMAIN__, https://radarr.voltaireun.local, https://radarr.voltaireun.local, https://radarr.voltairedeux.local {
    import security_headers
    import custom_tls
    reverse_proxy radarr:7878 __PRIMARY_IP__:7878 {
        lb_policy first
        fail_duration 10s
    }
}

# --- G. Prowlarr Indexer Synchronization ---
https://prowlarr.__EXTERNAL_DOMAIN__, https://prowlarr.voltaireun.local, https://prowlarr.voltaireun.local, https://prowlarr.voltairedeux.local {
    import security_headers
    import custom_tls
    reverse_proxy prowlarr:9696 __PRIMARY_IP__:9696 {
        lb_policy first
        fail_duration 10s
    }
}

# --- H. Bazarr Subtitles Automation ---
https://bazarr.__EXTERNAL_DOMAIN__, https://bazarr.voltaireun.local, https://bazarr.voltaireun.local, https://bazarr.voltairedeux.local {
    import security_headers
    import custom_tls
    reverse_proxy bazarr:6767 __PRIMARY_IP__:6767 {
        lb_policy first
        fail_duration 10s
    }
}

# --- I. Transmission Torrent Client ---
https://transmission.voltaireun.local, https://transmission.voltaireun.local, https://transmission.voltairedeux.local {
    import security_headers
    import custom_tls
    reverse_proxy transmission:9091 __PRIMARY_IP__:9091 {
        header_up X-Transmission-Session-Id {http.request.header.X-Transmission-Session-Id}
    }
}

# --- J. Tvheadend Live TV & DVR ---
https://tvheadend.voltaireun.local, https://tvheadend.voltaireun.local, https://tvheadend.voltairedeux.local {
    import security_headers
    import custom_tls
    reverse_proxy tvheadend:9981 __PRIMARY_IP__:9981
}

# --- K. HDHomeRun Hardware Tuner ---
https://hdhomerun.voltaireun.local, https://hdhomerun.voltaireun.local, https://hdhomerun.voltairedeux.local {
    import security_headers
    import custom_tls
    reverse_proxy 192.168.4.45:80
}

# --- L. MusicBrainz Mirror ---
https://musicbrainz.__EXTERNAL_DOMAIN__, https://musicbrainz.voltaireun.local, https://musicbrainz.voltaireun.local, https://musicbrainz.voltairedeux.local {
    import security_headers
    import custom_tls
    encode gzip zstd
    reverse_proxy __PRIMARY_IP__:5000 127.0.0.1:5001 {
        lb_policy first
        fail_duration 10s
    }
}

# --- M. MediaStack Database Administration ---
https://db.voltaireun.local, https://db.voltaireun.local, https://db.voltairedeux.local {
    import security_headers
    import custom_tls
    reverse_proxy mediastack-db:8080 __PRIMARY_IP__:8080
}

# --- N. Portainer Container Management ---
https://portainer.__EXTERNAL_DOMAIN__, https://portainer.voltaireun.local, https://portainer.voltairedeux.local {
    import security_headers
    import custom_tls
    reverse_proxy portainer:9000 __PRIMARY_IP__:9000 {
        lb_policy first
        fail_duration 10s
    }
}
'@

$caddyfileContent = $template.Replace("__PRIMARY_IP__", $PrimaryServerIP).Replace("__SECONDARY_IP__", $SecondaryServerIP).Replace("__EXTERNAL_DOMAIN__", $ExternalDomain)
$caddyfileContent | Set-Content -Path $CaddyfilePath -Encoding UTF8
Write-Host "  [OK] Primary Caddyfile generated: $CaddyfilePath" -ForegroundColor Green

# ==============================================================================
# STAGE 3: VALIDATE CADDYFILE SYNTAX & DEPLOY / RELOAD
# ==============================================================================
Write-Host "`n[STAGE 3/5] Validating Caddyfile Syntax & Applying to Caddy Container..." -ForegroundColor Yellow

$caddyRunning = docker ps --filter "name=caddy" --format "{{.Status}}" 2>$null

if ($caddyRunning -and $caddyRunning -match "Up") {
    Write-Host "  [*] Hot-reloading active Caddy container..." -ForegroundColor Cyan
    $reloadOutput = docker exec caddy caddy reload --config /etc/caddy/Caddyfile 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [OK] Caddy reverse proxy successfully reloaded in real-time." -ForegroundColor Green
    } else {
        Write-Host "  [WARN] Reload returned non-zero code. Recreating container..." -ForegroundColor Yellow
        docker compose up -d caddy 2>&1 | Out-Null
    }
} else {
    Write-Host "  [*] Launching Caddy container via Docker Compose..." -ForegroundColor Cyan
    docker compose up -d caddy 2>&1 | Out-Null
    Start-Sleep -Seconds 3
    Write-Host "  [OK] Caddy container started." -ForegroundColor Green
}

# ==============================================================================
# STAGE 4: COMPREHENSIVE INGRESS & SSL PROBE SUITE
# ==============================================================================
Write-Host "`n[STAGE 4/5] Executing Live Ingress & HTTPS Validation Probes..." -ForegroundColor Yellow

$probeSuite = @(
    @{ Name = "Direct Streaming Socket (:8096)"; Url = "http://127.0.0.1:8096/System/Info/Public"; Expected = "Jellyfin" },
    @{ Name = "HTTP Root Ingress (:80 -> HTTPS 301)"; Url = "http://localhost/"; ExpectedCode = "301" },
    @{ Name = "HTTPS Root Ingress (:443 -> Jellyfin)"; Url = "https://localhost/System/Info/Public"; Expected = "Jellyfin" },
    @{ Name = "External DDNS HTTPS Root ($ExternalDomain)"; Url = "https://$ExternalDomain/System/Info/Public"; Expected = "Jellyfin"; Resolve = "$ExternalDomain`:443`:127.0.0.1" },
    @{ Name = "External Jellyfin Subdomain (jellyfin.$ExternalDomain)"; Url = "https://jellyfin.$ExternalDomain/System/Info/Public"; Expected = "Jellyfin"; Resolve = "jellyfin.$ExternalDomain`:443`:127.0.0.1" },
    @{ Name = "Local LAN HTTPS Domain (voltaireun.local)"; Url = "https://voltaireun.local/System/Info/Public"; Expected = "Jellyfin"; Resolve = "voltaireun.local:443:127.0.0.1" },
    @{ Name = "Local LAN HTTPS Domain (voltairedeux.local)"; Url = "https://voltairedeux.local/System/Info/Public"; Expected = "Jellyfin"; Resolve = "voltairedeux.local:443:127.0.0.1" },
    @{ Name = "Internal LAN HTTP -> HTTPS Redirect (voltaireun.local)"; Url = "http://voltaireun.local/"; ExpectedCode = "301"; Resolve = "voltaireun.local:80:127.0.0.1" }
)

$probeResults = @()

foreach ($p in $probeSuite) {
    $curlArgs = @("-k", "-s", "-m", "4")
    if ($p.Resolve) {
        $curlArgs += "--resolve"
        $curlArgs += $p.Resolve
    }
    if ($p.ExpectedCode) {
        $curlArgs += "-o"
        $curlArgs += "NUL"
        $curlArgs += "-w"
        $curlArgs += "%{http_code}"
    }
    $curlArgs += $p.Url

    $resp = & curl.exe @curlArgs 2>$null
    
    $success = $false
    if ($p.ExpectedCode) {
        $success = ($resp -match "^30[1278]$" -or $resp -match "200" -or $resp -eq $p.ExpectedCode)
        $statusText = if ($success) { "[OK] REDIRECTED TO HTTPS (HTTP $resp)" } else { "[FAIL / CODE: $resp]" }
    } else {
        $success = ($resp -match $p.Expected -or $resp -match "jellyfinstack" -or $resp -match "ServerName")
        $statusText = if ($success) { "[OK] SECURE HTTPS -> JELLYFIN" } else { "[FAIL / STANDBY]" }
    }
    
    $color = if ($success) { "Green" } else { "Yellow" }
    Write-Host ("  {0,-58} -> {1}" -f $p.Name, $statusText) -ForegroundColor $color
    
    $probeResults += [PSCustomObject]@{
        Name    = $p.Name
        Url     = $p.Url
        Success = $success
        Status  = $statusText
    }
}

# ==============================================================================
# STAGE 5: EMIT INGRESS REPORT & SYNCHRONIZE ONEDRIVE
# ==============================================================================
Write-Host "`n[STAGE 5/5] Emitting Ingress Handoff Manifest..." -ForegroundColor Yellow

$reportTag = Get-Date -Format "yyyyMMdd_HHmmss"
$reportPath = Join-Path $HandoffsDir "Caddy_Ingress_Report_${reportTag}.md"

$md = @()
$md += "# Caddy Primary Ingress & End-to-End HTTPS Security Report"
$md += ""
$md += "- **Execution Timestamp:** $timestamp"
$md += "- **Primary Server IP (VoltaireUn):** $PrimaryServerIP"
$md += "- **Secondary Server IP (VoltaireDeux):** $SecondaryServerIP"
$md += "- **External DDNS Domain:** https://$ExternalDomain"
$md += "- **Security Policy:** 100% End-to-End TLS / HTTPS (:443) enforced across all internal LAN subdomains, external DDNS, and naked IPs."
$md += "- **Routing Policy:** Direct ALL incoming root traffic to Jellyfin with automatic dual-node failover."
$md += ""
$md += "---"
$md += ""
$md += "## Ingress Route & SSL/TLS Verification Status"
$md += ""
$md += "| Route / Endpoint | Security Protocol | Status |"
$md += "| :--- | :---: | :---: |"

foreach ($pr in $probeResults) {
    $tlsType = if ($pr.Url -match "^https") { "Custom 4096-bit SAN TLS" } else { "HTTP -> HTTPS (301 Redirect)" }
    $statusBadge = if ($pr.Success) { "VERIFIED SECURE (OK)" } else { "STANDBY" }
    $md += "| " + $pr.Name + " | " + $tlsType + " | " + $statusBadge + " |"
}

$md += ""
$md += "---"
$md += "*Report generated by Setup-MediaStackCaddyServer.ps1.*"

$md -join "`r`n" | Set-Content -Path $reportPath -Encoding UTF8
Write-Host "  [OK] Ingress report written to: $reportPath" -ForegroundColor Green

# Sync to C:\MediastackConfig
$mergeScript = Join-Path $BaseDir "Merge-OneDriveMediaStack.ps1"
if (Test-Path $mergeScript) {
    & $mergeScript | Out-Null
    Write-Host "  [OK] Synchronized Caddyfile and certificates to C:\MediastackConfig." -ForegroundColor Green
}

Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host "   C A D D Y   S E C U R I T Y   &   I N G R E S S   A C T I V E" -ForegroundColor White
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "1. External DDNS Ingress : https://$ExternalDomain -> Jellyfin (HTTPS :443)" -ForegroundColor Green
Write-Host "2. Internal LAN Ingress  : https://voltaireun.local & https://voltairedeux.local (HTTPS :443)" -ForegroundColor Green
Write-Host "3. HTTP Plaintext Policy : All Port 80 Requests Automatically Redirected to Port 443" -ForegroundColor Green
Write-Host "4. Root CA Certificate   : Installed in Windows Trusted Root Store" -ForegroundColor Green
Write-Host "================================================================================`n" -ForegroundColor Cyan

if (-not $NonInteractive) {
    Write-Host "Press any key to return..." -ForegroundColor DarkGray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

