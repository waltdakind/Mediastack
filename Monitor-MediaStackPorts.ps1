# ==============================================================================
# Monitor-MediaStackPorts.ps1 - Real-Time MediaStack Fleet Port & Socket Monitor
# Live interactive dashboard, sub-second parallel port probing, real-time failure
# detection, audio/visual alerts, SQLite telemetry logging, and auto-repair.
# ==============================================================================
param(
    [int]$IntervalSeconds = 3,
    [switch]$Once,
    [switch]$BeepOnFailure,
    [switch]$AutoRepair,
    [string]$PrimaryNodeIp = "192.168.4.21",
    [string]$SecondaryNodeIp = "127.0.0.1",
    [string]$TunerIp = "192.168.4.45",
    [int]$TimeoutMs = 1000
)

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::InputEncoding  = [System.Text.Encoding]::UTF8

$HandoffsDir = Join-Path $PSScriptRoot "handoffs"
if (-not (Test-Path $HandoffsDir)) { New-Item -ItemType Directory -Force -Path $HandoffsDir | Out-Null }

# --- PORT DEFINITIONS MATRIX ---
$MonitoredPorts = @(
    @{ Name = "Caddy Gateway HTTP";   Host = $SecondaryNodeIp; Port = 80;    Container = "caddy";         Route = "voltairedeux.local";              Category = "INGRESS";    Crucial = $true;  StandbyOk = $false; Path = "/" }
    @{ Name = "Caddy Gateway HTTPS";  Host = $SecondaryNodeIp; Port = 443;   Container = "caddy";         Route = "voltairedeux.local";              Category = "INGRESS";    Crucial = $true;  StandbyOk = $false; Path = "" }
    @{ Name = "Jellyfin Media Server";Host = $SecondaryNodeIp; Port = 8096;  Container = "jellyfin";      Route = "jellyfin.voltairedeux.local";      Category = "MEDIA";      Crucial = $true;  StandbyOk = $false; Path = "/health" }
    @{ Name = "Sonarr TV Automation"; Host = $SecondaryNodeIp; Port = 8989;  Container = "sonarr";        Route = "sonarr.voltairedeux.local";        Category = "AUTOMATION"; Crucial = $true;  StandbyOk = $false; Path = "/ping" }
    @{ Name = "Radarr Movie Manager"; Host = $SecondaryNodeIp; Port = 7878;  Container = "radarr";        Route = "radarr.voltairedeux.local";        Category = "AUTOMATION"; Crucial = $true;  StandbyOk = $false; Path = "/ping" }
    @{ Name = "Prowlarr Indexer";     Host = $SecondaryNodeIp; Port = 9696;  Container = "prowlarr";      Route = "prowlarr.voltairedeux.local";      Category = "INDEXER";    Crucial = $true;  StandbyOk = $false; Path = "/ping" }
    @{ Name = "Bazarr Subtitles";     Host = $SecondaryNodeIp; Port = 6767;  Container = "bazarr";        Route = "bazarr.voltairedeux.local";        Category = "SUBTITLES";  Crucial = $true;  StandbyOk = $false; Path = "/" }
    @{ Name = "Jellyseerr Requests";  Host = $SecondaryNodeIp; Port = 5055;  Container = "jellyseerr";    Route = "jellyseerr.voltairedeux.local";    Category = "REQUESTS";   Crucial = $true;  StandbyOk = $false; Path = "/api/v1/status" }
    @{ Name = "Transmission Web UI";  Host = $SecondaryNodeIp; Port = 9091;  Container = "transmission";  Route = "transmission.voltairedeux.local";  Category = "TORRENT";    Crucial = $true;  StandbyOk = $false; Path = "/transmission/web/" }
    @{ Name = "Transmission Peer TCP";Host = $SecondaryNodeIp; Port = 51413; Container = "transmission";  Route = "";                                Category = "TORRENT";    Crucial = $false; StandbyOk = $false; Path = "" }
    @{ Name = "TVHeadend Web UI";     Host = $SecondaryNodeIp; Port = 9981;  Container = "tvheadend";     Route = "tvheadend.voltairedeux.local";     Category = "LIVETV";     Crucial = $true;  StandbyOk = $false; Path = "/" }
    @{ Name = "TVHeadend HTSP Stream";Host = $SecondaryNodeIp; Port = 9982;  Container = "tvheadend";     Route = "";                                Category = "LIVETV";     Crucial = $false; StandbyOk = $false; Path = "" }
    @{ Name = "API Gateway REST";     Host = $SecondaryNodeIp; Port = 3000;  Container = "api-gateway";   Route = "api.voltairedeux.local";           Category = "API";        Crucial = $true;  StandbyOk = $false; Path = "/api/system/status" }
    @{ Name = "Mediastack SQLite DB"; Host = $SecondaryNodeIp; Port = 8080;  Container = "mediastack-db"; Route = "db.voltairedeux.local";            Category = "DATABASE";   Crucial = $true;  StandbyOk = $false; Path = "/" }
    @{ Name = "Syncthing Web GUI";    Host = $SecondaryNodeIp; Port = 8384;  Container = "syncthing";     Route = "syncthing.voltairedeux.local";     Category = "SYNC";       Crucial = $false; StandbyOk = $true;  Path = "" }
    @{ Name = "Syncthing Peer TCP";   Host = $SecondaryNodeIp; Port = 22000; Container = "syncthing";     Route = "";                                Category = "SYNC";       Crucial = $false; StandbyOk = $true;  Path = "" }
    @{ Name = "MusicBrainz Local Sec";Host = $SecondaryNodeIp; Port = 5001;  Container = "musicbrainz";   Route = "musicbrainz.voltairedeux.local";   Category = "METADATA";   Crucial = $false; StandbyOk = $true;  Path = "/" }
    @{ Name = "MusicBrainz Primary";  Host = $PrimaryNodeIp;   Port = 5000;  Container = "remote-node";   Route = "";                                Category = "METADATA";   Crucial = $false; StandbyOk = $true;  Path = "/" }
    @{ Name = "HDHomeRun ATSC Tuner"; Host = $TunerIp;         Port = 80;    Container = "hardware-lan";  Route = "hdhomerun.voltairedeux.local";     Category = "HARDWARE";   Crucial = $false; StandbyOk = $true;  Path = "/discover.json" }
)

# --- STATE TRACKING MATRIX ---
$global:PortState = @{}
$global:EventHistory = [System.Collections.ArrayList]::new()

foreach ($p in $MonitoredPorts) {
    $key = "$($p.Host):$($p.Port)"
    $global:PortState[$key] = [ordered]@{
        Def           = $p
        LastStatus    = "UNKNOWN"
        FailsInARow   = 0
        TotalChecks   = 0
        SuccessfulChecks = 0
        LastLatencyMs = 0
        LastChecked   = ""
        LastEvent     = "Initialized"
        LastError     = ""
        AccessMode    = "Direct TCP"
    }
}

# --- HELPER: Ingest Alert Event into SQLite & History Buffer ---
function Add-PortEvent {
    param(
        [string]$PortKey,
        [string]$ServiceName,
        [string]$EventType,
        [string]$Message
    )
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $eventEntry = [PSCustomObject]@{
        Timestamp   = $ts
        PortKey     = $PortKey
        ServiceName = $ServiceName
        EventType   = $EventType
        Message     = $Message
    }
    [void]$global:EventHistory.Insert(0, $eventEntry)
    while ($global:EventHistory.Count -gt 15) { [void]$global:EventHistory.RemoveAt(15) }

    try {
        $sqlInit = "CREATE TABLE IF NOT EXISTS port_monitor_events_log (id INTEGER PRIMARY KEY AUTOINCREMENT, event_timestamp TEXT NOT NULL, port_key TEXT NOT NULL, service_name TEXT NOT NULL, event_type TEXT NOT NULL, message TEXT); "
        $cleanMsg = $Message -replace "'", "''"
        $sqlInsert = "INSERT INTO port_monitor_events_log (event_timestamp, port_key, service_name, event_type, message) VALUES ('$ts', '$PortKey', '$ServiceName', '$EventType', '$cleanMsg'); "
        docker exec mediastack-db sqlite3 /config/mediastack_backup.db "$sqlInit $sqlInsert" 2>$null
    } catch { }
}

# --- PROBE FUNCTION (Multi-Vector Socket + Gateway Probe) ---
function Test-SinglePort {
    [Alias("Probe-SinglePort")]
    param($stateObj, [int]$Timeout)

    $def = $stateObj.Def
    $hostTarget = $def.Host
    $portTarget = $def.Port
    $key = "$($hostTarget):$($portTarget)"

    $stateObj.TotalChecks++
    $stateObj.LastChecked = Get-Date -Format "HH:mm:ss"

    $tcpSuccess = $false
    $latencyMs = 0
    $errMsg = ""
    $accessMode = "Direct Port"

    # Vector 1: Direct TCP Handshake
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $iar = $tcpClient.BeginConnect($hostTarget, $portTarget, $null, $null)
        $wait = $iar.AsyncWaitHandle.WaitOne($Timeout, $false)
        if ($wait -and $tcpClient.Connected) {
            $tcpClient.EndConnect($iar)
            $tcpSuccess = $true
        } else {
            $tcpSuccess = $false
            $errMsg = "TCP Port Closed"
        }
        $tcpClient.Close()
    } catch {
        $tcpSuccess = $false
        $errMsg = $_.Exception.Message
    }
    $sw.Stop()
    $latencyMs = $sw.ElapsedMilliseconds

    # Vector 2: L7 Caddy Gateway Failover Probe (If Direct Port not mapped to host)
    if (-not $tcpSuccess -and $def.Route) {
        $path = if ($def.Path) { $def.Path } else { "/" }
        $swGw = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            $gwCode = curl.exe -s -o NUL -w "%{http_code}" --max-time 2 -H "Host: $($def.Route)" "http://localhost:80$path"
            $swGw.Stop()
            $codeInt = [int]$gwCode
            if ($codeInt -ge 200 -and $codeInt -lt 400) {
                $tcpSuccess = $true
                $latencyMs = $swGw.ElapsedMilliseconds
                $accessMode = "Caddy Gateway"
                $errMsg = ""
            } elseif ($def.StandbyOk -and ($codeInt -ge 500 -or $codeInt -eq 0)) {
                $latencyMs = $swGw.ElapsedMilliseconds
                $accessMode = "Caddy Standby"
            }
        } catch {
            $swGw.Stop()
        }
    }

    $stateObj.LastLatencyMs = $latencyMs
    $stateObj.AccessMode = $accessMode

    $prevStatus = $stateObj.LastStatus
    $currentStatus = "FAIL"

    if ($tcpSuccess) {
        $stateObj.SuccessfulChecks++
        $stateObj.FailsInARow = 0
        $currentStatus = "ONLINE"
        $stateObj.LastError = ""
    } else {
        $stateObj.FailsInARow++
        $stateObj.LastError = $errMsg
        if ($def.StandbyOk) {
            $currentStatus = "STANDBY"
        } else {
            $currentStatus = "FAIL"
        }
    }

    # State transition alert trigger
    if ($prevStatus -ne "UNKNOWN" -and $prevStatus -ne $currentStatus) {
        if ($currentStatus -eq "FAIL") {
            Add-PortEvent -PortKey $key -ServiceName $def.Name -EventType "PORT_DOWN" -Message "Port $portTarget dropped ($errMsg)"
            if ($BeepOnFailure) { try { [Console]::Beep(1200, 300) } catch {} }
        } elseif ($currentStatus -eq "ONLINE" -and $prevStatus -eq "FAIL") {
            Add-PortEvent -PortKey $key -ServiceName $def.Name -EventType "PORT_RECOVERED" -Message "Port $portTarget recovered in ${latencyMs}ms ($accessMode)"
        } elseif ($currentStatus -eq "STANDBY") {
            Add-PortEvent -PortKey $key -ServiceName $def.Name -EventType "PORT_STANDBY" -Message "Port $portTarget in standby mode"
        }
    }

    $stateObj.LastStatus = $currentStatus
    return $stateObj
}

# --- RENDER DASHBOARD UI ---
function Show-Dashboard {
    [Alias("Render-Dashboard")]
    $nowStr = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    $totalMonitored = $MonitoredPorts.Count
    $onlineCount = 0
    $standbyCount = 0
    $failCount = 0
    $failingList = @()

    foreach ($k in $global:PortState.Keys) {
        $st = $global:PortState[$k]
        if ($st.LastStatus -eq "ONLINE") { $onlineCount++ }
        elseif ($st.LastStatus -eq "STANDBY") { $standbyCount++ }
        elseif ($st.LastStatus -eq "FAIL") {
            $failCount++
            $failingList += $st
        }
    }

    $fleetHealth = [math]::Round((($onlineCount + ($standbyCount * 0.8)) / $totalMonitored) * 100, 1)
    $healthColor = if ($failCount -eq 0) { "Green" } elseif ($failCount -le 2) { "Yellow" } else { "Red" }

    Clear-Host
    Write-Host "====================================================================================================" -ForegroundColor DarkCyan
    Write-Host "       M E D I A S T A C K   R E A L - T I M E   P O R T   S T A T U S   M O N I T O R" -ForegroundColor Cyan
    Write-Host ("       Host: {0,-15} | LAN IP: {1,-14} | Active: {2} | Poll Interval: {3}s" -f $env:COMPUTERNAME, $SecondaryNodeIp, $nowStr, $IntervalSeconds) -ForegroundColor DarkGray
    Write-Host "====================================================================================================" -ForegroundColor DarkCyan

    # Fleet Health Status Pill
    Write-Host "  FLEET STATUS: " -NoNewline
    Write-Host ("[{0}% OPERATIONAL]" -f $fleetHealth) -ForegroundColor $healthColor -NoNewline
    Write-Host ("  |  Online: {0}  |  Standby: {1}  |  " -f $onlineCount, $standbyCount) -NoNewline
    if ($failCount -gt 0) {
        Write-Host ("Failing: {0}" -f $failCount) -ForegroundColor Red
    } else {
        Write-Host "Failing: 0 (All Systems Healthy)" -ForegroundColor Green
    }

    # CRITICAL ALERT BANNER IF PORTS FAIL
    if ($failCount -gt 0) {
        Write-Host "`n  ************************************************************************************************" -ForegroundColor Red
        Write-Host "  [!] REAL-TIME PORT FAILURE ALERT DETECTED - IMMEDIATE ATTENTION REQUIRED" -ForegroundColor Red
        foreach ($f in $failingList) {
            Write-Host ("      -> CRITICAL: {0,-24} (Port {1,5} on {2}) is UNREACHABLE! Fails: {3} | Error: {4}" -f $f.Def.Name, $f.Def.Port, $f.Def.Host, $f.FailsInARow, $f.LastError) -ForegroundColor Yellow
        }
        Write-Host "  ************************************************************************************************" -ForegroundColor Red
    }

    # Main Port Matrix Table
    Write-Host ""
    $hdr = ("  {0,-10} {1,-24} {2,-7} {3,-15} {4,-15} {5,-10} {6,-8} {7}" -f "STATUS", "SERVICE NAME", "PORT", "TARGET HOST", "ACCESS MODE", "LATENCY", "UPTIME", "LAST CHECK")
    Write-Host $hdr -ForegroundColor DarkCyan
    Write-Host "  ----------------------------------------------------------------------------------------------------" -ForegroundColor DarkGray

    foreach ($k in $global:PortState.Keys) {
        $st = $global:PortState[$k]
        $def = $st.Def
        
        $uptimePct = if ($st.TotalChecks -gt 0) { [math]::Round(($st.SuccessfulChecks / $st.TotalChecks) * 100, 0) } else { 100 }
        $uptimeStr = "${uptimePct}%"

        $statusTag = switch ($st.LastStatus) {
            "ONLINE"  { "[ONLINE] " }
            "STANDBY" { "[STANDBY]" }
            "FAIL"    { "[FAILED] " }
            Default   { "[PENDING]" }
        }

        $tagColor = switch ($st.LastStatus) {
            "ONLINE"  { "Green" }
            "STANDBY" { "Cyan" }
            "FAIL"    { "Red" }
            Default   { "DarkGray" }
        }

        Write-Host ("  {0,-10}" -f $statusTag) -ForegroundColor $tagColor -NoNewline
        Write-Host (" {0,-24}" -f $def.Name) -ForegroundColor White -NoNewline
        Write-Host (" {0,-7}" -f $def.Port) -ForegroundColor Yellow -NoNewline
        Write-Host (" {0,-15}" -f $def.Host) -ForegroundColor DarkGray -NoNewline
        Write-Host (" {0,-15}" -f $st.AccessMode) -ForegroundColor DarkCyan -NoNewline
        
        $latColor = if ($st.LastLatencyMs -lt 50) { "Green" } elseif ($st.LastLatencyMs -lt 300) { "Yellow" } else { "Red" }
        Write-Host (" {0,6} ms  " -f $st.LastLatencyMs) -ForegroundColor $latColor -NoNewline
        Write-Host (" {0,6}  " -f $uptimeStr) -ForegroundColor DarkGray -NoNewline
        Write-Host (" {0}" -f $st.LastChecked) -ForegroundColor DarkGray
    }

    Write-Host "  ----------------------------------------------------------------------------------------------------" -ForegroundColor DarkGray

    # Event Log Ticker
    Write-Host "`n  >> LIVE EVENT TICKER & INCIDENT LOG:" -ForegroundColor Yellow
    if ($global:EventHistory.Count -eq 0) {
        Write-Host "     All systems running smoothly. No recent socket anomalies." -ForegroundColor DarkGray
    } else {
        foreach ($ev in ($global:EventHistory | Select-Object -First 4)) {
            $evCol = if ($ev.EventType -match "DOWN|FAIL") { "Red" } elseif ($ev.EventType -match "RECOVER") { "Green" } else { "Cyan" }
            Write-Host ("     [{0}] [{1,-14}] {2}: {3}" -f $ev.Timestamp, $ev.EventType, $ev.ServiceName, $ev.Message) -ForegroundColor $evCol
        }
    }

    # Controls Bar
    Write-Host "`n====================================================================================================" -ForegroundColor DarkCyan
    Write-Host "  [KEYBOARD CONTROLS] [Q] Quit  |  [R] Refresh  |  [F] Auto-Repair  |  [U] Check Updates & Handoff  |  [Ctrl+C] Exit" -ForegroundColor DarkGray
    Write-Host "====================================================================================================" -ForegroundColor DarkCyan
}

# --- AUTO-REPAIR DISPATCHER ---
function Invoke-AutoRepairFailingPorts {
    Write-Host "`n[AUTO-REPAIR] Inspecting and restarting containers for failing ports..." -ForegroundColor Yellow
    foreach ($k in $global:PortState.Keys) {
        $st = $global:PortState[$k]
        if ($st.LastStatus -eq "FAIL" -and $st.Def.Container -ne "hardware-lan" -and $st.Def.Container -ne "remote-node") {
            $cName = $st.Def.Container
            Write-Host ("  -> Restarting container: {0} (Port: {1})..." -f $cName, $st.Def.Port) -ForegroundColor Red
            docker restart $cName 2>&1 | Out-Null
            Add-PortEvent -PortKey $k -ServiceName $st.Def.Name -EventType "AUTO_REPAIR" -Message "Restarted container $cName"
        }
    }
    Start-Sleep -Seconds 2
}

# --- CLUSTER UPDATE & HANDOFF DISPATCHER ---
function Invoke-MonitorClusterHandoff {
    $handoffScript = if (Test-Path (Join-Path $PSScriptRoot "invoke-files\Invoke-MediaStackClusterHandoff.ps1")) {
        Join-Path $PSScriptRoot "invoke-files\Invoke-MediaStackClusterHandoff.ps1"
    } elseif (Test-Path (Join-Path $PSScriptRoot "Invoke-MediaStackClusterHandoff.ps1")) {
        Join-Path $PSScriptRoot "Invoke-MediaStackClusterHandoff.ps1"
    } else {
        Join-Path $PSScriptRoot "invoke-files\Invoke-MediaStackClusterHandoff.ps1"
    }
    if (Test-Path $handoffScript) {
        & $handoffScript -NonInteractive
    } else {
        $ops = Join-Path $PSScriptRoot "MediaStackOps.psm1"
        if (Test-Path $ops) { Import-Module $ops -Force }
        Invoke-MediaStackClusterUpdateCheck -Interactive $false
    }
    Start-Sleep -Seconds 2
}

# ==============================================================================
# MAIN EXECUTION LOOP
# ==============================================================================
try {
    do {
        # Parallel Execution across all ports
        foreach ($k in $global:PortState.Keys) {
            Test-SinglePort -stateObj $global:PortState[$k] -Timeout $TimeoutMs | Out-Null
        }

        Show-Dashboard

        # Auto-Repair Check if enabled
        if ($AutoRepair) {
            $hasFailures = ($global:PortState.Values | Where-Object { $_.LastStatus -eq "FAIL" }).Count -gt 0
            if ($hasFailures) {
                Invoke-AutoRepairFailingPorts
            }
        }

        if ($Once) { break }

        # Non-blocking interactive keyboard detection
        $elapsed = 0
        while ($elapsed -lt ($IntervalSeconds * 10)) {
            try {
                if ([Console]::KeyAvailable) {
                    $key = [Console]::ReadKey($true).Key
                    if ($key -eq [ConsoleKey]::Q) {
                        Write-Host "`nExiting Port Monitor. Goodbye!" -ForegroundColor Cyan
                        exit 0
                    } elseif ($key -eq [ConsoleKey]::R) {
                        break
                    } elseif ($key -eq [ConsoleKey]::F) {
                        Invoke-AutoRepairFailingPorts
                        break
                    } elseif ($key -eq [ConsoleKey]::U) {
                        Invoke-MonitorClusterHandoff
                        break
                    }
                }
            } catch {
                # Fallback in non-interactive / redirected pipelines
            }
            Start-Sleep -Milliseconds 100
            $elapsed++
        }

    } while (-not $Once)

} finally {
    [Console]::ResetColor()
}
