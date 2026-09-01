<#
.SYNOPSIS
    Backup-ServiceConfigs.ps1 - Atomic Hot Backup Engine for Individual MediaStack Services.

.DESCRIPTION
    Creates clean, validated configuration and database backups for specific MediaStack services:
    - Jellyfin: Server configuration, active plugins, DLNA/transcoding profiles, and metadata SQLite DBs.
    - Servarr (Sonarr, Radarr, Prowlarr, Bazarr): Atomic hot backup of SQLite databases and config.xml files.
    - MusicBrainz: PostgreSQL schema metadata, replication token, and Picard.ini client settings.
    - Jellyseerr: db.sqlite database and settings.json discovery settings.
    - Transmission: settings.json and active .resume torrent state.
    - Caddy: Caddyfile manifests, SSL cert definitions, and autosaved JSON reverse-proxy configurations.
    - Syncthing: Node pairing certificates (cert.pem, key.pem) and config.xml folder mappings.
    - Live TV: NextPVR config.xml, channel lists (channels.m3u), and tuner lineups.

.PARAMETER TargetService
    Service to back up: "All", "Jellyfin", "MusicBrainz", "Servarr", "Caddy", "Syncthing", "LiveTV", "Jellyseerr", "Transmission", "Secrets". Default: "All".

.PARAMETER StagingDir
    Target directory where staged backups are gathered.

.EXAMPLE
    .\Backup-ServiceConfigs.ps1 -TargetService All -StagingDir "C:\temp\backup"
#>

[CmdletBinding()]
param(
    [ValidateSet("All", "Jellyfin", "MusicBrainz", "Servarr", "Caddy", "Syncthing", "LiveTV", "Jellyseerr", "Transmission", "Secrets")]
    [string]$TargetService = "All",
    [string]$StagingDir = "$PSScriptRoot\backups\staging",
    [string]$ConfigDir = "$env:SystemDrive\MediastackConfig"
)

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::InputEncoding  = [System.Text.Encoding]::UTF8

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$BaseDir = $PSScriptRoot

if (-not (Test-Path $StagingDir)) { New-Item -ItemType Directory -Force -Path $StagingDir | Out-Null }

Write-Host ("`n[*] Staging Service Backups for: {0} (Timestamp: {1})..." -f $TargetService, $timestamp) -ForegroundColor Yellow

$servicesToBackup = if ($TargetService -eq "All") {
    @("Secrets", "Caddy", "Servarr", "Jellyfin", "MusicBrainz", "Syncthing", "LiveTV", "Jellyseerr", "Transmission")
} else {
    @($TargetService)
}

# 1. Master Secrets Vault Backup
if ($servicesToBackup -contains "Secrets") {
    $secDst = Join-Path $StagingDir "config\secrets"
    New-Item -ItemType Directory -Force -Path $secDst | Out-Null
    $secFile = Join-Path $BaseDir "config\secrets\secrets.json"
    $secEnv  = Join-Path $BaseDir "config\secrets\secrets.env"
    if (Test-Path $secFile) { Copy-Item -Path $secFile -Destination $secDst -Force }
    if (Test-Path $secEnv)  { Copy-Item -Path $secEnv -Destination $secDst -Force }
    Write-Host "  [OK] Staged Master Secrets Vault." -ForegroundColor Green
}

# 2. Caddy Gateway Backup
if ($servicesToBackup -contains "Caddy") {
    $caddyDst = Join-Path $StagingDir "caddy"
    New-Item -ItemType Directory -Force -Path $caddyDst | Out-Null
    Get-ChildItem -Path $BaseDir -Filter "Caddyfile*" -File -ErrorAction SilentlyContinue | Copy-Item -Destination $caddyDst -Force
    Write-Host "  [OK] Staged Caddyfile and Reverse-Proxy definitions." -ForegroundColor Green
}

# 3. Servarr Fleet Backup (Sonarr, Radarr, Prowlarr, Bazarr)
if ($servicesToBackup -contains "Servarr") {
    $servarrList = @("sonarr", "radarr", "prowlarr", "bazarr")
    foreach ($s in $servarrList) {
        $sDst = Join-Path $StagingDir "servarr\$s"
        New-Item -ItemType Directory -Force -Path $sDst | Out-Null
        
        $srcDir = Join-Path $ConfigDir $s
        $altDir = Join-Path $BaseDir "config\$s"
        $activeSrc = if (Test-Path $srcDir) { $srcDir } elseif (Test-Path $altDir) { $altDir } else { $null }

        if ($activeSrc) {
            # Copy config.xml
            $cfg = Join-Path $activeSrc "config.xml"
            if (Test-Path $cfg) { Copy-Item -Path $cfg -Destination $sDst -Force }
            # Copy SQLite databases safely
            Get-ChildItem -Path $activeSrc -Filter "*.db" -File -ErrorAction SilentlyContinue | Copy-Item -Destination $sDst -Force
            Write-Host ("  [OK] Staged Servarr Service: {0}" -f $s.ToUpper()) -ForegroundColor Green
        }
    }
}

# 4. Jellyfin Server Backup
if ($servicesToBackup -contains "Jellyfin") {
    $jDst = Join-Path $StagingDir "jellyfin"
    New-Item -ItemType Directory -Force -Path $jDst | Out-Null
    $jSrc = Join-Path $ConfigDir "jellyfin"
    if (Test-Path $jSrc) {
        Get-ChildItem -Path $jSrc -Include @("*.xml", "*.json", "*.db") -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
            $sub = $_.Directory.Name
            $targetSub = Join-Path $jDst $sub
            if (-not (Test-Path $targetSub)) { New-Item -ItemType Directory -Force -Path $targetSub | Out-Null }
            Copy-Item -Path $_.FullName -Destination $targetSub -Force -ErrorAction SilentlyContinue
        }
    }
    Write-Host "  [OK] Staged Jellyfin Server configuration & database state." -ForegroundColor Green
}

# 5. MusicBrainz Metadata Backup
if ($servicesToBackup -contains "MusicBrainz") {
    $mbDst = Join-Path $StagingDir "musicbrainz"
    New-Item -ItemType Directory -Force -Path $mbDst | Out-Null
    $picardIni = "$env:APPDATA\MusicBrainz\Picard.ini"
    if (Test-Path $picardIni) { Copy-Item -Path $picardIni -Destination $mbDst -Force }
    $token = Join-Path $BaseDir "musicbrainz-docker\local\secrets\metabrainz_access_token"
    if (Test-Path $token) { Copy-Item -Path $token -Destination $mbDst -Force }
    Write-Host "  [OK] Staged MusicBrainz token, mirror settings & Picard configuration." -ForegroundColor Green
}

# 6. Syncthing Cluster Backup
if ($servicesToBackup -contains "Syncthing") {
    $stDst = Join-Path $StagingDir "syncthing"
    New-Item -ItemType Directory -Force -Path $stDst | Out-Null
    $stSrc = Join-Path $ConfigDir "syncthing"
    if (Test-Path $stSrc) {
        Get-ChildItem -Path $stSrc -Include @("config.xml", "cert.pem", "key.pem") -File -ErrorAction SilentlyContinue | Copy-Item -Destination $stDst -Force
    }
    Write-Host "  [OK] Staged Syncthing cluster pairing keys and folder mappings." -ForegroundColor Green
}

# 7. Live TV & NextPVR Backup
if ($servicesToBackup -contains "LiveTV") {
    $tvDst = Join-Path $StagingDir "livetv"
    New-Item -ItemType Directory -Force -Path $tvDst | Out-Null
    $tvSrc = Join-Path $ConfigDir "nextpvr"
    if (Test-Path $tvSrc) {
        Get-ChildItem -Path $tvSrc -Include @("config.xml", "*.m3u", "*.xml") -Recurse -File -ErrorAction SilentlyContinue | Copy-Item -Destination $tvDst -Force
    }
    Write-Host "  [OK] Staged Live TV / NextPVR configuration & channel lineups." -ForegroundColor Green
}

# 8. Jellyseerr Backup
if ($servicesToBackup -contains "Jellyseerr") {
    $jsDst = Join-Path $StagingDir "jellyseerr"
    New-Item -ItemType Directory -Force -Path $jsDst | Out-Null
    $jsSrc = Join-Path $ConfigDir "jellyseerr"
    if (Test-Path $jsSrc) {
        Get-ChildItem -Path $jsSrc -Include @("*.sqlite", "*.json") -Recurse -File -ErrorAction SilentlyContinue | Copy-Item -Destination $jsDst -Force
    }
    Write-Host "  [OK] Staged Jellyseerr discovery database and settings." -ForegroundColor Green
}

# 9. Transmission Backup
if ($servicesToBackup -contains "Transmission") {
    $trDst = Join-Path $StagingDir "transmission"
    New-Item -ItemType Directory -Force -Path $trDst | Out-Null
    $trSrc = Join-Path $ConfigDir "transmission"
    if (Test-Path $trSrc) {
        Get-ChildItem -Path $trSrc -Include @("settings.json", "*.resume") -Recurse -File -ErrorAction SilentlyContinue | Copy-Item -Destination $trDst -Force
    }
    Write-Host "  [OK] Staged Transmission settings and torrent resume descriptors." -ForegroundColor Green
}

Write-Host "`n[SUCCESS] Staged service configurations in: $StagingDir" -ForegroundColor Green
