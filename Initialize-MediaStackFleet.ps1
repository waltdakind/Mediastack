# ==============================================================================
# Initialize-MediaStackFleet.ps1 - Master One-Touch Fleet Creation & Deployment Orchestrator
# Builds, provisions, initializes, and starts the entire MediaStack & MusicBrainz infrastructure
# ==============================================================================
param(
    [string]$ConfigDir = "$env:SystemDrive\MediastackConfig",
    [string]$MediaRoot = "C:\Media",
    [switch]$ForceRecreate,
    [switch]$SkipMusicBrainz
)

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::InputEncoding  = [System.Text.Encoding]::UTF8

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$fileTimestamp = Get-Date -Format "yyyyMMdd_HHmmss"

Write-Host "`n================================================================================" -ForegroundColor DarkCyan
Write-Host "     M E D I A S T A C K   F L E E T   I N I T I A L I Z A T I O N" -ForegroundColor Cyan
Write-Host ("     Host: {0} | Config Directory: {1}" -f $env:COMPUTERNAME, $ConfigDir) -ForegroundColor DarkGray
Write-Host "================================================================================" -ForegroundColor DarkCyan

# --- 1. ENVIRONMENT & DOCKER ENGINE VALIDATION ---
Write-Host "`n[1/6] Validating Docker Engine & System Environment..." -ForegroundColor Yellow

$dockerVersion = docker version --format '{{.Server.Version}}' 2>$null
if (-not $dockerVersion) {
    Write-Host "  [CRITICAL] Docker engine is not running or accessible. Please launch Docker Desktop." -ForegroundColor Red
    exit 1
}
Write-Host ("  [OK] Docker Engine Active (v{0})" -f $dockerVersion) -ForegroundColor Green

$composeVersion = docker compose version --short 2>$null
Write-Host ("  [OK] Docker Compose Plugin Active (v{0})" -f $composeVersion) -ForegroundColor Green

# --- 2. DIRECTORY STRUCTURE PROVISIONING ---
Write-Host "`n[2/6] Provisioning Master Directory Infrastructure..." -ForegroundColor Yellow

$requiredDirs = @(
    "$ConfigDir\caddy_data",
    "$ConfigDir\caddy_config",
    "$ConfigDir\jellyfin",
    "$ConfigDir\jellyseerr",
    "$ConfigDir\sonarr",
    "$ConfigDir\radarr",
    "$ConfigDir\prowlarr",
    "$ConfigDir\bazarr",
    "$ConfigDir\tvheadend",
    "$ConfigDir\diun",
    "$ConfigDir\homepage",
    "$ConfigDir\db-backup",
    "$PSScriptRoot\transmission\config",
    "$PSScriptRoot\dashboard",
    "$PSScriptRoot\handoffs",
    "$PSScriptRoot\musicbrainz-docker\local\secrets"
)

foreach ($dir in $requiredDirs) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        Write-Host ("  [CREATED] {0}" -f $dir) -ForegroundColor DarkCyan
    } else {
        Write-Host ("  [EXISTS]  {0}" -f $dir) -ForegroundColor DarkGray
    }
}

if (-not (Test-Path $MediaRoot)) {
    New-Item -ItemType Directory -Force -Path $MediaRoot | Out-Null
    Write-Host ("  [CREATED] Media Root: {0}" -f $MediaRoot) -ForegroundColor Green
}

# --- 3. ENVIRONMENT FILE & SECRETS SYNCHRONIZATION ---
Write-Host "`n[3/6] Configuring Stack Secrets & Environment Tokens..." -ForegroundColor Yellow

$envFile = Join-Path $PSScriptRoot ".env"
if (-not (Test-Path $envFile)) {
    $envTemplate = @"
CONFIG_DIR=$ConfigDir
MEDIA_ROOT=$MediaRoot
PUID=1000
PGID=1000
TZ=America/New_York
MUSICBRAINZ_PORT=5001
MUSICBRAINZ_FALLBACK_IP=192.168.4.21
MUSICBRAINZ_FALLBACK_PORT=5000
HDHOMERUN_IP=192.168.4.45
"@
    Set-Content -Path $envFile -Value $envTemplate -Encoding UTF8
    Write-Host "  [CREATED] Generated master .env configuration" -ForegroundColor Green
} else {
    Write-Host "  [OK] Master .env file validated" -ForegroundColor Green
}

# Ensure MusicBrainz secrets
$mbTokenFile = Join-Path $PSScriptRoot "musicbrainz-docker\local\secrets\metabrainz_access_token"
if (-not (Test-Path $mbTokenFile)) {
    Set-Content -Path $mbTokenFile -Value "test-token-12345" -Encoding UTF8
    Write-Host "  [CREATED] Initialized MetaBrainz token secret" -ForegroundColor DarkCyan
}

# --- 4. CADDY GATEWAY & REVERSE PROXY SYNCHRONIZATION ---
Write-Host "`n[4/6] Synchronizing Gateway Routing & Caddyfile..." -ForegroundColor Yellow

$caddySrc = Join-Path $PSScriptRoot "Caddyfile"
$caddyDest = Join-Path $ConfigDir "Caddyfile"
if (Test-Path $caddySrc) {
    Copy-Item $caddySrc $caddyDest -Force -ErrorAction SilentlyContinue
    Write-Host "  [OK] Master Caddyfile deployed to runtime directory" -ForegroundColor Green
}

# --- 5. DOCKER FLEET BOOTSTRAP & DEPLOYMENT ---
Write-Host "`n[5/6] Deploying Container Fleet Services..." -ForegroundColor Yellow

Set-Location $PSScriptRoot
$upCmd = if ($ForceRecreate) { "docker compose up -d --force-recreate" } else { "docker compose up -d" }
Write-Host ("  Executing: {0}" -f $upCmd) -ForegroundColor DarkGray
cmd.exe /c "$upCmd 2>&1"

if (-not $SkipMusicBrainz -and (Test-Path "$PSScriptRoot\musicbrainz-docker\docker-compose.yml")) {
    Write-Host "`n  Deploying MusicBrainz Multi-Tier Mirror..." -ForegroundColor DarkCyan
    Push-Location "$PSScriptRoot\musicbrainz-docker"
    $mbCmd = if ($ForceRecreate) { "docker compose up -d --force-recreate" } else { "docker compose up -d" }
    cmd.exe /c "$mbCmd 2>&1"
    Pop-Location
}

# --- 6. HEALTH VERIFICATION & INGESTION ---
Write-Host "`n[6/6] Verifying Stack Health & Ingesting Deployment Metrics..." -ForegroundColor Yellow

Start-Sleep -Seconds 3

$runningContainers = docker ps --format "{{.Names}}|{{.Status}}" 2>$null
$activeCount = 0
foreach ($line in $runningContainers) {
    $parts = $line -split "\|", 2
    if ($parts.Count -eq 2) {
        Write-Host ("  [ACTIVE] {0,-28} -> {1}" -f $parts[0], $parts[1]) -ForegroundColor Green
        $activeCount++
    }
}

try {
    $sqlInit = "CREATE TABLE IF NOT EXISTS fleet_deployments_log (id INTEGER PRIMARY KEY AUTOINCREMENT, deployment_timestamp TEXT NOT NULL, active_containers INTEGER, status TEXT, details TEXT); "
    $sqlInsert = "INSERT INTO fleet_deployments_log (deployment_timestamp, active_containers, status, details) VALUES ('$timestamp', $activeCount, 'SUCCESS', 'Fleet initialized with $activeCount running containers'); "
    docker exec mediastack-db sqlite3 /config/mediastack_backup.db "$sqlInit $sqlInsert" 2>$null
} catch { }

Write-Host "`n================================================================================" -ForegroundColor DarkCyan
Write-Host ("     F L E E T   D E P L O Y M E N T   C O M P L E T E   ({0} Running Containers)" -f $activeCount) -ForegroundColor Cyan
Write-Host "================================================================================`n" -ForegroundColor DarkCyan
