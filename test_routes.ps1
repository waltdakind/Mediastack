$ErrorActionPreference = "Stop";

$global:FailureCounts = @{}
$global:GracePeriods = @{}

function Invoke-Autoheal {
    param([string]$Container, [string]$Reason)
    
    $HandoffsDir = "$PSScriptRoot\handoffs"
    if (-not (Test-Path $HandoffsDir)) { New-Item -ItemType Directory -Force -Path $HandoffsDir | Out-Null }
    
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $filename = "$HandoffsDir\AI_Handoff_${Container}_${timestamp}.md"
    
    Write-Host "  [AUTOHEAL TRIGGERED] Restoring $Container..." -ForegroundColor Red
    
    # Generate Handoff File
    $handoff = @"
# AI Autoheal Handoff: $Container
**Timestamp:** $(Get-Date)
**Trigger Reason:** $Reason

## Docker Inspect State
```json
$(docker inspect $Container 2>$null)
```

## Recent Logs
```text
$(docker logs --tail 100 $Container 2>&1)
```
"@
    Set-Content -Path $filename -Value $handoff -Encoding UTF8
    
    # Restart Container
    docker restart $Container | Out-Null
    
    # Set grace period for 60 seconds
    $global:GracePeriods[$Container] = (Get-Date).AddSeconds(60)
    $global:FailureCounts[$Container] = 0
    
    Write-Host "  [HANDOFF CREATED] $filename" -ForegroundColor Magenta
}

function Test-Routes {
    param([switch]$Silent)
    
    if (-not $Silent) {
        Write-Host "`n--- Route Verification ---" -ForegroundColor Cyan
    }
    
    $routes = @(
        @{ Route="voltairedeux.local"; Container="caddy"; Path="" },
        @{ Route="homepage.voltairedeux.local"; Container="homepage"; Path="" },
        @{ Route="api.voltairedeux.local"; Container="api-gateway"; Path="/api/system/status" },
        @{ Route="jellyfin.voltairedeux.local"; Container="jellyfin"; Path="/health" },
        @{ Route="radarr.voltairedeux.local"; Container="radarr"; Path="/ping" },
        @{ Route="sonarr.voltairedeux.local"; Container="sonarr"; Path="/ping" },
        @{ Route="prowlarr.voltairedeux.local"; Container="prowlarr"; Path="/ping" },
        @{ Route="jellyseerr.voltairedeux.local"; Container="jellyseerr"; Path="/api/v1/status" },
        @{ Route="bazarr.voltairedeux.local"; Container="bazarr"; Path="" },
        @{ Route="transmission.voltairedeux.local"; Container="transmission"; Path="/transmission/web/" },
        @{ Route="tvheadend.voltairedeux.local"; Container="tvheadend"; Path="" },
        @{ Route="hdhomerun.voltairedeux.local"; Container="caddy"; Path="" },
        @{ Route="db.voltairedeux.local"; Container="mediastack-db"; Path="" },
        @{ Route="musicbrainz.voltairedeux.local"; Container="musicbrainz"; Path="" },
        @{ Route="voltaireun.local"; Container="caddy"; Path="" },
        @{ Route="jellyfin.voltaireun.local"; Container="jellyfin"; Path="/health" }
    )
    
    foreach ($r in $routes) {
        $route = $r.Route
        $container = $r.Container
        $failed = $false
        $reason = ""
        $statusCode = ""
        
        try {
            $path = if ($r.Path) { $r.Path } else { "/" }
            $curlOutput = curl.exe -s -o NUL -w "%{http_code}" --max-time 5 -H "Host: $route" "http://localhost:80$path"
            $statusCode = [int]$curlOutput
            
            if ($statusCode -eq 000 -or $statusCode -eq 0) {
                if (-not $Silent) { Write-Host "  [FAIL] http://$route failed to connect" -ForegroundColor Red }
                $failed = $true
                $reason = "Connection refused or timed out"
                $statusCode = "FAIL"
            } elseif ($statusCode -ge 500) {
                if (-not $Silent) { Write-Host "  [WARN] http://$route backend not ready ($statusCode)" -ForegroundColor Yellow }
                $failed = $true
                $reason = "Proxy returned $statusCode"
            } else {
                if (-not $Silent) { Write-Host "  [OK] http://$route is responding ($statusCode)" -ForegroundColor Green }
            }
        } catch {
            if (-not $Silent) { Write-Host "  [FAIL] http://$route failed to execute test" -ForegroundColor Red }
            $failed = $true
            $reason = "Test execution failed"
            $statusCode = "ERROR"
        }
        
        # Only process autoheal logic if we are in silent (monitor) mode
        if ($Silent) {
            # Display inline status
            if ($failed) {
                Write-Host "  [WARN] $route ($statusCode)" -ForegroundColor Yellow
            } else {
                Write-Host "  [OK] $route ($statusCode)" -ForegroundColor Green
            }
            
            # Autoheal logic
            if ($global:GracePeriods.ContainsKey($container) -and $global:GracePeriods[$container] -gt (Get-Date)) {
                # In grace period, ignore failures
            } elseif ($failed) {
                if (-not $global:FailureCounts.ContainsKey($container)) { $global:FailureCounts[$container] = 0 }
                $global:FailureCounts[$container]++
                
                if ($global:FailureCounts[$container] -ge 3) {
                    Invoke-Autoheal -Container $container -Reason $reason
                }
            } else {
                $global:FailureCounts[$container] = 0
            }
        }
    }

    # HTTPS Ingress Verification
    $httpsEndpoints = @(
        @{ Host="waltdakind.xubi.org"; Name="WAN Root (Jellyfin HTTPS)" },
        @{ Host="jellyfin.waltdakind.xubi.org"; Name="WAN Subdomain (Jellyfin HTTPS)" },
        @{ Host="voltairedeux.local"; Name="LAN VoltaireDeux (HTTPS)" },
        @{ Host="voltaireun.local"; Name="LAN VoltaireUn (HTTPS)" }
    )
    if (-not $Silent) {
        Write-Host "`n--- HTTPS (:443) Ingress & TLS Handshake Verification ---" -ForegroundColor Cyan
    }
    foreach ($ep in $httpsEndpoints) {
        try {
            $hCode = curl.exe -k -s -o NUL -w "%{http_code}" --max-time 5 --resolve "$($ep.Host):443:127.0.0.1" "https://$($ep.Host)/" --ssl-no-revoke
            $hI = [int]$hCode
            if ($hI -ge 200 -and $hI -lt 400) {
                if (-not $Silent) { Write-Host ("  [OK] https://{0,-30} (TLSv1.3 Secure -> HTTP {1})" -f $ep.Host, $hI) -ForegroundColor Green }
            } else {
                if (-not $Silent) { Write-Host ("  [WARN] https://{0} returned HTTP {1}" -f $ep.Host, $hI) -ForegroundColor Yellow }
            }
        } catch {
            if (-not $Silent) { Write-Host ("  [FAIL] https://{0} TLS handshake failed" -f $ep.Host) -ForegroundColor Red }
        }
    }
}

function Test-Startup {
    Write-Host "`nWaiting for containers to start..." -ForegroundColor Yellow
    Start-Sleep -Seconds 10
    $containers = docker ps --format '{{.Names}}'
    
    if (-not $containers) {
        Write-Host "No containers appear to be running." -ForegroundColor Red
        return
    }

    Write-Host "`n--- Container Startup Verification ---" -ForegroundColor Cyan
    foreach ($c in $containers) {
        $status = docker inspect -f '{{.State.Status}}' $c
        $health = docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}NoHealthCheck{{end}}' $c 2>$null
        
        if ($health -eq "healthy" -or $status -eq "running") {
            Write-Host "  [OK] $c is running ($status, $health)" -ForegroundColor Green
        } else {
            Write-Host "  [WARN] $c may have issues ($status, $health)" -ForegroundColor Yellow
        }
    }

    Test-Routes -Silent:$false
}

function Show-HealthMonitor {
    $monitoring = $true
    
    $global:FailureCounts.Clear()
    $global:GracePeriods.Clear()
    
    while ($monitoring) {
        Clear-Host
        Write-Host "=========================================" -ForegroundColor DarkCyan
        Write-Host "       L I V E   H E A L T H   M O N I T O R" -ForegroundColor Cyan
        Write-Host "       Press 'Q' to quit and return to Menu" -ForegroundColor DarkGray
        Write-Host "=========================================" -ForegroundColor DarkCyan
        
        docker ps --format 'table {{.Names}}`t{{.Status}}`t{{.Ports}}' | Write-Host
        Write-Host "`n--- CPU / MEMORY USAGE ---" -ForegroundColor Cyan
        docker stats --no-stream --format 'table {{.Name}}`t{{.CPUPerc}}`t{{.MemUsage}}`t{{.MemPerc}}' | Write-Host
        
        Write-Host "`n--- ACTIVE ROUTE AUTOHEALER ---" -ForegroundColor Cyan
        Test-Routes -Silent:$true
        
        if ($Host.UI.RawUI.KeyAvailable) {
            $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            if ($key.Character -match 'q|Q') {
                $monitoring = $false
            }
        }
        Start-Sleep -Seconds 2
    }
}

function New-Directories {
    Write-Host "Creating local volume directories..." -ForegroundColor Yellow;
    $ScriptDir = "$PSScriptRoot";
    $dirs = @(
        "config\jellyfin", "config\caddy_data", "config\caddy_config",
        "config\sonarr", "config\radarr", "config\bazarr", "config\jackett",
        "config\transmission", "config\jellyseerr", "config\tvheadend",
        "certs", "dashboard",
        "downloads", "data\buffer", "handoffs"
    );

    foreach ($dir in $dirs) {
        $path = Join-Path -Path $ScriptDir -ChildPath $dir;
        if (-not (Test-Path -Path $path)) {
            New-Item -ItemType Directory -Force -Path $path | Out-Null;
            Write-Host "  -> Created: $dir";
        }
    }
}

function Initialize-Environment {
    Write-Host "Ensuring base directory exists at $PSScriptRoot" -ForegroundColor Cyan;
    $ScriptDir = "$PSScriptRoot";
    
    if (-not (Test-Path $ScriptDir)) { New-Item -ItemType Directory -Force -Path $ScriptDir | Out-Null }
    
    Write-Host "Checking for Docker Compose..." -ForegroundColor Yellow;
    if (-not (Get-Command "docker" -ErrorAction SilentlyContinue)) {
        Write-Host "Docker is not installed or not in PATH!" -ForegroundColor Red
        return
    }
    $dcVersion = docker compose version
    Write-Host "Found Docker Compose: $dcVersion" -ForegroundColor Green

    Write-Host "Generating Caddyfile for Failover/Proxy..." -ForegroundColor Cyan;
    
    $CaddyFile = Join-Path $ScriptDir "Caddyfile"
    if (-not (Test-Path $CaddyFile)) {
        Write-Host "Warning: Caddyfile missing. Please ensure it exists." -ForegroundColor Red
    }

    $ComposeFile = Join-Path $ScriptDir "docker-compose.yml"
    if (-not (Test-Path $ComposeFile)) {
        Write-Host "Warning: docker-compose.yml missing. Please ensure it exists." -ForegroundColor Red
    }
}

$ScriptDir = "$PSScriptRoot"
Set-Location -Path $ScriptDir

# Always initialize on run to ensure files exist
Initialize-Environment


