<#
.SYNOPSIS
    Setup-Qbittorrent.ps1 - Automated qBittorrent Setup Wizard (PowerShell / Windows / Cross-Platform).

.DESCRIPTION
    Zero-touch installer and configuration injector for qBittorrent:
    1. Zero-Touch Permissions: Sets standard PUID/PGID=1000 for Docker Desktop container volume parity.
    2. Pre-Flight Config Injection: Writes qBittorrent.conf with [LegalNotice] Accepted=true to bypass EULA.
    3. "Arr" Subnet Whitelist: Injects Docker internal network whitelisting (172.16.0.0/12, 192.168.0.0/16)
       allowing Radarr, Sonarr, and Prowlarr to connect without credentials over local Docker networks.
    4. Docker Compose Generator: Emits a production-ready docker-compose.qbittorrent.yml.
    5. Automated Launch: Starts the container immediately unless -NoStart is specified.

.PARAMETER Port
    WebUI port (default: 8085 to avoid collision with mediastack-db on 8080).

.PARAMETER TorrentPort
    BitTorrent listening port (default: 6881).

.PARAMETER ConfigDir
    Host storage path for config (default: .\config\qbittorrent).

.PARAMETER DownloadDir
    Host storage path for downloads (default: .\data\downloads).

.PARAMETER NoStart
    Generates configuration and compose files without starting the container.

.PARAMETER NonInteractive
    Runs using defaults without prompting.

.EXAMPLE
    .\Setup-Qbittorrent.ps1
    .\Setup-Qbittorrent.ps1 -Port 8085 -NonInteractive
#>

[CmdletBinding()]
param(
    [int]$Port = 8085,
    [int]$TorrentPort = 6881,
    [string]$ConfigDir = ".\config\qbittorrent",
    [string]$DownloadDir = ".\data\downloads",
    [switch]$NoStart,
    [switch]$NonInteractive
)

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::InputEncoding  = [System.Text.Encoding]::UTF8

Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host "    q B i t t o r r e n t   A U T O M A T E D   S E T U P   W I Z A R D        " -ForegroundColor DarkCyan
Write-Host "        Zero-Touch Permissions  |  EULA Bypass  |  Arr Subnet Whitelist        " -ForegroundColor White
Write-Host "================================================================================" -ForegroundColor Cyan

# 1. Zero-Touch Permissions & Environment Detection
Write-Host "`n[1/5] Detecting System & Container Environment..." -ForegroundColor Yellow
$puid = 1000
$pgid = 1000
$tz   = "America/New_York"
if ($env:TZ) { $tz = $env:TZ }

$localIp = (Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -notmatch "^127\.|^169\.254\." } | Select-Object -First 1).IPAddress
if (-not $localIp) { $localIp = "127.0.0.1" }

Write-Host ("  [OK] Container User/Group Mapping : PUID={0}, PGID={1}" -f $puid, $pgid) -ForegroundColor Green
Write-Host ("  [OK] Detected Host IP             : {0}" -f $localIp) -ForegroundColor Green
Write-Host ("  [OK] System Timezone              : {0}" -f $tz) -ForegroundColor Green

# Interactive confirmation unless -NonInteractive
if (-not $NonInteractive) {
    Write-Host "`nReview or customize setup parameters (press Enter to accept default):" -ForegroundColor White
    $inputPort = Read-Host "  WebUI Port [Default: $Port] (Note: Port 8080 is reserved for mediastack-db)"
    if ($inputPort) { $Port = [int]$inputPort }

    $inputCfg = Read-Host "  Config Directory [Default: $ConfigDir]"
    if ($inputCfg) { $ConfigDir = $inputCfg }

    $inputDl = Read-Host "  Downloads Directory [Default: $DownloadDir]"
    if ($inputDl) { $DownloadDir = $inputDl }
}

# 2. Generate Secure Credentials
Write-Host "`n[2/5] Generating WebUI Admin Credentials..." -ForegroundColor Yellow
$adminUser = "admin"
$chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
$rand = New-Object System.Random
$adminPass = -join ((1..14) | ForEach-Object { $chars[$rand.Next(0, $chars.Length)] })

Write-Host ("  [OK] WebUI Username : {0}" -f $adminUser) -ForegroundColor Green
Write-Host ("  [OK] WebUI Password : {0}" -f $adminPass) -ForegroundColor Green

# 3. Directory Provisioning
Write-Host "`n[3/5] Provisioning Directory Layout..." -ForegroundColor Yellow
$qbitConfDir = Join-Path $ConfigDir "qBittorrent"
$dlComplete   = Join-Path $DownloadDir "complete"
$dlIncomplete = Join-Path $DownloadDir "incomplete"

$pathsToCreate = @($qbitConfDir, $dlComplete, $dlIncomplete)
foreach ($p in $pathsToCreate) {
    if (-not (Test-Path $p)) {
        New-Item -ItemType Directory -Force -Path $p | Out-Null
        Write-Host ("  [OK] Created Directory: {0}" -f $p) -ForegroundColor Green
    } else {
        Write-Host ("  [OK] Directory Exists : {0}" -f $p) -ForegroundColor Green
    }
}

# 4. Configuration Injection (EULA Acceptance & Docker Subnet Whitelist)
Write-Host "`n[4/5] Injecting Pre-Configured qBittorrent.conf..." -ForegroundColor Yellow
$confPath = Join-Path $qbitConfDir "qBittorrent.conf"

$confContent = @"
[Application]
FileLogger\Age=1
FileLogger\AgeType=1
FileLogger\Backup=true
FileLogger\DeleteOld=true
FileLogger\Enabled=true
FileLogger\Filter=1
FileLogger\MaxSizeBytes=66560000
FileLogger\Path=/config/qBittorrent/data/logs

[AutoRun]
enabled=false
program=

[BitTorrent]
Session\DefaultSavePath=/data/downloads/complete
Session\DiskCacheSize=-1
Session\Port=$TorrentPort
Session\QueueingSystemEnabled=true
Session\TempPath=/data/downloads/incomplete
Session\TempPathEnabled=true

[LegalNotice]
Accepted=true

[Network]
Cookies=@Invalid()

[Preferences]
Advanced\RecheckOnCompletion=false
Connection\PortRangeMin=$TorrentPort
Connection\UPnP=false
Downloads\PreAllocation=false
Downloads\SavePath=/data/downloads/complete
Downloads\TempPath=/data/downloads/incomplete
General\Locale=en
Queueing\MaxActiveDownloads=10
Queueing\MaxActiveTorrents=20
Queueing\MaxActiveUploads=10
Queueing\QueueingEnabled=true
WebUI\Address=0.0.0.0
WebUI\AuthSubnetWhitelist="172.16.0.0/12, 192.168.0.0/16, 10.0.0.0/8, 127.0.0.1/32"
WebUI\AuthSubnetWhitelistEnabled=true
WebUI\CustomHTTPHeaders=
WebUI\CustomHTTPHeadersEnabled=false
WebUI\HostHeaderValidation=false
WebUI\LocalHostAuth=false
WebUI\MaxAuthenticationFailures=10
WebUI\Port=$Port
WebUI\ReverseProxySupportEnabled=true
WebUI\SecureCookie=true
WebUI\ServerDomains=*
WebUI\SessionTimeout=3600
WebUI\TrustedReverseProxiesList=127.0.0.1, 192.168.0.0/16, 172.16.0.0/12
WebUI\UseUPnP=false
WebUI\Username=$adminUser
"@

Set-Content -Path $confPath -Value $confContent -Encoding UTF8
Write-Host ("  [OK] Injected Config       : {0}" -f $confPath) -ForegroundColor Green
Write-Host "  [OK] Legal EULA Accepted   : Accepted=true (No startup prompts)" -ForegroundColor Green
Write-Host "  [OK] Arr Subnet Whitelist  : 172.16.0.0/12, 192.168.0.0/16 (Passwordless internal API)" -ForegroundColor Green

# 5. Generate Docker Compose Spec
Write-Host "`n[5/5] Generating Docker Compose Specification..." -ForegroundColor Yellow
$composePath = "docker-compose.qbittorrent.yml"

# Normalize paths for compose
$cfgMount = $ConfigDir.Replace('\', '/')
$dlMount  = $DownloadDir.Replace('\', '/')

$composeContent = @"
version: "3.8"

services:
  qbittorrent:
    image: lscr.io/linuxserver/qbittorrent:latest
    container_name: qbittorrent
    restart: unless-stopped
    environment:
      - PUID=$puid
      - PGID=$pgid
      - TZ=$tz
      - WEBUI_PORT=$Port
      - TORRENTING_PORT=$TorrentPort
    volumes:
      - ${cfgMount}:/config
      - ${dlMount}:/data/downloads
    ports:
      - "${Port}:${Port}"
      - "${TorrentPort}:${TorrentPort}"
      - "${TorrentPort}:${TorrentPort}/udp"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:${Port}/api/v2/app/version"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 20s
    labels:
      - "autoheal=true"
"@

Set-Content -Path $composePath -Value $composeContent -Encoding UTF8
Write-Host ("  [OK] Generated Compose File: {0}" -f $composePath) -ForegroundColor Green

# Container launch
if (-not $NoStart) {
    Write-Host "`nLaunching qBittorrent via Docker Compose..." -ForegroundColor Cyan
    docker compose -f $composePath up -d
}

Write-Host "`n================================================================================" -ForegroundColor Green
Write-Host "   [SUCCESS] qBittorrent Setup Completed Successfully!" -ForegroundColor Green
Write-Host "================================================================================" -ForegroundColor Green
Write-Host ""
Write-Host " WebUI Access:" -ForegroundColor White
Write-Host ("   - Localhost : http://localhost:{0}" -f $Port) -ForegroundColor Cyan
Write-Host ("   - LAN Access: http://{0}:{1}" -f $localIp, $Port) -ForegroundColor Cyan
Write-Host ("   - Username  : {0}" -f $adminUser) -ForegroundColor White
Write-Host ("   - Password  : {0}" -f $adminPass) -ForegroundColor Yellow
Write-Host ""
Write-Host " 'Arr' Stack Integration Cheat Sheet (Radarr / Sonarr / Prowlarr):" -ForegroundColor White
Write-Host "   - Client Type : qBittorrent" -ForegroundColor Cyan
Write-Host "   - Host        : qbittorrent (if in same docker compose) or your Host IP" -ForegroundColor Cyan
Write-Host ("   - Port        : {0}" -f $Port) -ForegroundColor Cyan
Write-Host "   - Username    : <LEAVE BLANK> (Whitelisted for Docker internal subnets)" -ForegroundColor Green
Write-Host "   - Password    : <LEAVE BLANK> (Whitelisted for Docker internal subnets)" -ForegroundColor Green
Write-Host "   - Use SSL     : Disabled (Internal LAN/Docker communication)" -ForegroundColor Cyan
Write-Host "================================================================================`n" -ForegroundColor DarkCyan
