Write-Host "=== High-Availability Media Stack Installer ===" -ForegroundColor Cyan
Write-Host "Select your target CPU architecture:"
Write-Host "1. x64 (Standard Intel/AMD PC)"
Write-Host "2. arm (Raspberry Pi, ARM Servers, Apple Silicon)"

$valid = $false
while (-not $valid) {
    $archChoice = Read-Host "Enter 1 or 2"
    if ($archChoice.Trim() -eq '1') {
        $lsiTag = "amd64-latest"
        $valid = $true
        Write-Host "Selected architecture: x64 (amd64)" -ForegroundColor Green
    } elseif ($archChoice.Trim() -eq '2') {
        $lsiTag = "arm64v8-latest"
        $valid = $true
        Write-Host "Selected architecture: arm (arm64v8)" -ForegroundColor Green
    } else {
        Write-Host "Invalid choice, please enter 1 or 2." -ForegroundColor Red
    }
}

Write-Host "`nGenerating mediastack-ops.ps1..." -ForegroundColor Yellow

$CaddyFileString = @"
:80, :443, :8096 {
    reverse_proxy 192.168.4.21:8096 192.168.4.30:8096 {
        lb_policy first
        health_uri /health
        health_interval 10s
        header_up X-Real-IP {remote}
        header_up X-Forwarded-For {remote}
    }
}
:8080 {
    root * /var/www/dashboard
    file_server
}
"@

$ComposeFileString = @"
services:
  caddy:
    image: caddy:latest
    container_name: caddy
    ports:
      - "80:80"
      - "443:443"
      - "8096:8096"
      - "8080:8080"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - ./config/caddy_data:/data
      - ./config/caddy_config:/config
      - ./dashboard:/var/www/dashboard
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080"]
      interval: 30s
      timeout: 10s
      retries: 3
    labels:
      - "autoheal=true"

  jellyfin:
    image: lscr.io/linuxserver/jellyfin:__LSI_TAG__
    container_name: jellyfin
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/New_York
    volumes:
      - ./config/jellyfin:/config
      - ./media:/media
      - ./config/jellyfin/french-crime.m3u:/media/iptv/french-crime.m3u:ro
    ports:
      - 8097:8096
      - 8920:8920
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8096/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  jellyseerr:
    image: ghcr.io/seerr-team/seerr:v3.4.1
    container_name: jellyseerr
    environment:
      - LOG_LEVEL=debug
      - TZ=America/New_York
    ports:
      - 5055:5055
    volumes:
      - ./config/jellyseerr:/app/config
    restart: unless-stopped

  sonarr:
    image: lscr.io/linuxserver/sonarr:__LSI_TAG__
    container_name: sonarr
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/New_York
    volumes:
      - ./config/sonarr:/config
      - ./media/TV:/tv
      - ./downloads:/downloads
    ports:
      - 8989:8989
    restart: unless-stopped

  radarr:
    image: lscr.io/linuxserver/radarr:__LSI_TAG__
    container_name: radarr
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/New_York
    volumes:
      - ./config/radarr:/config
      - ./media/Movies:/movies
      - ./downloads:/downloads
    ports:
      - 7878:7878
    restart: unless-stopped

  jackett:
    image: lscr.io/linuxserver/jackett:__LSI_TAG__
    container_name: jackett
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/New_York
      - AUTO_UPDATE=true
    volumes:
      - ./config/jackett:/config
      - ./downloads:/downloads
    ports:
      - 9117:9117
    restart: unless-stopped
    sysctls:
      - net.ipv6.conf.all.disable_ipv6=1

  transmission:
    image: lscr.io/linuxserver/transmission:__LSI_TAG__
    container_name: transmission
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/New_York
    volumes:
      - ./config/transmission:/config
      - ./downloads:/downloads
      - ./downloads/watch:/watch
    ports:
      - 9091:9091
      - 51413:51413
      - 51413:51413/udp
    restart: unless-stopped

  bazarr:
    image: lscr.io/linuxserver/bazarr:__LSI_TAG__
    container_name: bazarr
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/New_York
    volumes:
      - ./config/bazarr:/config
      - ./media/Movies:/movies
      - ./media/TV:/tv
    ports:
      - 6767:6767
    restart: unless-stopped

  tvheadend:
    image: lscr.io/linuxserver/tvheadend:__LSI_TAG__
    container_name: tvheadend
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/New_York
    volumes:
      - ./config/tvheadend:/config
      - ./media/Recordings:/recordings
    ports:
      - 9981:9981
      - 9982:9982
    restart: unless-stopped
"@

$OpsScriptContent = @'
$ErrorActionPreference = "Stop";


function Initialize-Environment {
    Write-Host "Creating Base Directories in $PSScriptRoot..." -ForegroundColor Cyan;
    $BaseDir = "$PSScriptRoot";
    
    if (-not (Test-Path $BaseDir)) { New-Item -ItemType Directory -Force -Path $BaseDir | Out-Null }
    
    $SubDirs = @(
        "config\jellyfin", "config\caddy_data", "config\caddy_config",
        "config\sonarr", "config\radarr", "config\bazarr", "config\jackett",
        "config\transmission", "config\jellyseerr", "config\tvheadend",
        "downloads", "downloads\watch", "data\buffer",
        "media", "media\TV", "media\Movies", "media\Recordings"
    );
    
    foreach ($dir in $SubDirs) {
        $fullPath = "$BaseDir\$dir";
        if (-not (Test-Path $fullPath)) {
            New-Item -ItemType Directory -Force -Path $fullPath | Out-Null;
        }
    }

    Write-Host "Generating Caddyfile..." -ForegroundColor Yellow;
    $caddyContent = @"
___CADDY___
"@;
    $CaddyFile = "$BaseDir\Caddyfile";
    Set-Content -Path $CaddyFile -Value $caddyContent -Encoding UTF8;

    Write-Host "Generating docker-compose.yml..." -ForegroundColor Yellow;
    $composeContent = @"
___COMPOSE___
"@;
    $ComposeFile = "$BaseDir\docker-compose.yml";
    Set-Content -Path $ComposeFile -Value $composeContent -Encoding UTF8;
    Write-Host "Initialization Complete! You can now START the stack." -ForegroundColor Green;
}

function New-Backup {
    Write-Host "Initiating Backup Process..." -ForegroundColor Cyan;
    $ConfigPath = "$PSScriptRoot";
    
    $PublicDocs = [Environment]::GetFolderPath([Environment+SpecialFolder]::CommonDocuments);
    $BackupDir = "$PublicDocs\MediaStackBackups";
    if (-not (Test-Path $BackupDir)) {
        New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null;
    }

    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss";
    $BackupZip = "$BackupDir\MediaStack_Config_$timestamp.zip";
    
    Write-Host "Stopping containers to prevent database corruption..." -ForegroundColor Yellow;
    Set-Location -Path $ConfigPath;
    docker compose stop;
    
    Write-Host "Compressing $ConfigPath into $BackupZip..." -ForegroundColor Yellow;
    Compress-Archive -Path $ConfigPath -DestinationPath $BackupZip -Force;
    
    Write-Host "Restarting containers..." -ForegroundColor Yellow;
    docker compose start;
    
    Write-Host "Backup Complete: $BackupZip" -ForegroundColor Green;
}

function Restore-Backup {
    Write-Host "Initiating Restore Process..." -ForegroundColor Cyan;
    $PublicDocs = [Environment]::GetFolderPath([Environment+SpecialFolder]::CommonDocuments);
    $BackupDir = "$PublicDocs\MediaStackBackups";
    $BaseDir = "$PSScriptRoot";
    
    if (-not (Test-Path $BackupDir)) {
        Write-Host "No backup directory found at $BackupDir." -ForegroundColor Red;
        return;
    }
    
    $Backups = Get-ChildItem -Path $BackupDir -Filter "*.zip" | Sort-Object LastWriteTime -Descending;
    if ($Backups.Count -eq 0) {
        Write-Host "No backup zip files found in $BackupDir." -ForegroundColor Red;
        return;
    }
    
    Write-Host "Available Backups:" -ForegroundColor Yellow;
    for ($i=0; $i -lt $Backups.Count; $i++) {
        $sizeMB = [math]::Round($Backups[$i].Length / 1MB, 2);
        Write-Host "  [$i] $($Backups[$i].Name) ($sizeMB MB)";
    }
    
    $choice = Read-Host "Enter backup number to restore (or press Enter to cancel)";
    if ([string]::IsNullOrWhiteSpace($choice)) { Write-Host "Restore cancelled."; return; }
    
    $idx = [int]$choice;
    if ($idx -lt 0 -or $idx -ge $Backups.Count) { Write-Host "Invalid selection." -ForegroundColor Red; return; }
    
    $TargetZip = $Backups[$idx];
    Write-Host "Destroying existing stack..." -ForegroundColor Red;
    Set-Location -Path $BaseDir;
    docker compose down -v;
    
    Write-Host "Extracting backup..." -ForegroundColor Yellow;
    Expand-Archive -Path $TargetZip.FullName -DestinationPath "$(Split-Path -Parent $PSScriptRoot)" -Force;
    
    Write-Host "Restore complete. Booting Stack..." -ForegroundColor Green;
    docker compose up -d;
}

function Invoke-HealthCheck {
    Write-Host "Running Database Integrity Checks..." -ForegroundColor Cyan;
    
    Write-Host "Checking Sonarr..." -ForegroundColor Yellow;
    docker exec -it sonarr /bin/bash -c "apt-get update >/dev/null 2>&1 && apt-get install -y sqlite3 >/dev/null 2>&1; sqlite3 /config/sonarr.db 'PRAGMA integrity_check;'";
    
    Write-Host "Checking Radarr..." -ForegroundColor Yellow;
    docker exec -it radarr /bin/bash -c "apt-get update >/dev/null 2>&1 && apt-get install -y sqlite3 >/dev/null 2>&1; sqlite3 /config/radarr.db 'PRAGMA integrity_check;'";
    
    Write-Host "Done." -ForegroundColor Green;
}

function Optimize-Database {
    Write-Host "Verifying Volume Mappings and Paths..." -ForegroundColor Cyan;
    
    $SonarrDB = "$PSScriptRoot\config\sonarr\sonarr.db";
    $RadarrDB = "$PSScriptRoot\config\radarr\radarr.db";
    $BackupDir = "$(Split-Path -Parent $PSScriptRoot)\Documents\MediaStackBackups";
    
    if (Test-Path $SonarrDB) { Write-Host "[OK] Sonarr DB found at $SonarrDB." -ForegroundColor Green; }
    else { Write-Host "[WARN] Sonarr DB not found at $SonarrDB (Has it been started yet?)" -ForegroundColor Yellow; }
    
    if (Test-Path $RadarrDB) { Write-Host "[OK] Radarr DB found at $RadarrDB." -ForegroundColor Green; }
    else { Write-Host "[WARN] Radarr DB not found at $RadarrDB (Has it been started yet?)" -ForegroundColor Yellow; }
    
    if (Test-Path $BackupDir) { Write-Host "[OK] Backup Directory mapped correctly at $BackupDir." -ForegroundColor Green; }
    else { Write-Host "[WARN] Backup Directory missing at $BackupDir. Will be created on next backup." -ForegroundColor Yellow; }
    
    Write-Host "`nCompressing Databases (VACUUM)..." -ForegroundColor Cyan;
    
    Write-Host "Compressing Sonarr..." -ForegroundColor Yellow;
    docker exec -it sonarr /bin/bash -c "apt-get update >/dev/null 2>&1 && apt-get install -y sqlite3 >/dev/null 2>&1; sqlite3 /config/sonarr.db 'VACUUM;'";
    
    Write-Host "Compressing Radarr..." -ForegroundColor Yellow;
    docker exec -it radarr /bin/bash -c "apt-get update >/dev/null 2>&1 && apt-get install -y sqlite3 >/dev/null 2>&1; sqlite3 /config/radarr.db 'VACUUM;'";
    
    Write-Host "Database Compression Complete." -ForegroundColor Green;
}

function Confirm-Startup {
    Write-Host "`nWaiting for containers to initialize..." -ForegroundColor Yellow
    Start-Sleep -Seconds 5
    $containers = docker ps -a --format '{{.Names}}'
    
    if (-not $containers) {
        Write-Host "No containers appear to be running or created." -ForegroundColor Red
        return
    }

    Write-Host "`n--- Container Startup Verification ---" -ForegroundColor Cyan
    $MaxRetries = 15
    $WaitSeconds = 5
    $AllHealthy = $false

    for ($i = 1; $i -le $MaxRetries; $i++) {
        $AllHealthy = $true
        $statusLines = @()
        
        foreach ($c in $containers) {
            $status = docker inspect -f '{{.State.Status}}' $c
            $health = docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}NoHealthCheck{{end}}' $c 2>$null
            
            if ($status -eq "exited" -or $status -eq "dead" -or $status -eq "restarting") {
                $statusLines += "  [ERROR] $c is failing (Status: $status)"
                $AllHealthy = $false
            } elseif ($health -eq "unhealthy") {
                $statusLines += "  [ERROR] $c is unhealthy!"
                $AllHealthy = $false
            } elseif ($health -eq "starting") {
                $statusLines += "  [WAIT] $c is still starting..."
                $AllHealthy = $false
            } elseif ($health -eq "healthy" -or $status -eq "running") {
                $statusLines += "  [OK] $c is running ($status, $health)"
            } else {
                $statusLines += "  [WARN] $c is in unknown state ($status)"
                $AllHealthy = $false
            }
        }
        
        if ($AllHealthy) {
            Write-Host "All containers are running and healthy!" -ForegroundColor Green
            $statusLines | ForEach-Object { Write-Host $_ -ForegroundColor Green }
            break
        }
        
        Write-Host "Check $i/$MaxRetries: Waiting for containers to stabilize..." -ForegroundColor Yellow
        if ($i -eq $MaxRetries) {
            Write-Host "Timeout reached! Some containers failed to start properly:" -ForegroundColor Red
            $statusLines | ForEach-Object { Write-Host $_ }
        } else {
            Start-Sleep -Seconds $WaitSeconds
        }
    }

    Write-Host "`n--- Route Verification ---" -ForegroundColor Cyan
    $routes = @("voltaireun.local", "jellyfin.voltaireun.local", "radarr.voltaireun.local", "sonarr.voltaireun.local", "jellyseerr.voltaireun.local", "jackett.voltaireun.local", "bazarr.voltaireun.local", "transmission.voltaireun.local", "tvheadend.voltaireun.local", "dashboard.voltaireun.local", "hdhomerun.voltaireun.local")
    
    foreach ($route in $routes) {
        $routeOk = $false
        for ($r = 1; $r -le 5; $r++) {
            try {
                $null = Invoke-WebRequest -Uri "http://localhost:80" -Headers @{Host=$route} -UseBasicParsing -Method Head -TimeoutSec 5 -MaximumRedirection 0 -ErrorAction Stop
                Write-Host "  [OK] Route $route is responding" -ForegroundColor Green
                $routeOk = $true
                break
            } catch {
                if ($_.Exception.Response) {
                    $code = $_.Exception.Response.StatusCode.value__
                    if ($code -ge 200 -and $code -lt 500) {
                        Write-Host "  [OK] Route $route is responding (Status $code)" -ForegroundColor Green
                        $routeOk = $true
                        break
                    }
                }
                Start-Sleep -Seconds 3
            }
        }
        if (-not $routeOk) {
            Write-Host "  [WARN] Route $route failed verification after multiple attempts." -ForegroundColor Yellow
        }
    }
}

function Show-HealthMonitor {
    $monitoring = $true
    while ($monitoring) {
        Clear-Host
        Write-Host "=========================================" -ForegroundColor DarkCyan
        Write-Host "       L I V E   H E A L T H   M O N I T O R" -ForegroundColor Cyan
        Write-Host "       Press 'Q' to quit and return to Menu" -ForegroundColor DarkGray
        Write-Host "=========================================" -ForegroundColor DarkCyan
        
        docker ps --format 'table {{.Names}}`t{{.Status}}`t{{.Ports}}' | Write-Host
        Write-Host "`n--- CPU / MEMORY USAGE ---" -ForegroundColor Cyan
        docker stats --no-stream --format 'table {{.Name}}`t{{.CPUPerc}}`t{{.MemUsage}}`t{{.MemPerc}}' | Write-Host
        
        if ($Host.UI.RawUI.KeyAvailable) {
            $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            if ($key.Character -match 'q|Q') {
                $monitoring = $false
            }
        }
        if ($monitoring) { Start-Sleep -Seconds 3 }
    }
}

$BaseDir = "$PSScriptRoot";
$script:running = $true;
while ($script:running) {
    Write-Host "`n=== High-Availability Media Stack Control Room =" -ForegroundColor Cyan;
    Write-Host "Working Directory: $BaseDir" -ForegroundColor DarkGray;
    Write-Host "1. INITIALIZE: Create Folders & Generate Configs";
    Write-Host "2. START: Boot the entire stack (Detached)";
    Write-Host "3. STOP: Gracefully shutdown stack";
    Write-Host "4. BACKUP: Save Database & Config Zip Archive";
    Write-Host "5. RESTORE: Recover from a Zip Archive";
    Write-Host "6. HEALTH: Run DB Integrity Checks";
    Write-Host "7. OPTIMIZE: Verify Mappings & Compress Databases";
    Write-Host "8. LIVE HEALTH MONITOR";
    Write-Host "9. EXIT";
    Write-Host "================================================" -ForegroundColor Cyan;
    
    $choice = Read-Host "Select an option";
    if ($null -ne $choice) { $choice = $choice.Trim() }
    
    try {
        switch ($choice) {
            '1' { Initialize-Environment; }
            '2' { Set-Location -Path $BaseDir; docker compose up -d; Write-Host "Boot Command Sent!" -ForegroundColor Green; Confirm-Startup; }
            '3' { Set-Location -Path $BaseDir; docker compose down; Write-Host "Shutdown Command Sent!" -ForegroundColor Green; }
            '4' { New-Backup; }
            '5' { Restore-Backup; }
            '6' { Invoke-HealthCheck; }
            '7' { Optimize-Database; }
            '8' { Show-HealthMonitor; }
            '9' { $script:running = $false; Write-Host "Exiting Control Room..." -ForegroundColor Cyan; }
            default { Write-Host "Invalid option. Please try again." -ForegroundColor Red; }
        }
    } catch {
        Write-Host "An error occurred: $_" -ForegroundColor Red;
    }
}
'@

$OpsScriptContent = $OpsScriptContent.Replace('___CADDY___', $CaddyFileString)
$OpsScriptContent = $OpsScriptContent.Replace('___COMPOSE___', $ComposeFileString)
$OpsScriptContent = $OpsScriptContent.Replace('__LSI_TAG__', $lsiTag)

$BaseDir = "$PSScriptRoot"
$OpsScriptPath = "$BaseDir\config\jellyfin\mediastack-ops.ps1"
$TargetDir = Split-Path -Path $OpsScriptPath -Parent
if (-not (Test-Path $TargetDir)) {
    New-Item -ItemType Directory -Force -Path $TargetDir | Out-Null
}

Set-Content -Path $OpsScriptPath -Value $OpsScriptContent -Encoding UTF8
Write-Host "`nControl Script successfully built at $OpsScriptPath!" -ForegroundColor Green

Write-Host "Initializing base files for Docker Pull..." -ForegroundColor Yellow
# We can't dot-source the main script because it has an interactive while loop.
# But we can extract and write the generated YAML files directly here.
# Wait, parsing the script is tedious. Since we know what it looks like, we can just run the initialization block directly here, or we can just run docker compose pull directly if the compose file is built.
# To build the compose file, we just write it directly.
$CaddyFileContent = @'
http://voltaireun.local, :8080 {
    root * /var/www/dashboard
    file_server
}

http://jellyfin.voltaireun.local, :8096 {
    reverse_proxy 192.168.4.21:8096 192.168.4.30:8096 {
        lb_policy first
        health_uri /health
        health_interval 10s
        header_up X-Real-IP {remote}
        header_up X-Forwarded-For {remote}
    }
}

http://radarr.voltaireun.local {
    reverse_proxy radarr:7878
}

http://sonarr.voltaireun.local {
    reverse_proxy sonarr:8989
}

http://jellyseerr.voltaireun.local {
    reverse_proxy jellyseerr:5055
}

http://jackett.voltaireun.local {
    reverse_proxy jackett:9117
}

http://bazarr.voltaireun.local {
    reverse_proxy bazarr:6767
}

http://transmission.voltaireun.local {
    reverse_proxy transmission:9091
}

http://tvheadend.voltaireun.local {
    reverse_proxy tvheadend:9981
}
'@
$ComposeYamlContent = @'
services:
  caddy:
    image: caddy:latest
    container_name: caddy
    ports:
      - "80:80"
      - "443:443"
      - "8096:8096"
      - "8080:8080"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - ./config/caddy_data:/data
      - ./config/caddy_config:/config
      - ./dashboard:/var/www/dashboard
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080"]
      interval: 30s
      timeout: 10s
      retries: 3
    labels:
      - "autoheal=true"

  jellyfin:
    image: lscr.io/linuxserver/jellyfin:__LSI_TAG__
    container_name: jellyfin
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/New_York
    volumes:
      - ./config/jellyfin:/config
      - ./media:/media
      - ./config/jellyfin/french-crime.m3u:/media/iptv/french-crime.m3u:ro
    ports:
      - 8097:8096
      - 8920:8920
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8096/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  jellyseerr:
    image: ghcr.io/seerr-team/seerr:v3.4.1
    container_name: jellyseerr
    environment:
      - LOG_LEVEL=debug
      - TZ=America/New_York
    ports:
      - 5055:5055
    volumes:
      - ./config/jellyseerr:/app/config
    restart: unless-stopped

  sonarr:
    image: lscr.io/linuxserver/sonarr:__LSI_TAG__
    container_name: sonarr
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/New_York
    volumes:
      - ./config/sonarr:/config
      - ./media/TV:/tv
      - ./downloads:/downloads
    ports:
      - 8989:8989
    restart: unless-stopped

  radarr:
    image: lscr.io/linuxserver/radarr:__LSI_TAG__
    container_name: radarr
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/New_York
    volumes:
      - ./config/radarr:/config
      - ./media/Movies:/movies
      - ./downloads:/downloads
    ports:
      - 7878:7878
    restart: unless-stopped

  jackett:
    image: lscr.io/linuxserver/jackett:__LSI_TAG__
    container_name: jackett
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/New_York
      - AUTO_UPDATE=true
    volumes:
      - ./config/jackett:/config
      - ./downloads:/downloads
    ports:
      - 9117:9117
    restart: unless-stopped
    sysctls:
      - net.ipv6.conf.all.disable_ipv6=1

  transmission:
    image: lscr.io/linuxserver/transmission:__LSI_TAG__
    container_name: transmission
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/New_York
    volumes:
      - ./config/transmission:/config
      - ./downloads:/downloads
      - ./downloads/watch:/watch
    ports:
      - 9091:9091
      - 51413:51413
      - 51413:51413/udp
    restart: unless-stopped

  bazarr:
    image: lscr.io/linuxserver/bazarr:__LSI_TAG__
    container_name: bazarr
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/New_York
    volumes:
      - ./config/bazarr:/config
      - ./media/Movies:/movies
      - ./media/TV:/tv
    ports:
      - 6767:6767
    restart: unless-stopped

  tvheadend:
    image: lscr.io/linuxserver/tvheadend:__LSI_TAG__
    container_name: tvheadend
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/New_York
    volumes:
      - ./config/tvheadend:/config
      - ./media/Recordings:/recordings
    ports:
      - 9981:9981
      - 9982:9982
    restart: unless-stopped
'@
$ComposeYamlContent = $ComposeYamlContent.Replace('__LSI_TAG__', $lsiTag)

Set-Content -Path "$BaseDir\Caddyfile" -Value $CaddyFileContent -Encoding UTF8
Set-Content -Path "$BaseDir\docker-compose.yml" -Value $ComposeYamlContent -Encoding UTF8

Write-Host "`nPulling Docker Images ($lsiTag)..." -ForegroundColor Cyan
Set-Location -Path $BaseDir
docker compose pull

Write-Host "`nInstallation Complete!" -ForegroundColor Green
Write-Host "You can now launch the stack using:"
Write-Host "  cd $PSScriptRoot\config\jellyfin"
Write-Host "  .\mediastack-ops.ps1"
Write-Host ""
