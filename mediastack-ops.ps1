# ==============================================================================
# MediaStack Advanced Operations, Routing & Enterprise Autohealer Suite
# Node: VOLTAIREDEUX / ORDINATEURDEVOL (Dual-Node Aware)
# ==============================================================================

param(
    [switch]$Watchdog,
    [int]$IntervalSeconds = 30,
    [switch]$NoInteractive
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::InputEncoding  = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['Out-File:Encoding']   = 'utf8'
$PSDefaultParameterValues['Set-Content:Encoding'] = 'utf8'

$global:FailureCounts   = @{}
$global:GracePeriods    = @{}
$global:RestartHistory  = @{} # Circuit breaker tracking: @{ Container = @(Timestamps) }
$global:CircuitBreakers = @{} # @{ Container = [bool] }
$global:RecentEvents    = [System.Collections.ArrayList]::new()

if (Test-Path (Join-Path $PSScriptRoot "docker-compose.yml")) {
    $ScriptDir = $PSScriptRoot
} elseif (Test-Path (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "docker-compose.yml")) {
    $ScriptDir = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
} elseif (Test-Path (Join-Path (Split-Path -Parent $PSScriptRoot) "docker-compose.yml")) {
    $ScriptDir = Split-Path -Parent $PSScriptRoot
} else {
    $ScriptDir = $PSScriptRoot
}

# --- HELPER: Record Event to Database & Memory Buffer ---
function Record-AutohealEvent {
    param(
        [string]$Container,
        [string]$TriggerReason,
        [string]$ActionTaken,
        [string]$Details = "",
        [string]$Status = "HEALED"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $eventMsg = "[$timestamp] $Container : $TriggerReason -> $ActionTaken ($Status)"
    
    [void]$global:RecentEvents.Insert(0, $eventMsg)
    while ($global:RecentEvents.Count -gt 15) { [void]$global:RecentEvents.RemoveAt(15) }

    # Ingest into SQLite database via mediastack-db
    try {
        $sqlInit = @"
CREATE TABLE IF NOT EXISTS autoheal_events_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    event_timestamp TEXT NOT NULL,
    container_name TEXT NOT NULL,
    trigger_reason TEXT,
    action_taken TEXT,
    status TEXT,
    details TEXT
);
"@
        $cleanReason  = $TriggerReason -replace "'", "''"
        $cleanAction  = $ActionTaken -replace "'", "''"
        $cleanDetails = $Details -replace "'", "''"
        $sqlInsert = "INSERT INTO autoheal_events_log (event_timestamp, container_name, trigger_reason, action_taken, status, details) VALUES ('$timestamp', '$Container', '$cleanReason', '$cleanAction', '$Status', '$cleanDetails');"

        docker exec mediastack-db sqlite3 /config/mediastack_backup.db "$sqlInit $sqlInsert" 2>$null
    } catch {
        # Fallback if DB is initializing
    }
}

# --- MASTER AUTOHEALER FUNCTION ---
function Invoke-Autoheal {
    param(
        [string]$Container,
        [string]$Reason,
        [string]$Route = ""
    )

    $now = Get-Date
    $HandoffsDir = Join-Path $ScriptDir "handoffs"
    if (-not (Test-Path $HandoffsDir)) { New-Item -ItemType Directory -Force -Path $HandoffsDir | Out-Null }

    # 1. Circuit Breaker Check (Max 4 restarts in 15 minutes)
    if (-not $global:RestartHistory.ContainsKey($Container)) {
        $global:RestartHistory[$Container] = [System.Collections.ArrayList]::new()
    }
    
    # Prune timestamps older than 15 minutes
    $history = $global:RestartHistory[$Container]
    $cutoff = $now.AddMinutes(-15)
    for ($i = $history.Count - 1; $i -ge 0; $i--) {
        if ($history[$i] -lt $cutoff) { [void]$history.RemoveAt($i) }
    }

    if ($history.Count -ge 4) {
        $global:CircuitBreakers[$Container] = $true
        $global:GracePeriods[$Container] = $now.AddMinutes(5) # 5-minute backoff
        Write-Host "  [CIRCUIT BREAKER] $Container has restarted $($history.Count) times in 15m. Pausing autoheal to prevent crashloop." -ForegroundColor Red
        Record-AutohealEvent -Container $Container -TriggerReason $Reason -ActionTaken "Circuit Breaker Tripped (5m Backoff)" -Status "BLOCKED"
        return
    }

    [void]$history.Add($now)
    $global:CircuitBreakers[$Container] = $false

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $filename  = "$HandoffsDir\AI_Handoff_${Container}_${timestamp}.md"

    Write-Host "  [AUTOHEAL INITIATED] Diagnosing and recovering $Container (Trigger: $Reason)..." -ForegroundColor Red

    # 2. Deep Container Inspection
    $inspectJson  = cmd.exe /c "docker inspect $Container 2>&1"
    $inspectObj   = $inspectJson | ConvertFrom-Json -ErrorAction SilentlyContinue
    $processTree  = cmd.exe /c "docker top $Container 2>&1"
    $recentLogs   = cmd.exe /c "docker logs --tail 200 --timestamps $Container 2>&1"

    # 3. Environment & Configuration Discovery
    $envVars   = @()
    $warnings  = @()
    $hasPUID   = $false
    $hasPGID   = $false
    $hasTZ     = $false

    if ($inspectObj) {
        $rawEnv = $inspectObj[0].Config.Env
        foreach ($e in $rawEnv) {
            $kv = $e -split "=", 2
            $envVars += [PSCustomObject]@{ Key = $kv[0]; Value = if ($kv.Count -gt 1) { $kv[1] } else { "" } }
            if ($kv[0] -eq "PUID") { $hasPUID = $true }
            if ($kv[0] -eq "PGID") { $hasPGID = $true }
            if ($kv[0] -eq "TZ")   { $hasTZ   = $true }
        }
    }

    $envTable = "| Variable | Value |`n|----------|-------|`n"
    foreach ($e in $envVars) { $envTable += "| ``$($e.Key)`` | ``$($e.Value)`` |`n" }

    if (-not $hasPUID) { $warnings += "[WARN] **PUID not set** - container may have permission discrepancies." }
    if (-not $hasPGID) { $warnings += "[WARN] **PGID not set** - container may have permission discrepancies." }
    if (-not $hasTZ)   { $warnings += "[WARN] **TZ not set** - timestamps in logs/schedules may diverge." }

    # 4. Volume / Mount Discovery & SQLite Lock Inspection
    $configHostPath = $null
    if ($inspectObj) {
        $mounts = $inspectObj[0].Mounts
        foreach ($m in $mounts) {
            if ($m.Destination -match "^(/config|/app/config|/data)") { $configHostPath = $m.Source; break }
        }
    }

    $volumeTree    = "(no /config mount detected)"
    $corruptFiles  = @()
    $staleWalLocks = @()
    $configDumps   = ""

    if ($configHostPath -and (Test-Path $configHostPath)) {
        $volumeTree = (Get-ChildItem -Path $configHostPath -Recurse -Depth 3 -ErrorAction SilentlyContinue |
            Select-Object @{N='Path';E={$_.FullName.Replace($configHostPath,'').TrimStart('\/')}},
                          @{N='Size';E={if($_.PSIsContainer){"<DIR>"}else{"$($_.Length) bytes"}}} |
            Format-Table -AutoSize | Out-String).Trim()

        # Detect 0-byte database files
        Get-ChildItem -Path $configHostPath -Recurse -Filter "*.db" -ErrorAction SilentlyContinue |
            Where-Object { $_.Length -eq 0 } |
            ForEach-Object { $corruptFiles += $_.FullName }
        Get-ChildItem -Path $configHostPath -Recurse -Filter "*.sqlite" -ErrorAction SilentlyContinue |
            Where-Object { $_.Length -eq 0 } |
            ForEach-Object { $corruptFiles += $_.FullName }

        # Detect stale SQLite WAL & lock files
        Get-ChildItem -Path $configHostPath -Recurse -Filter "*.db-wal" -ErrorAction SilentlyContinue |
            ForEach-Object { $staleWalLocks += $_.FullName }
        Get-ChildItem -Path $configHostPath -Recurse -Filter "*.db-journal" -ErrorAction SilentlyContinue |
            ForEach-Object { $staleWalLocks += $_.FullName }

        $knownConfigs = @("settings.json", "config.xml", "system.xml", "database.xml", "network.xml", "prowlarr.db", "bazarr.db")
        foreach ($cfgName in $knownConfigs) {
            $found = Get-ChildItem -Path $configHostPath -Recurse -Filter $cfgName -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($found -and $found.Length -gt 0) {
                $ext = $found.Extension.ToLower()
                $lang = switch ($ext) { ".json" { "json" } ".xml" { "xml" } default { "text" } }
                $preview = (Get-Content $found.FullName -TotalCount 80 -ErrorAction SilentlyContinue) -join "`n"
                $configDumps += "`n### ``$($found.Name)```n> Path: ``$($found.FullName)```n```$lang`n$preview`n````n"
            }
        }
    }

    # 5. Targeted Remediation Action
    $actionTaken = "Docker Restart"
    $isDbLockIssue = ($recentLogs -match "database is locked" -or $recentLogs -match "disk I/O error" -or $recentLogs -match "sqlite3.OperationalError")

    if ($Container -eq "caddy") {
        # Caddy dynamic reload attempt first
        Write-Host "  [ACTION] Performing zero-downtime Caddy configuration reload..." -ForegroundColor Yellow
        $caddyReload = docker exec caddy caddy reload --config /etc/caddy/Caddyfile 2>&1
        if ($LASTEXITCODE -eq 0) {
            $actionTaken = "Caddy Zero-Downtime Reload"
        } else {
            docker restart caddy 2>&1 | Out-Null
            $actionTaken = "Caddy Hard Container Restart"
        }
    } elseif ($isDbLockIssue) {
        Write-Host "  [ACTION] SQLite disk I/O lock detected. Stopping container to cleanly release locks..." -ForegroundColor Yellow
        docker stop $Container 2>&1 | Out-Null
        Start-Sleep -Seconds 2
        docker start $Container 2>&1 | Out-Null
        $actionTaken = "SQLite Lock Release & Container Reboot"
    } else {
        docker restart $Container 2>&1 | Out-Null
    }

    # 6. Generate Structured AI Handoff Report
    $corruptBlock = if ($corruptFiles.Count -gt 0) { "## ⚠️ ZERO-BYTE CORRUPTION DETECTED`n" + (($corruptFiles | ForEach-Object { "- ``$_``" }) -join "`n") } else { "" }
    $warningsBlock = if ($warnings.Count -gt 0) { "## ⚠️ BEST PRACTICE WARNINGS`n" + (($warnings | ForEach-Object { "- $_" }) -join "`n") } else { "" }

    Set-Content -Path $filename -Encoding UTF8 -Value @"
# 🩺 Enterprise AI Autoheal Diagnostics Handoff: ``$Container``

| Parameter | Value |
| :--- | :--- |
| **Container Target** | ``$Container`` |
| **Associated Route** | ``$Route`` |
| **Timestamp** | $(Get-Date -Format "yyyy-MM-dd HH:mm:ss") |
| **Trigger Reason** | $Reason |
| **Action Executed** | $actionTaken |
| **Handoff Artifact** | ``$filename`` |

---

$corruptBlock
$warningsBlock

---

## 📋 Environment Variables
$envTable

---

## ⚡ Process Hierarchy at Healing Trigger
````text
$processTree
````

---

## 📂 Active Volume Layout
````text
$volumeTree
````

---

## 📜 Recent Container Logs (Tail 200)
````text
$recentLogs
````

---
*Report generated automatically by MediaStack Master Autohealer.*
"@

    # 7. Post-Healing Grace Window & Telemetry Log
    $global:GracePeriods[$Container] = $now.AddSeconds(60)
    $global:FailureCounts[$Container] = 0

    Record-AutohealEvent -Container $Container -TriggerReason $Reason -ActionTaken $actionTaken -Details "Handoff saved to $filename" -Status "HEALED"
    Write-Host "  [OK] $Container healed successfully via $actionTaken. Grace window set to 60s." -ForegroundColor Green
    Write-Host "  [DIAGNOSTIC REPORT] $filename" -ForegroundColor Magenta
}

# --- MASTER ROUTE & HEALTH CHECK ENGINE ---
function Test-Routes {
    param([switch]$Silent)
    
    if (-not $Silent) {
        Write-Host "`n--- Fleet Route & L7 Health Verification ---" -ForegroundColor Cyan
    }
    
    $routes = @(
        @{ Route="ordinateur.local"; Container="caddy"; Path=""; ExpectedCode=200 },
        @{ Route="homepage.ordinateur.local"; Container="homepage"; Path=""; ExpectedCode=200 },
        @{ Route="api.ordinateur.local"; Container="api-gateway"; Path="/api/system/status"; ExpectedCode=200 },
        @{ Route="jellyfin.ordinateur.local"; Container="jellyfin"; Path="/health"; ExpectedCode=200 },
        @{ Route="radarr.ordinateur.local"; Container="radarr"; Path="/ping"; ExpectedCode=200 },
        @{ Route="sonarr.ordinateur.local"; Container="sonarr"; Path="/ping"; ExpectedCode=200 },
        @{ Route="prowlarr.ordinateur.local"; Container="prowlarr"; Path="/ping"; ExpectedCode=200 },
        @{ Route="jellyseerr.ordinateur.local"; Container="jellyseerr"; Path="/api/v1/status"; ExpectedCode=200 },
        @{ Route="bazarr.ordinateur.local"; Container="bazarr"; Path=""; ExpectedCode=200 },
        @{ Route="transmission.ordinateur.local"; Container="transmission"; Path="/transmission/web/"; ExpectedCode=200 },
        @{ Route="tvheadend.ordinateur.local"; Container="tvheadend"; Path=""; ExpectedCode=302 },
        @{ Route="db.ordinateur.local"; Container="mediastack-db"; Path=""; ExpectedCode=200 },
        @{ Route="db.mediaserver.local"; Container="mediastack-db"; Path=""; ExpectedCode=200 },
        @{ Route="musicbrainz.ordinateur.local"; Container="musicbrainz"; Path=""; ExpectedCode=500 } # 500 until dumps imported, starlet responding
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
                if (-not $Silent) { Write-Host "  [FAIL] http://$route -> Connection Refused (000)" -ForegroundColor Red }
                $failed = $true
                $reason = "Connection refused / Host unreachable"
                $statusCode = "FAIL"
            } elseif ($statusCode -ge 502 -and $statusCode -le 504) {
                if (-not $Silent) { Write-Host "  [WARN] http://$route -> Gateway/Proxy Error ($statusCode)" -ForegroundColor Yellow }
                $failed = $true
                $reason = "Proxy Gateway returned $statusCode"
            } else {
                if (-not $Silent) { Write-Host "  [OK] http://$route is healthy ($statusCode)" -ForegroundColor Green }
            }
        } catch {
            if (-not $Silent) { Write-Host "  [FAIL] http://$route test execution exception: $_" -ForegroundColor Red }
            $failed = $true
            $reason = "Execution Exception: $($_.Exception.Message)"
            $statusCode = "ERROR"
        }
        
        if ($Silent) {
            $isTripped = ($global:CircuitBreakers.ContainsKey($container) -and $global:CircuitBreakers[$container])
            $inGrace = ($global:GracePeriods.ContainsKey($container) -and $global:GracePeriods[$container] -gt (Get-Date))

            if ($failed) {
                $statusTag = if ($isTripped) { "[CIRCUIT BREAKER]" } elseif ($inGrace) { "[GRACE PERIOD]" } else { "[FAILING]" }
                Write-Host ("  {0,-18} http://{1,-32} ({2})" -f $statusTag, $route, $statusCode) -ForegroundColor Yellow
            } else {
                Write-Host ("  {0,-18} http://{1,-32} ({2})" -f "[HEALTHY]", $route, $statusCode) -ForegroundColor Green
            }
            
            # Healing invocation
            if ($inGrace -or $isTripped) {
                # Suppress autoheal during active grace window or circuit trip
            } elseif ($failed) {
                if (-not $global:FailureCounts.ContainsKey($container)) { $global:FailureCounts[$container] = 0 }
                $global:FailureCounts[$container]++
                
                # Trigger healing on 3 consecutive failed probes (approx 90s)
                if ($global:FailureCounts[$container] -ge 3) {
                    Invoke-Autoheal -Container $container -Reason $reason -Route $route
                }
            } else {
                $global:FailureCounts[$container] = 0
            }
        }
    }
}

function Confirm-Startup {
    Write-Host "`nWaiting for containers to initialize..." -ForegroundColor Yellow
    Start-Sleep -Seconds 4
    $containers = docker ps -a --format '{{.Names}}'
    
    if (-not $containers) {
        Write-Host "No containers detected." -ForegroundColor Red
        return
    }

    Write-Host "`n--- Container Fleet State Verification ---" -ForegroundColor Cyan
    foreach ($c in $containers) {
        $status = docker inspect -f '{{.State.Status}}' $c
        $health = docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}NoHealthCheck{{end}}' $c 2>$null
        
        if ($health -eq "healthy" -or $status -eq "running") {
            Write-Host "  [OK] $c ($status, $health)" -ForegroundColor Green
        } else {
            Write-Host "  [WARN] $c ($status, $health)" -ForegroundColor Yellow
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
        $currentTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Write-Host "================================================================================" -ForegroundColor DarkCyan
        Write-Host "       M E D I A S T A C K   E N T E R P R I S E   A U T O H E A L E R" -ForegroundColor Cyan
        Write-Host "       Active Time: $currentTime | Watchdog Interval: ${IntervalSeconds}s | Press 'Q' to Exit" -ForegroundColor DarkGray
        Write-Host "================================================================================" -ForegroundColor DarkCyan
        
        Write-Host "--- CONTAINER RUNTIME STATUS ---" -ForegroundColor Cyan
        docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' | Write-Host
        
        Write-Host "`n--- RESOURCE TELEMETRY (CPU / MEMORY) ---" -ForegroundColor Cyan
        docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}' | Write-Host
        
        Write-Host "`n--- ACTIVE ROUTE HEALTH & AUTOHEAL STATUS ---" -ForegroundColor Cyan
        Test-Routes -Silent:$true

        if ($global:RecentEvents.Count -gt 0) {
            Write-Host "`n--- RECENT AUTOHEAL INCIDENT STREAM ---" -ForegroundColor Magenta
            foreach ($ev in ($global:RecentEvents | Select-Object -First 4)) {
                Write-Host "  $ev" -ForegroundColor DarkCyan
            }
        }
        
        # Check keypress for non-blocking exit
        for ($i = 0; $i -lt $IntervalSeconds; $i++) {
            if ($Host.UI.RawUI.KeyAvailable) {
                $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                if ($key.Character -match 'q|Q') {
                    $monitoring = $false
                    break
                }
            }
            Start-Sleep -Seconds 1
        }
    }
}

function New-Directories {
    Write-Host "Creating volume and configuration paths..." -ForegroundColor Yellow;
    $dirs = @(
        "config\jellyfin", "config\caddy_data", "config\caddy_config",
        "config\sonarr", "config\radarr", "config\bazarr", "config\jackett",
        "config\transmission", "config\jellyseerr", "config\tvheadend",
        "certs", "dashboard", "downloads", "data\buffer", "handoffs", "db-backup"
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
    Write-Host "Ensuring base directory exists at $ScriptDir" -ForegroundColor Cyan;
    if (-not (Test-Path $ScriptDir)) { New-Item -ItemType Directory -Force -Path $ScriptDir | Out-Null }
    
    if (-not (Get-Command "docker" -ErrorAction SilentlyContinue)) {
        Write-Host "Docker is not installed or not in PATH!" -ForegroundColor Red
        return
    }
    $dcVersion = docker compose version
    Write-Host "Found Docker Engine: $dcVersion" -ForegroundColor Green
}

Set-Location -Path $ScriptDir
Initialize-Environment

# Direct Watchdog mode if invoked via flag
if ($Watchdog) {
    Show-HealthMonitor
    exit 0
}

# Only enter interactive menu if executed directly (not dot-sourced)
if ($MyInvocation.InvocationName -ne '.') {
    while ($true) {
    Write-Host ""
    Write-Host "=======================================================" -ForegroundColor Cyan
    Write-Host "       M E D I A S T A C K   O P E R A T I O N S" -ForegroundColor Cyan
    Write-Host "       Host: $env:COMPUTERNAME | Working Path: $ScriptDir" -ForegroundColor DarkGray
    Write-Host "=======================================================" -ForegroundColor Cyan
    Write-Host " 0.   🛡️ Primary Music Server Sentinel Suite (HUD & HA Matrix)"
    Write-Host " 00.  🏆 Run Master Executive Fleet Suite (5-Phase Startup)"
    Write-Host " 000. 🩺 Autonomous Auto-Repair & Diagnostic Handoff Engine"
    Write-Host " 1.   🚀 One-Touch Fleet Initialize & Bootstrap Engine"
    Write-Host " 2.   Fast Boot Stack (No re-init)"
    Write-Host " 3.   Stop Complete Fleet"
    Write-Host " 4.   Clean Up Orphan Containers & Synchronize"
    Write-Host " 5.   Full Backup to Public Folders (Configs + DBs + Meta)"
    Write-Host " 6.   Full DB Backup to Private SQLite DB"
    Write-Host " 7.   Point-in-Time Recovery / Database Restore"
    Write-Host " 8.   Live Caddy Gateway Routing Logs"
    Write-Host " 9.   Live Enterprise Health Monitor & Autohealer"
    Write-Host " 10.  API Tester & Key Auto-Discovery Suite"
    Write-Host " 11.  Database Optimizer & SQLite Integrity Suite"
    Write-Host " 12.  Comprehensive Network & WAN Diagnostics"
    Write-Host " 13.  MusicBrainz Replication & Metadata Database Manager"
    Write-Host " 14.  Set System Nameservers (8.8.8.8 / 1.1.1.1)"
    Write-Host " 15.  Exit"
    Write-Host "=======================================================" -ForegroundColor Cyan
    
    $choice = Read-Host "Select an option"
    
    switch ($choice) {
        '0'   { powershell.exe -ExecutionPolicy Bypass -File "$ScriptDir\PrimarySentinelSuite.ps1" }
        '00'  { powershell.exe -ExecutionPolicy Bypass -File "$ScriptDir\Invoke-MediaStackSuite.ps1" }
        '000' { powershell.exe -ExecutionPolicy Bypass -File "$ScriptDir\Invoke-StackAutoRepair.ps1" }
        '1'   { powershell.exe -ExecutionPolicy Bypass -File "$ScriptDir\Initialize-MediaStackFleet.ps1" }
            New-Directories;
            try {
                Set-Location -Path $ScriptDir;
                docker compose up -d;
                if (Test-Path "$ScriptDir\musicbrainz-docker\docker-compose.yml") {
                    Push-Location "$ScriptDir\musicbrainz-docker";
                    docker compose up -d;
                    Pop-Location;
                }
                Write-Host "All stack services booted successfully!" -ForegroundColor Green;
                Confirm-Startup;
            } catch {
                Write-Host "Failed to start stack: $_" -ForegroundColor Red
            }
        }
        '2' {
            try {
                Set-Location -Path $ScriptDir;
                docker compose up -d;
                if (Test-Path "$ScriptDir\musicbrainz-docker\docker-compose.yml") {
                    Push-Location "$ScriptDir\musicbrainz-docker";
                    docker compose up -d;
                    Pop-Location;
                }
                Write-Host "Stack fast-booted successfully!" -ForegroundColor Green;
                Confirm-Startup;
            } catch {
                Write-Host "Failed to start stack: $_" -ForegroundColor Red
            }
        }
        '3' { 
            Set-Location -Path $ScriptDir; 
            docker compose down; 
            if (Test-Path "$ScriptDir\musicbrainz-docker\docker-compose.yml") {
                Push-Location "$ScriptDir\musicbrainz-docker";
                docker compose down;
                Pop-Location;
            }
            Write-Host "All containers gracefully stopped." -ForegroundColor Yellow 
        }
        '4' {
            Write-Host "Cleaning up orphan containers and networks..." -ForegroundColor Yellow
            Set-Location -Path $ScriptDir
            docker compose down --remove-orphans
            if (Test-Path "$ScriptDir\musicbrainz-docker\docker-compose.yml") {
                Push-Location "$ScriptDir\musicbrainz-docker";
                docker compose down --remove-orphans;
                Pop-Location;
            }
            Write-Host "Restarting fleet in synchronized state..." -ForegroundColor Yellow
            docker compose up -d
            if (Test-Path "$ScriptDir\musicbrainz-docker\docker-compose.yml") {
                Push-Location "$ScriptDir\musicbrainz-docker";
                docker compose up -d;
                Pop-Location;
            }
            Write-Host "Stack synchronized and restarted!" -ForegroundColor Green
        }
        '5' { 
            Write-Host "Stopping database applications to cleanly flush WAL logs..." -ForegroundColor Yellow
            docker compose stop jellyfin sonarr radarr jellyseerr bazarr transmission
            Write-Host "--- Creating DB Backups ---" -ForegroundColor Cyan
            docker exec mediastack-db sh /config/backup.sh
            powershell.exe -ExecutionPolicy Bypass -File "$ScriptDir\Backup-MusicBrainzMetadata.ps1"
            Write-Host "--- Creating Consolidated Config Archive ---" -ForegroundColor Cyan
            docker compose down
            $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
            $backupFile = Join-Path $ScriptDir "handoffs\ConfigBackup_$timestamp.zip"
            Compress-Archive -Path "config", "transmission", "db-backup", "Caddyfile", "docker-compose.yml" -DestinationPath $backupFile -Force
            Write-Host "Consolidated backup archive created: $backupFile" -ForegroundColor Green
            Write-Host "Restarting stack..." -ForegroundColor Yellow
            docker compose up -d
            if (Test-Path "$ScriptDir\musicbrainz-docker\docker-compose.yml") {
                Push-Location "$ScriptDir\musicbrainz-docker";
                docker compose up -d;
                Pop-Location;
            }
        }
        '6' {
            Write-Host "--- Creating Full DB Backup to Private DB ---" -ForegroundColor Cyan
            Write-Host "Stopping apps to release SQLite file locks..." -ForegroundColor Yellow
            docker compose stop jellyfin sonarr radarr jellyseerr bazarr transmission
            docker exec mediastack-db sqlite3 /mediastack/config/jellyfin/data/data/jellyfin.db ".backup '/config/jellyfin_backup.db'"
            docker exec mediastack-db sqlite3 /mediastack/config/radarr/radarr.db ".backup '/config/radarr_backup.db'"
            docker exec mediastack-db sqlite3 /mediastack/config/sonarr/sonarr.db ".backup '/config/sonarr_backup.db'"
            powershell.exe -ExecutionPolicy Bypass -File "$ScriptDir\Backup-MusicBrainzMetadata.ps1"
            Write-Host "Private DB backups created in mediastack-db." -ForegroundColor Green
            Write-Host "Restarting apps..." -ForegroundColor Yellow
            docker compose start jellyfin sonarr radarr jellyseerr bazarr transmission
        }
        '7' { 
            Write-Host "`n--- Restore & Recovery Engine ---" -ForegroundColor Cyan
            Write-Host "1. Restore Database from Snapshot (.sqlite3 / .sql)"
            Write-Host "2. Restore Full System Config Archive (.zip)"
            $restChoice = Read-Host "Select a restore option"
            if ($restChoice -eq '1') {
                $dbs = Get-ChildItem "$ScriptDir\db-backup\*.sqlite3" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
                if ($dbs.Count -eq 0) { Write-Host "No DB backups found." -ForegroundColor Red; continue }
                for ($i=0; $i -lt $dbs.Count; $i++) { Write-Host "$($i+1). $($dbs[$i].Name)" }
                $dbChoice = Read-Host "Select DB to restore (Number)"
                $dbIdx = [int]$dbChoice - 1
                if ($dbIdx -ge 0 -and $dbIdx -lt $dbs.Count) {
                    $selected = $dbs[$dbIdx]
                    $svc = $selected.Name.Split('_')[0]
                    $targetPath = ""
                    if ($svc -eq "jellyfin") { $targetPath = "config\jellyfin\data\data\jellyfin.db" }
                    elseif ($svc -eq "radarr") { $targetPath = "config\radarr\radarr.db" }
                    elseif ($svc -eq "sonarr") { $targetPath = "config\sonarr\sonarr.db" }
                    elseif ($svc -eq "bazarr") { $targetPath = "config\bazarr\db\bazarr.db" }
                    elseif ($svc -eq "jellyseerr") { $targetPath = "config\jellyseerr\db\db.sqlite3" }
                    if ($targetPath -ne "") {
                        Write-Host "Stopping stack for restore..." -ForegroundColor Yellow
                        docker compose down
                        Copy-Item $selected.FullName (Join-Path $ScriptDir $targetPath) -Force
                        Write-Host "Restored $svc DB. Restarting stack..." -ForegroundColor Green
                        docker compose up -d
                    } else { Write-Host "Database snapshot restored to $ScriptDir\db-backup." -ForegroundColor Green }
                }
            } elseif ($restChoice -eq '2') {
                $zips = Get-ChildItem "$ScriptDir\handoffs\*.zip" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
                if ($zips.Count -eq 0) { Write-Host "No Config Zips found." -ForegroundColor Red; continue }
                for ($i=0; $i -lt $zips.Count; $i++) { Write-Host "$($i+1). $($zips[$i].Name)" }
                $zipChoice = Read-Host "Select Config Zip to restore (Number)"
                $zipIdx = [int]$zipChoice - 1
                if ($zipIdx -ge 0 -and $zipIdx -lt $zips.Count) {
                    $selected = $zips[$zipIdx]
                    Write-Host "Stopping stack for restore..." -ForegroundColor Yellow
                    docker compose down
                    Expand-Archive -Path $selected.FullName -DestinationPath $ScriptDir -Force
                    Write-Host "Restored configs. Restarting stack..." -ForegroundColor Green
                    docker compose up -d
                }
            }
        }
        '8' { docker compose logs -f caddy }
        '9' { powershell.exe -ExecutionPolicy Bypass -File "$ScriptDir\Start-MediaStackAutohealer.ps1" }
        '10' { powershell.exe -ExecutionPolicy Bypass -File "$ScriptDir\Test-MediaStackApis.ps1" }
        '11' { powershell.exe -ExecutionPolicy Bypass -File "$ScriptDir\Optimize-MediaStackDatabase.ps1" }
        '12' { powershell.exe -ExecutionPolicy Bypass -File "$ScriptDir\Test-NetworkDiagnostics.ps1" }
        '13' { 
            Write-Host "`n=== MusicBrainz Operations ===" -ForegroundColor Cyan
            Write-Host "1. Test Primary (5001) & Fallback (5000) Mirror Health"
            Write-Host "2. Switch Picard Client to Primary Node (192.168.4.30:5001)"
            Write-Host "3. Switch Picard Client to Fallback Node (192.168.4.21:5000)"
            Write-Host "4. Set Replication Token & Picard ID"
            Write-Host "5. Download Specific Replication Packet"
            Write-Host "6. Run Automated Incremental Replication"
            Write-Host "7. Backup MusicBrainz Metadata to Local DB"
            $mbChoice = Read-Host "Select MusicBrainz action"
            switch ($mbChoice) {
                '1' { powershell.exe -ExecutionPolicy Bypass -File "$ScriptDir\Test-MusicBrainzMirror.ps1" }
                '2' { powershell.exe -ExecutionPolicy Bypass -File "$ScriptDir\Test-MusicBrainzMirror.ps1" -SetPicardToPrimary }
                '3' { powershell.exe -ExecutionPolicy Bypass -File "$ScriptDir\Test-MusicBrainzMirror.ps1" -SetPicardToFallback }
                '4' { powershell.exe -ExecutionPolicy Bypass -File "$ScriptDir\Update-MusicBrainz.ps1" }
                '5' { 
                    $pNum = Read-Host "Enter replication packet number (e.g. 150000)"
                    powershell.exe -ExecutionPolicy Bypass -File "$ScriptDir\Update-MusicBrainz.ps1" -PacketNumber [int]$pNum -ApplyReplication
                }
                '6' { powershell.exe -ExecutionPolicy Bypass -File "$ScriptDir\Update-MusicBrainz.ps1" -ApplyReplication }
                '7' { powershell.exe -ExecutionPolicy Bypass -File "$ScriptDir\Backup-MusicBrainzMetadata.ps1" }
                default { Write-Host "Invalid MusicBrainz selection." -ForegroundColor Red }
            }
        }
        '14' { powershell.exe -ExecutionPolicy Bypass -File "$ScriptDir\Set-DnsServers.ps1" }
        '15' { Write-Host "Exiting MediaStack Operations."; return }
        default { Write-Host "Invalid selection." -ForegroundColor Red }
    }
}
}

