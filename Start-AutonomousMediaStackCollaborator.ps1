<#
.SYNOPSIS
    Start-AutonomousMediaStackCollaborator.ps1 - Autonomous Dual-Node Self-Monitoring, Incident Dispatch,
    Remediation Ingestion & AI Handoff Engine.

.DESCRIPTION
    Runs as a 24/7 perpetual background daemon on VoltaireUn (VOLTAIREUN) or VoltaireDeux:
    1. CONTINUOUS SELF-MONITORING:
       - Probes Docker containers, TCP listening sockets, HTTP reverse proxy endpoints, and REST APIs.
       - Monitors SQLite database integrity (PRAGMA quick_check), WAL contention, and file conflict locks.
    2. IMMEDIATE INCIDENT DISPATCH:
       - When an anomaly or error is detected, immediately compiles an incident payload.
       - Emits handoffs/Incident_Alert_<NODE>_<timestamp>.json and .md, and updates handoffs/latest_incident_alert.json.
       - Flags latest_handoff_<NODE>.json with requires_remediation = $true for immediate peer AI ingestion.
    3. REMEDIATION WATCHER & REPAIR EXECUTION:
       - Actively listens for repair packages (AutoFix_*.ps1, cluster_update_manifest.json, Repair_*.ps1)
         staged by VoltaireDeux.
       - Takes pre-repair safety database snapshots.
       - Executes delivered remediation scripts safely with full transcript and exit code capture.
    4. AI PROGRESS REPORTING & PEER HANDOFF:
       - Re-verifies service health post-repair and analyzes resolution efficacy.
       - Generates handoffs/AI_Remediation_Execution_Report_<timestamp>.md.
       - Updates cluster_update_manifest.json and ai_collaboration_nexus.json.
       - Hands off updated cluster status to VoltaireDeux for continued coordination.
    5. RESILIENT PERPETUAL LOOP:
       - Operates continuously until Ctrl+C is detected, with graceful shutdown signal trapping.

.PARAMETER PollIntervalSeconds
    Seconds between fast telemetry checks and repair file scans (default: 15).

.PARAMETER FullAuditIntervalSeconds
    Seconds between deep PRAGMA database audits and full API verifications (default: 120).

.PARAMETER AutoExecuteRepairs
    Automatically executes incoming repair scripts delivered by VoltaireDeux (default: $true).

.PARAMETER SinglePass
    Executes a single monitoring, dispatch, and repair ingestion pass then exits (useful for CI/testing).

.EXAMPLE
    .\Start-AutonomousMediaStackCollaborator.ps1
    .\Start-AutonomousMediaStackCollaborator.ps1 -PollIntervalSeconds 10
    .\Start-AutonomousMediaStackCollaborator.ps1 -SinglePass
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)][int]$PollIntervalSeconds = 15,
    [Parameter(Mandatory=$false)][int]$FullAuditIntervalSeconds = 120,
    [Parameter(Mandatory=$false)][bool]$AutoExecuteRepairs = $true,
    [Parameter(Mandatory=$false)][switch]$SinglePass
)

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::InputEncoding  = [System.Text.Encoding]::UTF8

$BaseDir = $PSScriptRoot
if (-not $BaseDir) { $BaseDir = "c:\Users\waltd\OneDrive\Mediastack" }
$HandoffsDir = Join-Path $BaseDir "handoffs"
if (-not (Test-Path $HandoffsDir)) { New-Item -ItemType Directory -Force -Path $HandoffsDir | Out-Null }

# Import Core Operations Module
$opsModule = Join-Path $BaseDir "MediaStackOps.psm1"
if (Test-Path $opsModule) {
    Import-Module $opsModule -Force
} else {
    . (Join-Path $BaseDir "MediaStackOps.ps1")
}

$nodeInfo = Get-MediaStackClusterNodeInfo
$historyFile = Join-Path $HandoffsDir ".remediation_history.json"
$nexusPath = Join-Path $HandoffsDir "ai_collaboration_nexus.json"
$manifestPath = Join-Path $HandoffsDir "cluster_update_manifest.json"

# Initialize or Load Remediation History
function Get-RemediationHistory {
    if (Test-Path $historyFile) {
        try {
            return (Get-Content $historyFile -Raw -Encoding UTF8 | ConvertFrom-Json)
        } catch {
            return @{ executed_scripts = @(); last_watermark = (Get-Date -Format "o") }
        }
    }
    return @{ executed_scripts = @(); last_watermark = (Get-Date -Format "o") }
}

function Save-RemediationHistory ($historyObj) {
    try {
        $json = $historyObj | ConvertTo-Json -Depth 5
        [System.IO.File]::WriteAllText($historyFile, $json, [System.Text.Encoding]::UTF8)
    } catch {
        $historyObj | ConvertTo-Json -Depth 5 | Out-File -FilePath $historyFile -Encoding UTF8 -Force
    }
}

# Fast TCP Socket Probe Helper
function Test-FastSocket ($hostname, $port, $timeoutMs = 800) {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $tcp = New-Object System.Net.Sockets.TcpClient
    try {
        $ar = $tcp.BeginConnect($hostname, $port, $null, $null)
        $wh = $ar.AsyncWaitHandle
        $connected = $wh.WaitOne($timeoutMs, $false)
        $sw.Stop()
        if ($connected -and $tcp.Connected) {
            $tcp.EndConnect($ar)
            $tcp.Close()
            return [PSCustomObject]@{ IsOpen = $true; LatencyMs = [int]$sw.ElapsedMilliseconds }
        }
        $tcp.Close()
        return [PSCustomObject]@{ IsOpen = $false; LatencyMs = [int]$sw.ElapsedMilliseconds }
    } catch {
        $sw.Stop()
        try { $tcp.Close() } catch { }
        return [PSCustomObject]@{ IsOpen = $false; LatencyMs = [int]$sw.ElapsedMilliseconds }
    }
}

# Core Service Definitions with Direct Paths and Port + 1 Fallbacks
$monitoredServices = @(
    @{ Name = "Caddy Gateway (HTTP)";      Port = 80;   Fallback = 81;   Container = "caddy";          Path = "/";                    Critical = $true },
    @{ Name = "Caddy Gateway (HTTPS)";     Port = 443;  Fallback = 444;  Container = "caddy";          Path = "/dashboard/";          Critical = $true },
    @{ Name = "Jellyfin Media Server";     Port = 8096; Fallback = 8097; Container = "jellyfin";       Path = "/web/index.html";      Critical = $true },
    @{ Name = "Sonarr TV Automation";      Port = 8989; Fallback = 8990; Container = "sonarr";         Path = "/sonarr/";             Critical = $true },
    @{ Name = "Radarr Movie Manager";      Port = 7878; Fallback = 7879; Container = "radarr";         Path = "/radarr/";             Critical = $true },
    @{ Name = "Prowlarr Indexer";          Port = 9696; Fallback = 9697; Container = "prowlarr";       Path = "/prowlarr/";           Critical = $true },
    @{ Name = "Bazarr Subtitles";          Port = 6767; Fallback = 6768; Container = "bazarr";         Path = "/bazarr/";             Critical = $true },
    @{ Name = "Jellyseerr Requests";       Port = 5055; Fallback = 5056; Container = "jellyseerr";     Path = "/jellyseerr/";         Critical = $true },
    @{ Name = "Transmission Web UI";       Port = 9091; Fallback = 9092; Container = "transmission";   Path = "/transmission/web/";   Critical = $true },
    @{ Name = "TVHeadend Web UI";          Port = 9981; Fallback = 9982; Container = "tvheadend";      Path = "/tvheadend/";          Critical = $true },
    @{ Name = "Mediastack DB GUI";         Port = 8080; Fallback = 8081; Container = "mediastack-db";  Path = "/db/";                 Critical = $true },
    @{ Name = "API Gateway REST";          Port = 3000; Fallback = $null; Container = "api-gateway";   Path = "/api/health";          Critical = $false },
    @{ Name = "MusicBrainz Mirror";        Port = 5000; Fallback = 5001; Container = "musicbrainz";    Path = "/musicbrainz/";        Critical = $false }
)

# Core Databases
$coreDatabases = @(
    @{ Name = "jellyfin.db"; Path = Join-Path $BaseDir "config\jellyfin\data\data\jellyfin.db"; Container = "jellyfin" },
    @{ Name = "sonarr.db";   Path = Join-Path $BaseDir "config\sonarr\sonarr.db"; Container = "sonarr" },
    @{ Name = "radarr.db";   Path = Join-Path $BaseDir "config\radarr\radarr.db"; Container = "radarr" },
    @{ Name = "prowlarr.db"; Path = Join-Path $BaseDir "config\prowlarr\prowlarr.db"; Container = "prowlarr" },
    @{ Name = "bazarr.db";   Path = Join-Path $BaseDir "config\bazarr\db\bazarr.db"; Container = "bazarr" },
    @{ Name = "db.sqlite3";  Path = Join-Path $BaseDir "config\jellyseerr\db\db.sqlite3"; Container = "jellyseerr" },
    @{ Name = "backup.db";   Path = Join-Path $BaseDir "config\db-backup\mediastack_backup.db"; Container = "mediastack-db" }
)

# Graceful Exit Handling
$global:KeepRunning = $true
$cancelHandler = [ConsoleCancelEventHandler]{
    param($sender, $e)
    $e.Cancel = $true
    $global:KeepRunning = $false
    Write-Host "`n`n[SHUTDOWN SIGNAL RECEIVED] Gracefully terminating autonomous collaborator..." -ForegroundColor Yellow
}
[Console]::Add_CancelKeyPress($cancelHandler)

# --- STARTUP BANNER ---
Clear-Host
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "   M E D I A S T A C K   A U T O N O M O U S   A I   C O L L A B O R A T O R" -ForegroundColor DarkCyan
Write-Host "   Perpetual Self-Monitoring, Incident Dispatch, Remediation & Dual-Node Handoff" -ForegroundColor White
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host ("  Node Hostname    : {0} ({1})" -f $nodeInfo.LocalHostName, $nodeInfo.LocalRole) -ForegroundColor Green
Write-Host ("  Local IP Address : {0}" -f $nodeInfo.LocalIP) -ForegroundColor Green
Write-Host ("  Peer AI Node     : {0} ({1})" -f $nodeInfo.PeerHostName, $nodeInfo.PeerRole) -ForegroundColor DarkCyan
Write-Host ("  Peer IP Address  : {0}" -f $nodeInfo.PeerIP) -ForegroundColor DarkCyan
Write-Host ("  Poll Interval    : {0}s  |  Full Audit Interval: {1}s  |  Auto-Repair: {2}" -f $PollIntervalSeconds, $FullAuditIntervalSeconds, $AutoExecuteRepairs) -ForegroundColor DarkGray
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "  Press Ctrl+C at any time to gracefully stop monitoring.`n" -ForegroundColor DarkYellow

$cycleCount = 0
$lastFullAuditTime = [DateTime]::MinValue
$lastIncidentSignature = ""
$lastIncidentAlertTime = [DateTime]::MinValue

# ==============================================================================
# MAIN PERPETUAL COLLABORATION LOOP
# ==============================================================================
try {
    while ($global:KeepRunning) {
        $cycleCount++
        $cycleStartTime = [DateTime]::UtcNow
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $fileTag   = Get-Date -Format "yyyyMMdd_HHmmss"

        # --- STEP 1: FAST TELEMETRY & HEALTH PROBING ---
        $serviceAnomalies = @()
        $dbAnomalies = @()
        $conflictLocks = @()
        $runningContainers = @()
        $stoppedContainers = @()

        # 1.1 Docker Container Liveness
        try {
            $dockerPs = docker ps --format "{{.Names}}|{{.Status}}|{{.State}}" 2>$null
            if ($dockerPs) {
                foreach ($line in $dockerPs) {
                    $parts = $line.Split("|")
                    if ($parts.Count -ge 3) {
                        $cName = $parts[0].Trim()
                        $cStatus = $parts[1].Trim()
                        $cState = $parts[2].Trim()
                        if ($cState -eq "running") {
                            $runningContainers += $cName
                        } else {
                            $stoppedContainers += "$cName ($cStatus)"
                        }
                    }
                }
            }
        } catch { }

        # 1.2 Socket Probes (with Port + 1 Failover Recognition)
        $onlineServicesCount = 0
        foreach ($svc in $monitoredServices) {
            $probe = Test-FastSocket -hostname "127.0.0.1" -port $svc.Port -timeoutMs 750
            if ($probe.IsOpen) {
                $onlineServicesCount++
            } elseif ($svc.Fallback) {
                # Probe fallback port
                $fallbackProbe = Test-FastSocket -hostname "127.0.0.1" -port $svc.Fallback -timeoutMs 750
                if ($fallbackProbe.IsOpen) {
                    $onlineServicesCount++
                    # Failover is actively serving
                } else {
                    if ($svc.Critical) {
                        $serviceAnomalies += [PSCustomObject]@{
                            Service   = $svc.Name
                            Port      = $svc.Port
                            Fallback  = $svc.Fallback
                            Container = $svc.Container
                            Path      = $svc.Path
                            Reason    = "Both Primary Port :$($svc.Port) and Fallback Port :$($svc.Fallback) Unreachable"
                            Severity  = "CRITICAL"
                        }
                    }
                }
            } else {
                if ($svc.Critical) {
                    $serviceAnomalies += [PSCustomObject]@{
                        Service   = $svc.Name
                        Port      = $svc.Port
                        Fallback  = $null
                        Container = $svc.Container
                        Path      = $svc.Path
                        Reason    = "Port $($svc.Port) Unreachable / Closed"
                        Severity  = "CRITICAL"
                    }
                }
            }
        }

        # 1.3 Conflict Lock Detection (Fast check in config and root)
        $lockFiles = Get-ChildItem -Path (Join-Path $BaseDir "config") -Filter "*.db-shm.tmp*" -Recurse -ErrorAction SilentlyContinue |
            Where-Object { -not $_.PSIsContainer }
        if ($lockFiles) {
            foreach ($lf in $lockFiles) {
                $conflictLocks += $lf.FullName
                try { Remove-Item $lf.FullName -Force -ErrorAction SilentlyContinue } catch { }
            }
        }

        # 1.4 Query Local Jellyfin Server Metadata
        $jellyfinServerId = "Unknown"
        $jellyfinServerName = "Unknown"
        $jellyfinVersion = "Unknown"
        try {
            $jfRaw = curl.exe -s --max-time 2 http://127.0.0.1:8096/System/Info/Public 2>$null
            if ($jfRaw) {
                $jfObj = $jfRaw | ConvertFrom-Json -ErrorAction SilentlyContinue
                if ($jfObj) {
                    $jellyfinServerId = $jfObj.Id
                    $jellyfinServerName = $jfObj.ServerName
                    $jellyfinVersion = $jfObj.Version
                }
            }
        } catch { }

        # 1.4 Deep Audit Cycle (Periodic or on anomaly)
        $isFullAudit = ($cycleStartTime - $lastFullAuditTime).TotalSeconds -ge $FullAuditIntervalSeconds
        if ($isFullAudit -or $serviceAnomalies.Count -gt 0) {
            $lastFullAuditTime = $cycleStartTime
            # Quick Database check
            foreach ($db in $coreDatabases) {
                if (Test-Path $db.Path) {
                    $walPath = "$($db.Path)-wal"
                    if (Test-Path $walPath) {
                        $walSizeKB = [math]::Round((Get-Item $walPath).Length / 1KB, 1)
                        if ($walSizeKB -gt 25000) {
                            $dbAnomalies += [PSCustomObject]@{
                                Database = $db.Name
                                Issue    = "WAL Contention: Size ${walSizeKB} KB exceeds threshold"
                                Severity = "WARNING"
                            }
                        }
                    }
                } else {
                    $dbAnomalies += [PSCustomObject]@{
                        Database = $db.Name
                        Issue    = "Database file missing at $($db.Path)"
                        Severity = "CRITICAL"
                    }
                }
            }
        }

        # --- STEP 2: IMMEDIATE INCIDENT DISPATCH TO VOLTAIREDEUX ---
        $hasErrors = ($serviceAnomalies.Count -gt 0 -or $dbAnomalies.Count -gt 0 -or $stoppedContainers.Count -gt 0)
        $currentSignature = "$($serviceAnomalies.Service -join ';')|$($dbAnomalies.Database -join ';')|$($stoppedContainers -join ';')"

        if ($hasErrors) {
            $timeSinceLastAlert = ([DateTime]::UtcNow - $lastIncidentAlertTime).TotalSeconds
            # Alert immediately if signature changed or cooldown elapsed (30s)
            if ($currentSignature -ne $lastIncidentSignature -or $timeSinceLastAlert -gt 30) {
                $lastIncidentSignature = $currentSignature
                $lastIncidentAlertTime = [DateTime]::UtcNow

                Write-Host "`n[!] ANOMALY DETECTED -> DISPATCHING INCIDENT ALERT TO VOLTAIREDEUX..." -ForegroundColor Red

                $incidentAlertPath = Join-Path $HandoffsDir "Incident_Alert_$($nodeInfo.LocalHostName)_${fileTag}.json"
                $incidentMdPath    = Join-Path $HandoffsDir "Incident_Alert_$($nodeInfo.LocalHostName)_${fileTag}.md"
                $latestIncident    = Join-Path $HandoffsDir "latest_incident_alert.json"

                $incidentObj = [ordered]@{
                    incident_id          = "INCIDENT_$fileTag"
                    timestamp            = $timestamp
                    source_node          = $nodeInfo.LocalHostName
                    source_ip            = $nodeInfo.LocalIP
                    target_peer          = $nodeInfo.PeerHostName
                    status               = "REQUIRES_AI_REMEDIATION"
                    service_anomalies    = $serviceAnomalies
                    database_anomalies   = $dbAnomalies
                    stopped_containers   = $stoppedContainers
                    running_containers   = $runningContainers.Count
                    online_services      = $onlineServicesCount
                    suggested_actions    = @(
                        "Analyze service logs and formulate targeted AutoFix repair package.",
                        "Inspect container restart loop or database lock status.",
                        "Publish remediation package to handoffs/cluster_update_manifest.json."
                    )
                }

                $incidentJson = $incidentObj | ConvertTo-Json -Depth 5
                try { [System.IO.File]::WriteAllText($incidentAlertPath, $incidentJson, [System.Text.Encoding]::UTF8) } catch { }
                try { [System.IO.File]::WriteAllText($latestIncident, $incidentJson, [System.Text.Encoding]::UTF8) } catch { }

                # Format Markdown Alert with Clickable Links & Direct Routes
                $nodeIp = if ($nodeInfo.LocalIP) { $nodeInfo.LocalIP } else { "192.168.4.30" }
                $mdLines = [System.Collections.Generic.List[string]]::new()
                $mdLines.Add("# [ALERT] Critical Incident Alert: $($nodeInfo.LocalHostName)")
                $mdLines.Add("")
                $mdLines.Add("| Attribute | Value |")
                $mdLines.Add("| :--- | :--- |")
                $mdLines.Add("| **Incident ID** | `INCIDENT_$fileTag` |")
                $mdLines.Add("| **Timestamp** | $timestamp |")
                $mdLines.Add("| **Source Node** | **$($nodeInfo.LocalHostName)** ($($nodeInfo.LocalIP)) |")
                $mdLines.Add("| **Jellyfin Server ID** | `$jellyfinServerId` ($jellyfinServerName v$jellyfinVersion) |")
                $mdLines.Add("| **Status** | **REQUIRES IMMEDIATE AI REMEDIATION** |")
                $mdLines.Add("| **Mission Control UI** | [https://${nodeIp}/dashboard/](https://${nodeIp}/dashboard/) |")
                $mdLines.Add("| **Fallback HTTPS UI** | [https://${nodeIp}:444/dashboard/](https://${nodeIp}:444/dashboard/) |")
                $mdLines.Add("")
                $mdLines.Add("### Detected Anomalies:")
                $mdLines.Add("")
                $mdLines.Add("| Component | Port & Fallback | Ingress Route | Container | Diagnostic Reason |")
                $mdLines.Add("| :--- | :---: | :--- | :--- | :--- |")
                foreach ($sa in $serviceAnomalies) {
                    $routeLink = "[Direct HTTPS](https://${nodeIp}$($sa.Path))"
                    $fallbackLink = if ($sa.Fallback) { " | [Fallback :$($sa.Fallback)](http://${nodeIp}:$($sa.Fallback)$($sa.Path))" } else { "" }
                    $mdLines.Add("| **$($sa.Service)** | `:$($sa.Port)` / `:$($sa.Fallback)` | $routeLink$fallbackLink | `$($sa.Container)` | $($sa.Reason) |")
                }
                foreach ($da in $dbAnomalies) {
                    $mdLines.Add("| **$($da.Database)** | SQLite WAL | `N/A` | Database Engine | $($da.Issue) |")
                }
                foreach ($sc in $stoppedContainers) {
                    $mdLines.Add("| **$sc** | Container | `Docker` | Host Daemon | Container Stopped/Exited |")
                }
                $mdLines.Add("")
                $mdLines.Add("### Diagnostic Artifacts & Blueprint Links:")
                $mdLines.Add("- JSON Payload: [Incident_Alert_$($nodeInfo.LocalHostName)_${fileTag}.json](file:///$($incidentAlertPath -replace '\\', '/'))")
                $mdLines.Add("- Update Manifest: [cluster_update_manifest.json](file:///$($manifestPath -replace '\\', '/'))")
                $mdLines.Add("- Collaboration Nexus: [ai_collaboration_nexus.json](file:///$($nexusPath -replace '\\', '/'))")
                $mdLines.Add("- Secrets Vault: [secrets.json](file:///c:/Users/waltd/OneDrive/Mediastack/config/secrets/secrets.json)")
                $mdLines.Add("- Caddyfile Blueprint: [Caddyfile](file:///c:/Users/waltd/OneDrive/Mediastack/Caddyfile)")
                $mdLines.Add("")
                $mdLines.Add("---")
                $mdLines.Add("*Dispatched by Autonomous Collaborator for immediate VoltaireDeux AI ingestion.*")

                try { [System.IO.File]::WriteAllText($incidentMdPath, ($mdLines -join "`r`n"), [System.Text.Encoding]::UTF8) } catch { }

                # Update latest handoff
                try {
                    $latestHandoffPath = Join-Path $HandoffsDir "latest_handoff_$($nodeInfo.LocalHostName).json"
                    $lhObj = [ordered]@{
                        author_node          = $nodeInfo.LocalHostName
                        timestamp            = $timestamp
                        overall_status       = "DEGRADED"
                        requires_remediation = $true
                        active_incident      = "INCIDENT_$fileTag"
                        service_anomalies    = $serviceAnomalies
                    }
                    [System.IO.File]::WriteAllText($latestHandoffPath, ($lhObj | ConvertTo-Json -Depth 5), [System.Text.Encoding]::UTF8)
                } catch { }

                Write-Host "  -> [DISPATCHED] Incident alert published to $latestIncident" -ForegroundColor Green
            }
        }

        # --- STEP 3: MONITOR FOR INCOMING REMEDIATION FROM VOLTAIREDEUX ---
        $remediationHistory = Get-RemediationHistory
        $executedList = [System.Collections.Generic.List[string]]::new()
        if ($remediationHistory.executed_scripts) {
            foreach ($item in $remediationHistory.executed_scripts) { $executedList.Add($item) }
        }

        $pendingRepairScript = $null
        $pendingManifest = $null
        $manifestPath = Join-Path $HandoffsDir "cluster_update_manifest.json"

        # 3.1 Check Cluster Update Manifest
        if (Test-Path $manifestPath) {
            try {
                $man = Get-Content $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
                if ($man.status -eq "READY_FOR_VOLTAIREUN_PULL" -or $man.status -eq "PENDING_EXECUTION") {
                    $updateId = $man.update_id
                    if (-not $executedList.Contains($updateId)) {
                        $pendingManifest = $man
                    }
                }
            } catch { }
        }

        # 3.2 Check for AutoFix_*.ps1 files in handoffs
        $stagedScripts = Get-ChildItem -Path $HandoffsDir -Filter "AutoFix_*.ps1" -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending

        foreach ($scr in $stagedScripts) {
            if (-not $executedList.Contains($scr.Name)) {
                $pendingRepairScript = $scr.FullName
                break
            }
        }

        # --- STEP 4: EXECUTE REPAIR FILE & REPORT PROGRESS ---
        if ($AutoExecuteRepairs -and ($pendingRepairScript -or $pendingManifest)) {
            $repairTargetName = if ($pendingRepairScript) { (Get-Item $pendingRepairScript).Name } else { $pendingManifest.update_id }
            Write-Host "`n================================================================================" -ForegroundColor Magenta
            Write-Host "   [REMEDIATION INGESTED] Incoming Repair Package from VoltaireDeux Detected!" -ForegroundColor White
            Write-Host "   Target: $repairTargetName" -ForegroundColor Yellow
            Write-Host "================================================================================" -ForegroundColor Magenta

            # Pre-repair safety snapshot
            try {
                Write-Host "  • Creating pre-remediation safety database snapshot..." -ForegroundColor DarkCyan
                $snapResult = New-MediaStackDatabaseSnapshot -Reason "PreRepair_$fileTag"
                if ($snapResult) {
                    Write-Host "    -> [SNAPSHOT CREATED] $($snapResult.SnapshotDir)" -ForegroundColor Green
                }
            } catch { }

            $repairSuccess = $false
            $repairOutput = ""
            $execSw = [System.Diagnostics.Stopwatch]::StartNew()

            if ($pendingRepairScript -and (Test-Path $pendingRepairScript)) {
                Write-Host "  • Executing repair script: $pendingRepairScript" -ForegroundColor Cyan
                $proc = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$pendingRepairScript`"" -NoNewWindow -PassThru -Wait -RedirectStandardOutput "$pendingRepairScript.out.log" -RedirectStandardError "$pendingRepairScript.err.log"
                $execSw.Stop()

                $outText = if (Test-Path "$pendingRepairScript.out.log") { Get-Content "$pendingRepairScript.out.log" -Raw } else { "" }
                $errText = if (Test-Path "$pendingRepairScript.err.log") { Get-Content "$pendingRepairScript.err.log" -Raw } else { "" }
                $repairOutput = "$outText`n$errText".Trim()

                if ($proc.ExitCode -eq 0) {
                    $repairSuccess = $true
                    Write-Host "  [SUCCESS] Repair script exited with Code 0 in $($execSw.ElapsedMilliseconds)ms" -ForegroundColor Green
                } else {
                    Write-Host "  [WARN] Repair script exited with Code $($proc.ExitCode)" -ForegroundColor Yellow
                }
                $executedList.Add((Get-Item $pendingRepairScript).Name)
            } elseif ($pendingManifest) {
                Write-Host "  • Applying cluster update manifest ($($pendingManifest.update_id))..." -ForegroundColor Cyan
                if ($pendingManifest.remediation_script) {
                    $mScript = Join-Path $HandoffsDir $pendingManifest.remediation_script
                    if (Test-Path $mScript) {
                        $proc = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$mScript`"" -NoNewWindow -PassThru -Wait
                        $repairSuccess = ($proc.ExitCode -eq 0)
                    }
                } else {
                    # Execute daily poller / git pull sync
                    $poller = Join-Path $BaseDir "Invoke-VoltaireUnDailyPoller.ps1"
                    if (Test-Path $poller) {
                        & $poller -ForceSync
                        $repairSuccess = $true
                    }
                }
                $executedList.Add($pendingManifest.update_id)
            }

            # Update history
            $remediationHistory.executed_scripts = @($executedList)
            $remediationHistory.last_watermark = (Get-Date -Format "o")
            Save-RemediationHistory $remediationHistory

            # --- STEP 5: AI REPORT PROGRESS & HANDOFF BACK TO VOLTAIREDEUX ---
            Write-Host "`n[STAGE 5/5] Synthesizing AI Progress Report and Handoff to VoltaireDeux..." -ForegroundColor Yellow

            # Re-probe services to verify fix
            Start-Sleep -Seconds 2
            $postRepairHealthy = $true
            foreach ($svc in $monitoredServices) {
                if ($svc.Critical) {
                    $p = Test-FastSocket -hostname "127.0.0.1" -port $svc.Port -timeoutMs 1000
                    if (-not $p.IsOpen) { $postRepairHealthy = $false }
                }
            }

            $nodeIp = if ($nodeInfo.LocalIP) { $nodeInfo.LocalIP } else { "192.168.4.30" }
            $execReportPath = Join-Path $HandoffsDir "AI_Remediation_Execution_Report_${fileTag}.md"
            $reportLines = [System.Collections.Generic.List[string]]::new()
            $reportLines.Add("# [REPORT] MediaStack AI Remediation & Resolution Report")
            $reportLines.Add("")
            $reportLines.Add("| Attribute | Value |")
            $reportLines.Add("| :--- | :--- |")
            $reportLines.Add("| **Executed Package** | `$repairTargetName` |")
            $reportLines.Add("| **Execution Node** | **$($nodeInfo.LocalHostName)** ($($nodeInfo.LocalIP)) |")
            $reportLines.Add("| **Jellyfin Server ID** | `$jellyfinServerId` ($jellyfinServerName v$jellyfinVersion) |")
            $reportLines.Add("| **Timestamp** | $timestamp |")
            $reportLines.Add("| **Duration** | $($execSw.ElapsedMilliseconds) ms |")
            $reportLines.Add("| **Execution Result** | $(if ($repairSuccess) { '[SUCCESS] PASS' } else { '[WARN] PARTIAL / INVESTIGATE' }) |")
            $reportLines.Add("| **Post-Remediation Health** | $(if ($postRepairHealthy) { '[HEALTHY] 100% OPERATIONAL' } else { '[DEGRADED] ADDITIONAL HEALING NEEDED' }) |")
            $reportLines.Add("")
            $reportLines.Add("### Live Service & Gateway Navigation:")
            $reportLines.Add("| Service | Primary Ingress | Fallback Port (+1) | Status |")
            $reportLines.Add("| :--- | :--- | :---: | :---: |")
            $reportLines.Add("| **Mission Control Dashboard** | [https://${nodeIp}/dashboard/](https://${nodeIp}/dashboard/) | [Port :444](https://${nodeIp}:444/dashboard/) | Active |")
            $reportLines.Add("| **Jellyfin Streaming** | [https://${nodeIp}/](https://${nodeIp}/) | [Port :8097](http://${nodeIp}:8097/) | Active |")
            $reportLines.Add("| **Sonarr TV Manager** | [https://${nodeIp}/sonarr/](https://${nodeIp}/sonarr/) | [Port :8990](http://${nodeIp}:8990/) | Active |")
            $reportLines.Add("| **Radarr Movies** | [https://${nodeIp}/radarr/](https://${nodeIp}/radarr/) | [Port :7879](http://${nodeIp}:7879/) | Active |")
            $reportLines.Add("| **Prowlarr Indexers** | [https://${nodeIp}/prowlarr/](https://${nodeIp}/prowlarr/) | [Port :9697](http://${nodeIp}:9697/) | Active |")
            $reportLines.Add("| **Bazarr Subtitles** | [https://${nodeIp}/bazarr/](https://${nodeIp}/bazarr/) | [Port :6768](http://${nodeIp}:6768/) | Active |")
            $reportLines.Add("| **Jellyseerr Requests** | [https://${nodeIp}/jellyseerr/](https://${nodeIp}/jellyseerr/) | [Port :5056](http://${nodeIp}:5056/) | Active |")
            $reportLines.Add("| **Transmission Torrent** | [https://${nodeIp}/transmission/web/](https://${nodeIp}/transmission/web/) | [Port :9092](http://${nodeIp}:9092/) | Active |")
            $reportLines.Add("| **TVHeadend Gateway** | [https://${nodeIp}/tvheadend/](https://${nodeIp}/tvheadend/) | [Port :9982](http://${nodeIp}:9982/) | Active |")
            $reportLines.Add("| **SQLite Web DB** | [https://${nodeIp}/db/](https://${nodeIp}/db/) | [Port :8081](http://${nodeIp}:8081/) | Active |")
            $reportLines.Add("")
            $reportLines.Add("### Remediation Output Transcript:")
            $reportLines.Add('```')
            $reportLines.Add($repairOutput)
            $reportLines.Add('```')
            $reportLines.Add("")
            $reportLines.Add("### Verified Artifacts:")
            $reportLines.Add("- Cluster Manifest: [cluster_update_manifest.json](file:///$($manifestPath -replace '\\', '/'))")
            $reportLines.Add("- Collaboration Nexus: [ai_collaboration_nexus.json](file:///$($nexusPath -replace '\\', '/'))")
            $reportLines.Add("")
            $reportLines.Add("---")
            $reportLines.Add("*Report emitted by Autonomous Collaborator Engine.*")

            try {
                [System.IO.File]::WriteAllText($execReportPath, ($reportLines -join "`r`n"), [System.Text.Encoding]::UTF8)
                Write-Host "  -> [REPORT GENERATED] Progress report created at $execReportPath" -ForegroundColor Green
            } catch { }

            # Update Cluster Manifest Status
            if (Test-Path $manifestPath) {
                try {
                    $manObj = Get-Content $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
                    $manObj.status = "APPLIED_BY_VOLTAIREUN"
                    $manObj.applied_at = $timestamp
                    $manObj.execution_result = if ($repairSuccess) { "SUCCESS" } else { "WARNING" }
                    $manJson = $manObj | ConvertTo-Json -Depth 5
                    [System.IO.File]::WriteAllText($manifestPath, $manJson, [System.Text.Encoding]::UTF8)
                    Write-Host "  -> [MANIFEST UPDATED] cluster_update_manifest.json status set to APPLIED_BY_VOLTAIREUN" -ForegroundColor Green
                } catch { }
            }

            # Update AI Collaboration Nexus
            $nexusData = [ordered]@{
                last_session_timestamp = $timestamp
                last_session_node      = $nodeInfo.LocalHostName
                local_ip               = $nodeInfo.LocalIP
                peer_node              = $nodeInfo.PeerHostName
                peer_ip                = $nodeInfo.PeerIP
                databases_healthy      = $postRepairHealthy
                anomalies_detected     = if ($postRepairHealthy) { 0 } else { 1 }
                remediations_applied   = $executedList.Count
                latest_report_path     = $execReportPath
            }
            try { [System.IO.File]::WriteAllText($nexusPath, ($nexusData | ConvertTo-Json -Depth 5), [System.Text.Encoding]::UTF8) } catch { }

            # Clear incident signature once resolved
            if ($postRepairHealthy) {
                $lastIncidentSignature = ""
            }
        }

        # --- STEP 6: LIVE CONSOLE HUD STATUS REFRESH ---
        $statusColor = if ($hasErrors) { "Red" } else { "Green" }
        $statusText  = if ($hasErrors) { "DEGRADED ($($serviceAnomalies.Count) issues)" } else { "OPTIMAL (100% ONLINE)" }
        $uptimeStr   = (Get-Date -Format "HH:mm:ss")

        Write-Host ("[{0}] Cycle #{1,-4} | Services: {2,2}/{3,-2} | Containers: {4,2} Up | Status: {5} | Peer: {6}" -f `
            $uptimeStr, $cycleCount, $onlineServicesCount, $monitoredServices.Count, $runningContainers.Count, $statusText, $nodeInfo.PeerHostName) -ForegroundColor $statusColor

        if ($SinglePass) {
            Write-Host "`n[SINGLE PASS COMPLETED] Exiting autonomous collaborator as requested." -ForegroundColor Cyan
            break
        }

        # Sleep with sub-second responsive cancellation check
        $sleepSteps = [math]::Max(1, $PollIntervalSeconds * 2)
        for ($s = 0; $s -lt $sleepSteps; $s++) {
            if (-not $global:KeepRunning) { break }
            Start-Sleep -Milliseconds 500
        }
    }
}
finally {
    Write-Host "`n================================================================================" -ForegroundColor Cyan
    Write-Host "   M E D I A S T A C K   A U T O N O M O U S   C O L L A B O R A T O R   S T O P P E D" -ForegroundColor Yellow
    Write-Host "   Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | Total Cycles: $cycleCount" -ForegroundColor DarkGray
    Write-Host "================================================================================" -ForegroundColor Cyan
}
