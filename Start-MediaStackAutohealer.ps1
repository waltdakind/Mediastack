# ==============================================================================
# Start-MediaStackAutohealer.ps1 - Primary Multi-Node Continuous Autohealing Sentinel
# Nodes: VOLTAIREDEUX (192.168.4.30) <---> VOLTAIREUN (192.168.4.21)
# ==============================================================================
param(
    [int]$IntervalSeconds = 25,
    [switch]$Daemon,
    [switch]$RunOnce,
    [string]$ConfigDir = "$env:SystemDrive\MediastackConfig"
)

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::InputEncoding  = [System.Text.Encoding]::UTF8

$global:RestartHistory  = @{}
$global:CircuitBreakers = @{}
$global:GracePeriods    = @{}
$global:FailureCounts   = @{}
$global:EventStream     = [System.Collections.ArrayList]::new()

$PrimaryNodeIp   = "192.168.4.21"
$HdhomerunIp     = "192.168.4.45"

# --- HELPER: Ingest Autoheal Incident to Database & HUD Stream ---
function Write-AutohealIncident {
    param(
        [string]$Target,
        [string]$Reason,
        [string]$Action,
        [string]$Status = "HEALED",
        [string]$Details = ""
    )
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $msg = "[$ts] [$Status] $Target : $Reason -> $Action"
    [void]$global:EventStream.Insert(0, $msg)
    while ($global:EventStream.Count -gt 25) { [void]$global:EventStream.RemoveAt(25) }

    try {
        $sqlInit = "CREATE TABLE IF NOT EXISTS autoheal_events_log (id INTEGER PRIMARY KEY AUTOINCREMENT, event_timestamp TEXT NOT NULL, container_name TEXT NOT NULL, trigger_reason TEXT, action_taken TEXT, status TEXT, details TEXT); "
        $cleanTgt = $Target -replace "'", "''"
        $cleanRsn = $Reason -replace "'", "''"
        $cleanAct = $Action -replace "'", "''"
        $cleanDet = $Details -replace "'", "''"
        $sqlInsert = "INSERT INTO autoheal_events_log (event_timestamp, container_name, trigger_reason, action_taken, status, details) VALUES ('$ts', '$cleanTgt', '$cleanRsn', '$cleanAct', '$Status', '$cleanDet'); "
        docker exec mediastack-db sqlite3 /config/mediastack_backup.db "$sqlInit $sqlInsert" 2>$null
    } catch { }
}

# --- PRIMARY REMEDIATION & HEALING FUNCTION ---
function Invoke-AutohealAction {
    param(
        [string]$Container,
        [string]$Reason,
        [string]$Endpoint = ""
    )

    $now = Get-Date
    $HandoffsDir = Join-Path $PSScriptRoot "handoffs"
    if (-not (Test-Path $HandoffsDir)) { New-Item -ItemType Directory -Force -Path $HandoffsDir | Out-Null }

    # 1. Circuit Breaker Check (Max 4 restarts within rolling 15m)
    if (-not $global:RestartHistory.ContainsKey($Container)) {
        $global:RestartHistory[$Container] = [System.Collections.ArrayList]::new()
    }
    $history = $global:RestartHistory[$Container]
    $cutoff = $now.AddMinutes(-15)
    for ($i = $history.Count - 1; $i -ge 0; $i--) {
        if ($history[$i] -lt $cutoff) { [void]$history.RemoveAt($i) }
    }

    if ($history.Count -ge 4) {
        $global:CircuitBreakers[$Container] = $true
        $global:GracePeriods[$Container] = $now.AddMinutes(5)
        Write-AutohealIncident -Target $Container -Reason $Reason -Action "Circuit Breaker Tripped (5m backoff applied)" -Status "BLOCKED"
        return
    }

    [void]$history.Add($now)
    $global:CircuitBreakers[$Container] = $false

    # 2. Gather Root Cause Diagnostics
    $recentLogs = cmd.exe /c "docker logs --tail 100 --timestamps $Container 2>&1"
    $isDbLock = ($recentLogs -match "database is locked" -or $recentLogs -match "disk I/O error" -or $recentLogs -match "sqlite3.OperationalError")
    $actionTaken = "Docker Restart"

    # 3. Apply Targeted Remediation
    if ($Container -eq "caddy") {
        docker exec caddy caddy reload --config /etc/caddy/Caddyfile 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            $actionTaken = "Caddy Zero-Downtime Reload"
        } else {
            docker restart caddy 2>&1 | Out-Null
            $actionTaken = "Caddy Hard Container Restart"
        }
    } elseif ($isDbLock) {
        docker stop $Container 2>&1 | Out-Null
        Start-Sleep -Seconds 2
        Get-ChildItem -Path "$ConfigDir\$Container" -Recurse -Filter "*.db-journal" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
        docker start $Container 2>&1 | Out-Null
        $actionTaken = "SQLite Lock Purge & Clean Reboot"
    } else {
        docker restart $Container 2>&1 | Out-Null
        $actionTaken = "Container Restart"
    }

    # 4. Generate AI Diagnostic RCA Document
    $rcaFile = "$HandoffsDir\Autoheal_RCA_${Container}_$($now.ToString('yyyyMMdd_HHmmss')).md"
    $rcaContent = @"
# MediaStack Autoheal RCA Incident Report: $Container

| Parameter | Value |
| :--- | :--- |
| **Container Target** | $Container |
| **Affected Endpoint** | $Endpoint |
| **Incident Timestamp** | $($now.ToString('yyyy-MM-dd HH:mm:ss')) |
| **Trigger Reason** | $Reason |
| **Remediation Action** | $actionTaken |
| **Circuit Breaker Status** | Normal ($($history.Count)/4 attempts in 15m) |

---

## Recent Container Logs
````text
$recentLogs
````

---
*Generated by MediaStack Primary Autohealer Sentinel.*
"@
    Set-Content -Path $rcaFile -Value $rcaContent -Encoding UTF8

    # 5. Set 60-second grace period
    $global:GracePeriods[$Container] = $now.AddSeconds(60)
    $global:FailureCounts[$Container] = 0

    Write-AutohealIncident -Target $Container -Reason $Reason -Action $actionTaken -Status "HEALED" -Details "RCA saved to $rcaFile"
}

# --- PRIMARY SWEEP FUNCTION ---
function Invoke-AutohealSweep {
    $now = Get-Date

    # 1. Local Container Fleet State
    $containers = docker ps -a --format "{{.Names}}|{{.Status}}" 2>$null
    $containerTable = @{}
    foreach ($line in $containers) {
        $parts = $line -split "\|", 2
        if ($parts.Count -eq 2) {
            $containerTable[$parts[0]] = $parts[1]
        }
    }

    # 2. Local L7 Service Endpoints to Monitor
    $serviceEndpoints = @(
        @{ Name="Caddy Gateway";    Container="caddy";         Route="voltairedeux.local";         Path=""; Expected=200 },
        @{ Name="Homepage Hub";     Container="homepage";      Route="homepage.voltairedeux.local"; Path=""; Expected=200 },
        @{ Name="API Gateway";      Container="api-gateway";   Route="api.voltairedeux.local";      Path="/api/system/status"; Expected=200 },
        @{ Name="Jellyfin Stream";  Container="jellyfin";      Route="jellyfin.voltairedeux.local"; Path="/health"; Expected=200 },
        @{ Name="Radarr Movies";    Container="radarr";        Route="radarr.voltairedeux.local";   Path="/ping"; Expected=200 },
        @{ Name="Sonarr TV";        Container="sonarr";        Route="sonarr.voltairedeux.local";   Path="/ping"; Expected=200 },
        @{ Name="Prowlarr Index";   Container="prowlarr";      Route="prowlarr.voltairedeux.local"; Path="/ping"; Expected=200 },
        @{ Name="Jellyseerr Req";   Container="jellyseerr";    Route="jellyseerr.voltairedeux.local"; Path="/api/v1/status"; Expected=200 },
        @{ Name="Bazarr Subs";      Container="bazarr";        Route="bazarr.voltairedeux.local";   Path=""; Expected=200 },
        @{ Name="Transmission";     Container="transmission";  Route="transmission.voltairedeux.local"; Path="/transmission/web/"; Expected=200 },
        @{ Name="TVHeadend Tuner";  Container="tvheadend";     Route="tvheadend.voltairedeux.local"; Path=""; Expected=302 },
        @{ Name="HDHomeRun Gateway"; Container="caddy";        Route="hdhomerun.voltairedeux.local"; Path="/discover.json"; Expected=200 },
        @{ Name="SQLite DB Web";    Container="mediastack-db"; Route="db.voltairedeux.local";      Path=""; Expected=200 },
        @{ Name="MusicBrainz (Local)"; Container="musicbrainz"; Route="musicbrainz.voltairedeux.local"; Path=""; Expected=500 }
    )

    $results = @()

    foreach ($svc in $serviceEndpoints) {
        $cName = $svc.Container
        $route = $svc.Route
        $path  = if ($svc.Path) { $svc.Path } else { "/" }
        
        $cStatus = if ($containerTable.ContainsKey($cName)) { $containerTable[$cName] } else { "NOT FOUND" }
        $isContainerDead = ($cStatus -like "*Exited*" -or $cStatus -eq "NOT FOUND" -or $cStatus -like "*Dead*")

        # L7 HTTP Probe
        $httpCode = "000"
        $failed = $false
        $reason = ""

        try {
            $httpCode = (curl.exe -s -o NUL -w "%{http_code}" --max-time 4 -H "Host: $route" "http://localhost:80$path")
            $cInt = [int]$httpCode

            if ($cInt -eq 0 -or $cInt -eq 000) {
                $failed = $true
                $reason = "Connection Refused (000)"
            } elseif ($cInt -ge 502 -and $cInt -le 504) {
                $failed = $true
                $reason = "Bad Gateway ($httpCode)"
            } elseif ($cName -ne "musicbrainz" -and $cInt -ge 500) {
                $failed = $true
                $reason = "Backend Internal Server Error ($httpCode)"
            }
        } catch {
            $failed = $true
            $reason = $_.Exception.Message
        }

        # Autoheal Decision Logic
        $inGrace = ($global:GracePeriods.ContainsKey($cName) -and $global:GracePeriods[$cName] -gt $now)
        $isTripped = ($global:CircuitBreakers.ContainsKey($cName) -and $global:CircuitBreakers[$cName])

        if ($isContainerDead) {
            $failed = $true
            $reason = "Container State: $cStatus"
            if (-not $inGrace -and -not $isTripped) {
                Invoke-AutohealAction -Container $cName -Reason $reason -Endpoint "http://$route$path"
            }
        } elseif ($failed) {
            if (-not $global:FailureCounts.ContainsKey($cName)) { $global:FailureCounts[$cName] = 0 }
            $global:FailureCounts[$cName]++

            if ($global:FailureCounts[$cName] -ge 2 -and -not $inGrace -and -not $isTripped) {
                Invoke-AutohealAction -Container $cName -Reason $reason -Endpoint "http://$route$path"
            }
        } else {
            $global:FailureCounts[$cName] = 0
        }

        $statusTag = if ($isTripped) { "CIRCUIT_TRIPPED" } elseif ($inGrace) { "GRACE_PERIOD" } elseif ($failed) { "UNHEALTHY" } else { "HEALTHY" }

        $results += [PSCustomObject]@{
            Service   = $svc.Name
            Container = $cName
            Route     = "http://$route"
            HTTPCode  = $httpCode
            Runtime   = $cStatus
            Status    = $statusTag
        }
    }

    # 3. Cross-Node Telemetry Probe
    $primaryLan = Test-Connection -ComputerName $PrimaryNodeIp -Count 1 -Quiet -ErrorAction SilentlyContinue
    $tunerLan   = Test-Connection -ComputerName $HdhomerunIp -Count 1 -Quiet -ErrorAction SilentlyContinue

    $primaryMb = (curl.exe -s -o NUL -w "%{http_code}" --max-time 4 "http://${PrimaryNodeIp}:5000/")

    return [PSCustomObject]@{
        Services        = $results
        PrimaryLan      = $primaryLan
        TunerLan        = $tunerLan
        PrimaryMbCode   = $primaryMb
        Timestamp       = $now
    }
}

# --- 4. EXECUTION HANDLER ---
if ($RunOnce) {
    Write-Host "`nRunning Single-Pass Autoheal Sweep..." -ForegroundColor Yellow
    $res = Invoke-AutohealSweep
    Write-Host "`n--- LOCAL FLEET STATUS ---" -ForegroundColor Cyan
    foreach ($s in $res.Services) {
        $color = if ($s.Status -eq "HEALTHY") { "Green" } elseif ($s.Status -eq "GRACE_PERIOD") { "Yellow" } else { "Red" }
        Write-Host ("  [{0,-15}] {1,-20} -> HTTP {2,-4} ({3})" -f $s.Status, $s.Service, $s.HTTPCode, $s.Route) -ForegroundColor $color
    }

    $primStatus = if ($res.PrimaryLan) { "ONLINE" } else { "OFFLINE" }
    $tunerStatus = if ($res.TunerLan) { "ONLINE" } else { "OFFLINE" }
    $primColor = if ($res.PrimaryLan) { "Green" } else { "Red" }
    $mbColor = if ($res.PrimaryMbCode -eq "200") { "Green" } else { "Yellow" }
    $tunerColor = if ($res.TunerLan) { "Green" } else { "Red" }

    Write-Host "`n--- REMOTE NODE STATUS ---" -ForegroundColor Cyan
    Write-Host ("  Primary Node Link (192.168.4.21)       : {0}" -f $primStatus) -ForegroundColor $primColor
    Write-Host ("  Primary MusicBrainz (192.168.4.21:5000): HTTP {0}" -f $res.PrimaryMbCode) -ForegroundColor $mbColor
    Write-Host ("  Hardware HDHomeRun (192.168.4.45)      : {0}" -f $tunerStatus) -ForegroundColor $tunerColor
    exit 0
}

# --- 5. CONTINUOUS MONITOR HUD ---
$running = $true
while ($running) {
    $sweep = Invoke-AutohealSweep
    $curTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    if ($Daemon) {
        $healthyCount = ($sweep.Services | Where-Object { $_.Status -eq "HEALTHY" }).Count
        $pStat = if ($sweep.PrimaryLan) { "ONLINE" } else { "STANDBY" }
        Write-Host ("[{0}] [AUTOHEALER DAEMON] Heartbeat: {1}/{2} Services Healthy | Primary Peer (192.168.4.21): {3}" -f $curTime, $healthyCount, $sweep.Services.Count, $pStat)
    } else {
        Clear-Host
        Write-Host "================================================================================" -ForegroundColor DarkCyan
        Write-Host "       M E D I A S T A C K   M A S T E R   A U T O H E A L E R   H U D" -ForegroundColor Cyan
        Write-Host ("       Active Time: {0} | Interval: {1}s | Press 'Q' to Exit" -f $curTime, $IntervalSeconds) -ForegroundColor DarkGray
        Write-Host "================================================================================" -ForegroundColor DarkCyan

        $pStat = if ($sweep.PrimaryLan) { "ONLINE" } else { "OFFLINE" }
        $tStat = if ($sweep.TunerLan) { "ONLINE" } else { "OFFLINE" }
        $pCol = if ($sweep.PrimaryLan) { "Green" } else { "Red" }
        $tCol = if ($sweep.TunerLan) { "Green" } else { "Red" }

        Write-Host "`n--- MULTI-NODE INFRASTRUCTURE MATRIX ---" -ForegroundColor Cyan
        Write-Host "  Local Node    [192.168.4.30]  (VOLTAIREDEUX)   : ACTIVE (Gateway Port 80/443)" -ForegroundColor Green
        Write-Host ("  Primary Node  [192.168.4.21]  (VOLTAIREUN)     : {0} (MB Port 5000: HTTP {1})" -f $pStat, $sweep.PrimaryMbCode) -ForegroundColor $pCol
        Write-Host ("  Hardware Tuner[192.168.4.45]  (HDHomeRun)      : {0}" -f $tStat) -ForegroundColor $tCol

        Write-Host "`n--- LOCAL CONTAINER & L7 ROUTE HEALTH ---" -ForegroundColor Cyan
        foreach ($s in $sweep.Services) {
            $color = if ($s.Status -eq "HEALTHY") { "Green" } elseif ($s.Status -eq "GRACE_PERIOD") { "Yellow" } else { "Red" }
            Write-Host ("  [{0,-15}] {1,-20} -> HTTP {2,-4} ({3})" -f $s.Status, $s.Service, $s.HTTPCode, $s.Route) -ForegroundColor $color
        }

        if ($global:EventStream.Count -gt 0) {
            Write-Host "`n--- RECENT AUTOHEAL & REMEDIATION INCIDENT STREAM ---" -ForegroundColor Magenta
            foreach ($ev in ($global:EventStream | Select-Object -First 4)) {
                Write-Host ("  {0}" -f $ev) -ForegroundColor DarkCyan
            }
        }
    }

    # Non-blocking pause with Q key detection
    for ($i = 0; $i -lt $IntervalSeconds; $i++) {
        if (-not $Daemon -and $Host.UI.RawUI.KeyAvailable) {
            $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            if ($key.Character -match 'q|Q') {
                $running = $false
                break
            }
        }
        Start-Sleep -Seconds 1
    }
}
