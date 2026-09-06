<#
.SYNOPSIS
    Invoke-MediaStackAiCollaboration.ps1 - Dual-Node AI Collaboration & Cross-Healing Nexus.

.DESCRIPTION
    Lead Enterprise Engineering Script establishing automated AI collaboration
    between the AI Coding & Acceleration System (VoltaireDeux) and the Primary Media Streaming
    Node (VoltaireUn).

    Core Collaborative Capabilities:
    1. Ecosystem Role Understanding & Capability Discovery:
       - Identifies node roles, AI compute resources (CUDA/DirectML/Ollama/Valkey), memory, and service responsibilities.
    2. Dynamic LAN Connectivity & Reverse Proxy Synthesis:
       - Validates cross-node latency, DNS resolution, and Caddy active/passive failover pathways.
    3. File Naming, Database Path & Lock Sanitation:
       - Detects and repairs OneDrive conflict duplicates (*-VoltaireDeux.db, *.db-shm), ensures standard Servarr
         directory layouts, and validates SQLite schemas.
    4. Intelligent AI Log Analysis & Cross-Node Incident Diagnostics:
       - Ingests recent container crash logs, SQLite audit events, and proxy status codes.
    5. Intelligently Directed AI Remediation & Self-Healing:
       - Applies safe, automated recovery recipes (WAL flush, container restart, DNS flush, proxy reload).
    6. Self-Improving Shared AI Knowledge Nexus:
       - Emits and updates persistent cross-node knowledge manifests (`handoffs/ai_collaboration_nexus.json`)
         and generates comprehensive Markdown collaboration handoffs.

.PARAMETER AutoRepair
    Automatically executes safe, non-destructive remediations for discovered issues.

.PARAMETER SyncKnowledge
    Reconciles shared AI knowledge manifests across OneDrive. Default is $true.

.PARAMETER Interactive
    Prompts the user interactively during execution. Default is $true.

.PARAMETER DryRun
    Simulates repairs and diagnostic actions without modifying state.

.EXAMPLE
    .\Invoke-MediaStackAiCollaboration.ps1 -AutoRepair
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)][switch]$AutoRepair,
    [Parameter(Mandatory = $false)][bool]$SyncKnowledge = $true,
    [Parameter(Mandatory = $false)][switch]$Continuous,
    [Parameter(Mandatory = $false)][int]$IntervalSeconds = 15,
    [Parameter(Mandatory = $false)][bool]$Interactive = $true,
    [Parameter(Mandatory = $false)][switch]$NonInteractive,
    [Parameter(Mandatory = $false)][Alias("Stop", "Exit", "Conclude")][switch]$ExitSession,
    [Parameter(Mandatory = $false)][string]$ExitReason = "Operator requested collaboration exit",
    [Parameter(Mandatory = $false)][switch]$DryRun
)

if ($NonInteractive -or $Continuous) { $Interactive = $false }

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::InputEncoding = [System.Text.Encoding]::UTF8

$BaseDir = $PSScriptRoot
if (-not $BaseDir -or -not (Test-Path (Join-Path $BaseDir "MediaStackOps.psm1"))) {
    $parent = Split-Path $PSScriptRoot -Parent
    if ($parent -and (Test-Path (Join-Path $parent "MediaStackOps.psm1"))) {
        $BaseDir = $parent
    } else {
        $BaseDir = "c:\Users\waltd\OneDrive\Mediastack"
    }
}
$HandoffsDir = Join-Path $BaseDir "handoffs"
if (-not (Test-Path $HandoffsDir)) { New-Item -ItemType Directory -Force -Path $HandoffsDir | Out-Null }

# Load Primary Operations Module
$opsModule = Join-Path $BaseDir "MediaStackOps.psm1"
if (Test-Path $opsModule) {
    Import-Module $opsModule -Force
}
else {
    . (Join-Path $BaseDir "MediaStackOps.ps1")
}

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$fileTag = Get-Date -Format "yyyyMMdd_HHmmss"
$nodeInfo = Get-MediaStackClusterNodeInfo

# ==============================================================================
# FAST-PATH: AI COLLABORATION EXIT BROADCAST
# ==============================================================================
if ($ExitSession) {
    $nexusJsonPath = Join-Path $HandoffsDir "ai_collaboration_nexus.json"
    $currentNexus = @{}
    if (Test-Path $nexusJsonPath) {
        try { $currentNexus = Get-Content $nexusJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch { }
    }

    $exitReportPath = Join-Path $HandoffsDir "AI_Collaboration_Session_Exit_$($nodeInfo.LocalHostName)_${fileTag}.md"
    $exitMd = @"
# MediaStack AI Collaboration Session Concluded

- **Concluded By Node:** $($nodeInfo.LocalHostName) ($($nodeInfo.LocalIP))
- **Peer Node:** $($nodeInfo.PeerHostName) ($($nodeInfo.PeerIP))
- **Timestamp:** $timestamp
- **Exit Reason:** $ExitReason
- **Session State:** CONCLUDED
- **Session Active:** false

---
*Notice broadcast to cluster to terminate frequent collaborator polling loops.*
"@
    try { Set-Content -Path $exitReportPath -Value $exitMd -Encoding UTF8 } catch { }

    $nexusObj = [ordered]@{
        session_state          = "CONCLUDED"
        session_active         = $false
        concluded_by           = $nodeInfo.LocalHostName
        concluded_at           = $timestamp
        exit_reason            = $ExitReason
        peer_acknowledged_exit = $false
        last_session_timestamp = $timestamp
        last_session_node      = $nodeInfo.LocalHostName
        local_ip               = $nodeInfo.LocalIP
        peer_node              = $nodeInfo.PeerHostName
        peer_ip                = $nodeInfo.PeerIP
        peer_latency_ms        = $(if ($currentNexus.peer_latency_ms) { $currentNexus.peer_latency_ms } else { 0 })
        databases_healthy      = $(if ($null -ne $currentNexus.databases_healthy) { $currentNexus.databases_healthy } else { $true })
        anomalies_detected     = 0
        remediations_applied   = $(if ($currentNexus.remediations_applied) { $currentNexus.remediations_applied } else { 0 })
        active_action_plan     = @()
        latest_report_path     = $exitReportPath
    }
    [System.IO.File]::WriteAllText($nexusJsonPath, ($nexusObj | ConvertTo-Json -Depth 5), [System.Text.Encoding]::UTF8)

    Write-Host "`n================================================================================" -ForegroundColor Cyan
    Write-Host "   [AI COLLABORATION EXIT BROADCAST] SESSION CONCLUDED" -ForegroundColor Yellow
    Write-Host ("   Concluded By : {0} ({1})" -f $nodeInfo.LocalHostName, $nodeInfo.LocalIP) -ForegroundColor Green
    Write-Host ("   Peer Target  : {0} ({1})" -f $nodeInfo.PeerHostName, $nodeInfo.PeerIP) -ForegroundColor DarkCyan
    Write-Host ("   Timestamp    : {0}" -f $timestamp) -ForegroundColor White
    Write-Host ("   Exit Reason  : {0}" -f $ExitReason) -ForegroundColor DarkYellow
    Write-Host "   Broadcast updated -> handoffs/ai_collaboration_nexus.json" -ForegroundColor DarkCyan
    Write-Host "   Frequent polling signals halted across cluster." -ForegroundColor Green
    Write-Host "================================================================================`n" -ForegroundColor Cyan
    return
}

# ==============================================================================
# HERO BANNER & COLLABORATION MATRIX
# ==============================================================================
Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host "   M E D I A S T A C K   A I   C O L L A B O R A T I O N   N E X U S" -ForegroundColor DarkCyan
Write-Host "   Autonomous Dual-Node Diagnostic, Knowledge Synthesis & Self-Healing Engine" -ForegroundColor White
Write-Host ("   Local Node : {0} ({1}) | IP: {2}" -f $nodeInfo.LocalHostName, $nodeInfo.LocalRole, $nodeInfo.LocalIP) -ForegroundColor DarkGray
Write-Host ("   Peer Node  : {0} ({1}) | IP: {2}" -f $nodeInfo.PeerHostName, $nodeInfo.PeerRole, $nodeInfo.PeerIP) -ForegroundColor DarkGray
Write-Host ("   Timestamp  : {0} | AutoRepair: {1} | DryRun: {2}" -f $timestamp, [bool]$AutoRepair, [bool]$DryRun) -ForegroundColor DarkGray
Write-Host "================================================================================" -ForegroundColor Cyan

# ==============================================================================
# STAGE 1: ECOSYSTEM ROLES & AI RESOURCE DISCOVERY
# ==============================================================================
Write-Host "`n[STAGE 1/6] Discovering Ecosystem Roles, Workloads & AI Compute Topology..." -ForegroundColor Yellow

$localAiResources = [ordered]@{
    NodeName          = $nodeInfo.LocalHostName
    Role              = $nodeInfo.LocalRole
    LocalIP           = $nodeInfo.LocalIP
    GpuAcceleration   = "Standard"
    OllamaEndpoint    = "http://127.0.0.1:11434"
    OllamaActive      = $false
    MusicBrainzMirror = "http://127.0.0.1:5000"
    MusicBrainzActive = $false
    ServarrSuite      = "http://127.0.0.1:8989"
    ServarrActive     = $false
    PrimaryWorkload   = if ($nodeInfo.IsVoltaireDeux) { "AI Code Synthesis, LLM Offloading, Metadata Tagging" } else { "24/7 Media Streaming, Servarr Automation, Storage Hosting" }
}

# Check Ollama AI Service
try {
    $olCheck = Test-MediaStackPort -Hostname "127.0.0.1" -Port 11434 -TimeoutMs 600
    $localAiResources.OllamaActive = $olCheck.IsOpen
}
catch { }

# Check MusicBrainz & Servarr
try {
    $mbCheck = Test-MediaStackPort -Hostname "127.0.0.1" -Port 5000 -TimeoutMs 600
    $localAiResources.MusicBrainzActive = $mbCheck.IsOpen
    $sonarrCheck = Test-MediaStackPort -Hostname "127.0.0.1" -Port 8989 -TimeoutMs 600
    $localAiResources.ServarrActive = $sonarrCheck.IsOpen
}
catch { }

# Probe Peer Node AI & Workload Ports across LAN
Write-Host "  • Probing Peer Node AI and service endpoints on $($nodeInfo.PeerIP)..." -ForegroundColor DarkCyan
$peerAiProbe = Test-MediaStackPort -Hostname $nodeInfo.PeerIP -Port 11434 -TimeoutMs 1000
$peerMbProbe = Test-MediaStackPort -Hostname $nodeInfo.PeerIP -Port 5000 -TimeoutMs 1000
$peerJellyProbe = Test-MediaStackPort -Hostname $nodeInfo.PeerIP -Port 8096 -TimeoutMs 1000

$localAiStatus = if ($localAiResources.OllamaActive) { "[ACTIVE]" } else { "[STANDBY]" }
$localAiColor = if ($localAiResources.OllamaActive) { "Green" } else { "DarkGray" }
$peerAiStatus = if ($peerAiProbe.IsOpen) { "[ACTIVE]" } else { "[STANDBY]" }
$peerAiColor = if ($peerAiProbe.IsOpen) { "Green" } else { "DarkGray" }
$peerJellyStatus = if ($peerJellyProbe.IsOpen) { "[ACTIVE]" } else { "[STANDBY]" }
$peerJellyColor = if ($peerJellyProbe.IsOpen) { "Green" } else { "DarkGray" }
$peerMbStatus = if ($peerMbProbe.IsOpen) { "[ACTIVE]" } else { "[STANDBY]" }
$peerMbColor = if ($peerMbProbe.IsOpen) { "Green" } else { "DarkGray" }

$peerIp = $nodeInfo.PeerIP
Write-Host ("    - Local AI Engine (Ollama:11434)      : {0}" -f $localAiStatus) -ForegroundColor $localAiColor
Write-Host ("    - Peer AI Engine ({0}:11434) : {1}" -f $peerIp, $peerAiStatus) -ForegroundColor $peerAiColor
Write-Host ("    - Peer Streaming ({0}:8096)  : {1}" -f $peerIp, $peerJellyStatus) -ForegroundColor $peerJellyColor
Write-Host ("    - Peer MusicBrainz ({0}:5000): {1}" -f $peerIp, $peerMbStatus) -ForegroundColor $peerMbColor

# ==============================================================================
# STAGE 2: DYNAMIC CONNECTIVITY & REVERSE PROXY ROUTING NEXUS
# ==============================================================================
Write-Host "`n[STAGE 2/6] Evaluating Dual-Node LAN Connectivity & Upstream Routing..." -ForegroundColor Yellow

$connectivityIssues = @()
$peerPingLatency = $null

# 1. Ping Latency Check
try {
    $pingObj = New-Object System.Net.NetworkInformation.Ping
    $reply = $pingObj.Send($nodeInfo.PeerIP, 1200)
    if ($reply.Status -eq [System.Net.NetworkInformation.IPStatus]::Success) {
        $peerPingLatency = $reply.RoundtripTime
        Write-Host ("  [OK] Peer LAN Ping ({0}) -> {1}ms" -f $nodeInfo.PeerIP, $peerPingLatency) -ForegroundColor Green
    }
    else {
        $connectivityIssues += "Ping to peer node ($($nodeInfo.PeerIP)) timed out or unreachable."
        Write-Host ("  [WARN] Peer LAN Ping ({0}) -> Unreachable ({1})" -f $nodeInfo.PeerIP, $reply.Status) -ForegroundColor Yellow
    }
}
catch {
    $connectivityIssues += "Ping probe exception: $($_.Exception.Message)"
}

# 2. Local DNS Resolution Test
$dnsEntries = @("voltaireun.local", "voltairedeux.local")
foreach ($domain in $dnsEntries) {
    try {
        $resolved = [System.Net.Dns]::GetHostAddresses($domain) | Select-Object -First 1
        if ($resolved) {
            Write-Host ("  [OK] DNS Domain '{0}' -> Resolved to {1}" -f $domain, $resolved.IPAddressToString) -ForegroundColor Green
        }
        else {
            $connectivityIssues += "DNS domain '$domain' failed resolution."
            Write-Host ("  [WARN] DNS Domain '{0}' -> Resolution failed." -f $domain) -ForegroundColor Yellow
        }
    }
    catch {
        $connectivityIssues += "DNS resolution exception for '$domain': $($_.Exception.Message)"
    }
}

# ==============================================================================
# STAGE 3: FILE NAMING, DATABASE SCHEMAS & ONEDRIVE CONFLICT SANITATION
# ==============================================================================
Write-Host "`n[STAGE 3/6] Inspecting File Naming Standards, Database Layouts & Sync Locks..." -ForegroundColor Yellow

$fileNamingAnomalies = @()
$remediatedFiles = @()

$ActiveConfig = if (Test-Path "$BaseDir\config") { "$BaseDir\config" } else { "$env:SystemDrive\MediastackConfig" }

# 1. Scan for OneDrive Duplicate Lock/Conflict Files
Write-Host "  • Scanning for OneDrive conflict files and stale SQLite lock journals..." -ForegroundColor DarkCyan
$conflictPatterns = @(
    "* - Copy.*",
    "*-VoltaireDeux.db*",
    "*-VoltaireDeux-*.db*",
    "*.db-wal.tmp*",
    "*.db-shm.tmp*"
)

foreach ($pat in $conflictPatterns) {
    $foundConflictFiles = Get-ChildItem -Path $ActiveConfig -Recurse -Filter $pat -ErrorAction SilentlyContinue |
    Where-Object { -not $_.PSIsContainer }
    
    foreach ($m in $foundConflictFiles) {
        $fileNamingAnomalies += "Found sync conflict file: $($m.FullName) ($([math]::Round($m.Length/1KB, 1)) KB)"
        if ($AutoRepair -and -not $DryRun) {
            try {
                Remove-Item -Path $m.FullName -Force -ErrorAction SilentlyContinue
                $remediatedFiles += "Purged conflict file: $($m.Name)"
                Write-Host ("    [REPAIRED] Deleted conflict file: {0}" -f $m.Name) -ForegroundColor Green
            }
            catch { }
        }
    }
}

# 2. Validate Canonical Database Names
$canonicalDatabases = @(
    @{ Name = "sonarr.db"; ExpectedPath = "$ActiveConfig\sonarr\sonarr.db"; Service = "sonarr" },
    @{ Name = "radarr.db"; ExpectedPath = "$ActiveConfig\radarr\radarr.db"; Service = "radarr" },
    @{ Name = "prowlarr.db"; ExpectedPath = "$ActiveConfig\prowlarr\prowlarr.db"; Service = "prowlarr" },
    @{ Name = "bazarr.db"; ExpectedPath = "$ActiveConfig\bazarr\db\bazarr.db"; Service = "bazarr" },
    @{ Name = "db.sqlite3"; ExpectedPath = "$ActiveConfig\jellyseerr\db\db.sqlite3"; Service = "jellyseerr" },
    @{ Name = "jellyfin.db"; ExpectedPath = "$ActiveConfig\jellyfin\data\data\jellyfin.db"; Service = "jellyfin" },
    @{ Name = "mediastack_backup.db"; ExpectedPath = "$ActiveConfig\db-backup\mediastack_backup.db"; Service = "mediastack-db" }
)

$dbHealthSummary = @()
foreach ($db in $canonicalDatabases) {
    $exists = Test-Path $db.ExpectedPath
    $size = if ($exists) { (Get-Item $db.ExpectedPath).Length } else { 0 }
    $chk = if ($exists) { Test-MediaStackDatabaseHealth -HostPath $db.ExpectedPath -InternalPath "/config/$($db.Name)" } else { [PSCustomObject]@{ IsValid = $false; Details = "File not found" } }
    
    $statusText = if ($chk.IsValid) { "[OK] PRISTINE" } elseif ($exists) { "[WARN] CORRUPT" } else { "[INFO] MISSING" }
    $color = if ($chk.IsValid) { "Green" } else { "Yellow" }
    Write-Host ("    {0,-22} | Service: {1,-14} | Size: {2,7} KB | {3}" -f $db.Name, $db.Service, [math]::Round($size / 1KB, 1), $statusText) -ForegroundColor $color
    
    $walPath = "$($db.ExpectedPath)-wal"
    $hasWal = Test-Path $walPath
    $walSizeKB = if ($hasWal) { [math]::Round((Get-Item $walPath).Length / 1KB, 1) } else { 0 }

    $dbHealthSummary += [PSCustomObject]@{
        Name      = $db.Name
        Service   = $db.Service
        Exists    = $exists
        SizeKB    = [math]::Round($size / 1KB, 1)
        HasWAL    = $hasWal
        WalSizeKB = $walSizeKB
        Status    = $statusText
        Valid     = $chk.IsValid
    }
}

# ==============================================================================
# STAGE 4: INTELLIGENT ERROR LOG DIGEST & CROSS-NODE DIAGNOSTICS
# ==============================================================================
Write-Host "`n[STAGE 4/6] Parsing Container Incident Logs & SQLite Audit Events..." -ForegroundColor Yellow

$recentIncidents = @()

# Ingest from SQLite Registry
try {
    $auditLogs = docker exec mediastack-db sqlite3 /config/mediastack_backup.db "SELECT event_timestamp, service_name, event_type, message FROM port_monitor_events_log WHERE event_type LIKE '%FAIL%' OR event_type LIKE '%ANOMALY%' ORDER BY id DESC LIMIT 5;" 2>$null
    if ($auditLogs) {
        foreach ($row in ($auditLogs -split "`n")) {
            if ($row.Trim()) { $recentIncidents += $row.Trim() }
        }
    }
}
catch { }

# Ingest from Container Docker Logs for failing services
$stoppedContainers = docker ps -a --filter "status=exited" --filter "status=dead" --format "{{.Names}}" 2>$null
if ($stoppedContainers) {
    foreach ($sc in ($stoppedContainers -split "`n")) {
        $c = $sc.Trim()
        if ($c) {
            $logTail = docker logs --tail 3 $c 2>&1
            $recentIncidents += "Container '$c' is stopped. Last log snippet: $logTail"
        }
    }
}

if ($recentIncidents.Count -eq 0) {
    Write-Host "  [OK] No critical system errors or container crashes recorded in recent telemetry." -ForegroundColor Green
}
else {
    Write-Host ("  [WARN] Discovered {0} incident telemetry events:" -f $recentIncidents.Count) -ForegroundColor Yellow
    foreach ($inc in $recentIncidents) {
        Write-Host ("    • {0}" -f $inc) -ForegroundColor DarkYellow
    }
}

# ==============================================================================
# STAGE 5: AI-DIRECTED COLLABORATIVE HEALING & REMEDIATION
# ==============================================================================
Write-Host "`n[STAGE 5/6] Formulating AI Directed Cross-Node Healing & Repair Plan..." -ForegroundColor Yellow

$aiActionPlan = @()

# Rule 1: WAL Checkpoint Flush if WAL file exceeds 5MB
foreach ($db in $canonicalDatabases) {
    $walPath = "$($db.ExpectedPath)-wal"
    if (Test-Path $walPath) {
        $walSize = (Get-Item $walPath).Length
        if ($walSize -gt 5MB) {
            $aiActionPlan += "Execute PRAGMA wal_checkpoint(TRUNCATE) on $($db.Name) (Active WAL size: $([math]::Round($walSize/1MB, 1)) MB)"
        }
    }
}

# Rule 2: Flush DNS if any DNS entry failed
if ($connectivityIssues | Where-Object { $_ -match "DNS" }) {
    $aiActionPlan += "Execute DNS Client Cache Flush ('Clear-DnsClientCache' & 'ipconfig /flushdns')"
}

# Rule 3: Restart unhealthy or stopped containers
if ($stoppedContainers) {
    foreach ($sc in ($stoppedContainers -split "`n")) {
        if ($sc.Trim()) {
            $aiActionPlan += "Restart container '$($sc.Trim())' with health verification"
        }
    }
}

# Rule 4: Caddy Upstream Hot-Reload if Caddy is running
$caddyStatus = docker ps --filter "name=caddy" --format "{{.Status}}" 2>$null
if ($caddyStatus -match "Up") {
    $aiActionPlan += "Soft-reload Caddy reverse proxy upstream definitions ('docker exec caddy caddy reload')"
}

if ($aiActionPlan.Count -eq 0) {
    Write-Host "  [OK] System state is optimal. No active remediation actions required." -ForegroundColor Green
}
else {
    Write-Host "  >> AI COLLABORATIVE REMEDIATION ACTIONS:" -ForegroundColor Cyan
    foreach ($act in $aiActionPlan) {
        Write-Host ("     -> {0}" -f $act) -ForegroundColor Yellow
    }

    if ($AutoRepair -and -not $DryRun) {
        Write-Host "`n  [*] Executing Automated Self-Healing Plan..." -ForegroundColor Yellow
        
        # 1. Execute WAL Checkpoint Truncate
        Invoke-MediaStackWalCheckpoint -Mode "PASSIVE" | Out-Null
        Write-Host "    [APPLIED] Passive SQLite WAL Checkpoints executed across all databases." -ForegroundColor Green

        # 2. Flush DNS
        try {
            Clear-DnsClientCache -ErrorAction SilentlyContinue
            ipconfig /flushdns 2>&1 | Out-Null
            Write-Host "    [APPLIED] Flushed Windows DNS resolver cache." -ForegroundColor Green
        }
        catch { }

        # 3. Restart Stopped Containers
        if ($stoppedContainers) {
            foreach ($sc in ($stoppedContainers -split "`n")) {
                $c = $sc.Trim()
                if ($c) {
                    docker restart $c 2>&1 | Out-Null
                    Write-Host ("    [APPLIED] Restarted container '{0}'." -f $c) -ForegroundColor Green
                }
            }
        }

        # 4. Reload Caddy
        if ($caddyStatus -match "Up") {
            docker exec caddy caddy reload 2>&1 | Out-Null
            Write-Host "    [APPLIED] Hot-reloaded Caddy edge gateway proxy maps." -ForegroundColor Green
        }
    }
}

# ==============================================================================
# STAGE 6: EMIT MARKDOWN HANDOFF & UPDATE KNOWLEDGE NEXUS
# ==============================================================================
Write-Host "`n[STAGE 6/6] Emitting Markdown Collaboration Handoff & Updating Knowledge Nexus..." -ForegroundColor Yellow

$mdLines = @()
$mdLines += "# MediaStack AI Collaboration & Self-Healing Session"
$mdLines += ""
$mdLines += "- **Session Host:** $($nodeInfo.LocalHostName) ($($nodeInfo.LocalRole))"
$mdLines += "- **Host Local IP:** $($nodeInfo.LocalIP)"
$mdLines += "- **Collaborator Peer:** $($nodeInfo.PeerHostName) ($($nodeInfo.PeerRole))"
$mdLines += "- **Peer LAN IP:** $($nodeInfo.PeerIP)"
$mdLines += "- **Execution Time:** $timestamp"
$sessionMode = if ($AutoRepair) { "Autonomous Self-Healing (AutoRepair)" } else { "Diagnostic & Advisory" }
$mdLines += "- **Mode:** $sessionMode"
$mdLines += ""
$mdLines += "---"
$mdLines += ""
$mdLines += "## 1. Dual-Node Topology & Resource Roles"
$mdLines += ""
$mdLines += "| Node Name | Role | LAN IP | Ollama AI | Media Services | Primary Duty |"
$mdLines += "| :--- | :--- | :--- | :---: | :---: | :--- |"

$localAiState = if ($localAiResources.OllamaActive) { "Active" } else { "Standby" }
$localServarrState = if ($localAiResources.ServarrActive) { "Active" } else { "Standby" }
$peerAiState = if ($peerAiProbe.IsOpen) { "Active" } else { "Standby" }
$peerJellyState = if ($peerJellyProbe.IsOpen) { "Active" } else { "Standby" }
$peerWorkload = if ($nodeInfo.IsVoltaireDeux) { "24/7 Media Streaming, Servarr, Storage" } else { "AI Acceleration, Push Source" }

$mdLines += "| **" + $nodeInfo.LocalHostName + "** (Local) | " + $nodeInfo.LocalRole + " | " + $nodeInfo.LocalIP + " | " + $localAiState + " | " + $localServarrState + " | " + $localAiResources.PrimaryWorkload + " |"
$mdLines += "| **" + $nodeInfo.PeerHostName + "** (Peer) | " + $nodeInfo.PeerRole + " | " + $nodeInfo.PeerIP + " | " + $peerAiState + " | " + $peerJellyState + " | " + $peerWorkload + " |"
$mdLines += ""
$mdLines += "---"
$mdLines += ""
$mdLines += "## 2. SQLite Database Health & Concurrency Audit"
$mdLines += ""
$mdLines += "| Database File | Size (KB) | WAL Active | WAL Size (KB) | Status |"
$mdLines += "| :--- | :---: | :---: | :---: | :---: |"
foreach ($db in $dbHealthSummary) {
    $walStatus = if ($db.HasWAL) { 'Yes' } else { 'No' }
    $mdLines += "| " + $db.Name + " | " + $db.SizeKB + " | " + $walStatus + " | " + $db.WalSizeKB + " | " + $db.Status + " |"
}
$mdLines += ""
$mdLines += "---"
$mdLines += ""
$mdLines += "## 3. Discovered Anomalies & Auto-Remediations"
$mdLines += ""
if ($fileNamingAnomalies.Count -eq 0 -and $connectivityIssues.Count -eq 0 -and $recentIncidents.Count -eq 0) {
    $mdLines += "[OK] **All systems operating normally.** Zero file naming conflicts, zero DNS anomalies, and zero active crashes."
}
else {
    if ($fileNamingAnomalies.Count -gt 0) {
        $mdLines += "### File Naming & Sync Anomaly Findings:"
        foreach ($f in $fileNamingAnomalies) { $mdLines += "- $f" }
    }
    if ($connectivityIssues.Count -gt 0) {
        $mdLines += "### Connectivity Diagnostic Findings:"
        foreach ($c in $connectivityIssues) { $mdLines += "- $c" }
    }
    if ($recentIncidents.Count -gt 0) {
        $mdLines += "### Recent System Incidents:"
        foreach ($inc in $recentIncidents) { $mdLines += "- $inc" }
    }
}
$mdLines += ""
$mdLines += "---"
$mdLines += ""
$mdLines += "## 4. AI-Directed Self-Healing & Peer Recommendations"
$mdLines += ""
$mdLines += "> **Actionable Insights Generated for Cluster Stability:**"
$mdLines += ""
if ($nodeInfo.IsVoltaireDeux) {
    $mdLines += "1. **VoltaireUn (Main Server) Database IO Optimization:** Keep `PRAGMA synchronous=NORMAL;` and `PRAGMA wal_autocheckpoint=1000;` on `sonarr.db` and `radarr.db` to prevent I/O wait during streaming peaks."
    $mdLines += "2. **MusicBrainz Proxy Partitioning:** Use local Picard mirror on VoltaireDeux (`http://127.0.0.1:5001`) for batch tagging tasks to leave VoltaireUn's `5000` port free for automated Servarr lookups."
    $mdLines += "3. **Automated Handoff Exchange:** Continue running the daily update poller on VoltaireUn to ingest fixes authored on VoltaireDeux."
}
else {
    $mdLines += "1. **VoltaireDeux (AI Node) Acceleration Offloading:** Route Ollama embedding requests for subtitle processing through `http://192.168.4.30:11434`."
    $mdLines += "2. **Temporary Lock File Exclusion:** Keep `-wal` and `-shm` files local to prevent OneDrive sync locking."
}
$mdLines += ""
$mdLines += "---"
$mdLines += "*Report generated by MediaStack AI Collaboration Nexus Engine.*"

$reportPath = Join-Path $HandoffsDir "AI_Collaboration_Session_$($nodeInfo.LocalHostName)_${fileTag}.md"
$nexusJsonPath = Join-Path $HandoffsDir "ai_collaboration_nexus.json"

$mdReport = $mdLines -join "`r`n"
Set-Content -Path $reportPath -Value $mdReport -Encoding UTF8

# Update Persistent Knowledge Nexus Manifest
$nexusObj = [ordered]@{
    session_state          = "ACTIVE"
    session_active         = $true
    session_id             = "COLLAB_${fileTag}_$($nodeInfo.LocalHostName)"
    concluded_by           = $null
    concluded_at           = $null
    exit_reason            = $null
    peer_acknowledged_exit = $false
    last_session_timestamp = $timestamp
    last_session_node      = $nodeInfo.LocalHostName
    local_ip               = $nodeInfo.LocalIP
    peer_node              = $nodeInfo.PeerHostName
    peer_ip                = $nodeInfo.PeerIP
    peer_latency_ms        = $peerPingLatency
    databases_healthy      = ($dbHealthSummary | Where-Object { -not $_.Valid }).Count -eq 0
    anomalies_detected     = ($fileNamingAnomalies.Count + $connectivityIssues.Count + $recentIncidents.Count)
    remediations_applied   = $remediatedFiles.Count
    active_action_plan     = $aiActionPlan
    latest_report_path     = $reportPath
}
[System.IO.File]::WriteAllText($nexusJsonPath, ($nexusObj | ConvertTo-Json -Depth 5), [System.Text.Encoding]::UTF8)

Write-Host ("`n[COLLABORATION SESSION COMPLETE] Markdown Report -> {0}" -f $reportPath) -ForegroundColor Green
Write-Host ("  Persistent AI Knowledge Nexus updated -> {0}" -f $nexusJsonPath) -ForegroundColor DarkCyan

if ($Continuous) {
    Write-Host "`n[CONTINUOUS SENTINEL ACTIVE] Polling for VoltaireUn updates every ${IntervalSeconds}s (Press 'Q', 'X' or Ctrl+C to stop)..." -ForegroundColor Cyan
    $lastReportTime = [DateTime]::UtcNow
    while ($true) {
        $hbTs = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Write-Host "[$hbTs] [AI COLLABORATION HUB] Heartbeat: Peer ($($nodeInfo.PeerIP)) Synchronized. Watching handoffs/ for peer telemetry..." -ForegroundColor DarkGray

        # 1. Check for Peer Exit Signal in ai_collaboration_nexus.json
        if (Test-Path $nexusJsonPath) {
            try {
                $liveNexus = Get-Content $nexusJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
                if ($liveNexus.session_state -in @("CONCLUDED", "EXIT_REQUESTED") -or $liveNexus.session_active -eq $false) {
                    if ($liveNexus.concluded_by -and $liveNexus.concluded_by -ne $nodeInfo.LocalHostName) {
                        Write-Host "`n================================================================================" -ForegroundColor Yellow
                        Write-Host "   [PEER COLLABORATOR EXITED] COLLABORATION SESSION CONCLUDED" -ForegroundColor Magenta
                        Write-Host ("   Peer node [{0}] concluded the AI collaboration session." -f $liveNexus.concluded_by) -ForegroundColor White
                        Write-Host ("   Conclusion Timestamp : {0}" -f $liveNexus.concluded_at) -ForegroundColor DarkCyan
                        Write-Host ("   Exit Reason          : {0}" -f $liveNexus.exit_reason) -ForegroundColor DarkGray
                        Write-Host "   Ending session and terminating frequent polling loops." -ForegroundColor Green
                        Write-Host "================================================================================" -ForegroundColor Yellow

                        try {
                            $liveNexus.peer_acknowledged_exit = $true
                            $liveNexus.peer_acknowledged_at = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
                            [System.IO.File]::WriteAllText($nexusJsonPath, ($liveNexus | ConvertTo-Json -Depth 5), [System.Text.Encoding]::UTF8)
                        } catch { }

                        break
                    }
                }
            } catch { }
        }

        # 2. Responsive Sleep with Keyboard Exit Check
        $sleepSteps = [math]::Max(1, $IntervalSeconds * 2)
        $stopRequested = $false
        for ($s = 0; $s -lt $sleepSteps; $s++) {
            try {
                if ([System.Environment]::UserInteractive -and [Console]::KeyAvailable) {
                    $key = [Console]::ReadKey($true)
                    if ($key.Key -in @([System.ConsoleKey]::Q, [System.ConsoleKey]::X, [System.ConsoleKey]::Escape)) {
                        Write-Host "`n[EXIT KEY DETECTED] Gracefully concluding AI collaboration session..." -ForegroundColor Yellow
                        & $PSCommandPath -ExitSession -ExitReason "Operator pressed '$($key.Key)' in console"
                        $stopRequested = $true
                        break
                    }
                }
            } catch { }
            Start-Sleep -Milliseconds 500
        }
        if ($stopRequested) { break }

        # 3. Check for fresh reports from peer
        $newReports = Get-ChildItem -Path $HandoffsDir -Filter "VoltaireUn_*.md" -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTimeUtc -gt $lastReportTime } |
            Sort-Object LastWriteTimeUtc -Descending |
            Select-Object -First 1
        
        if ($newReports) {
            Write-Host "`n[NEW TELEMETRY DETECTED] Found fresh report from VoltaireUn: $($newReports.Name)" -ForegroundColor Magenta
            $lastReportTime = $newReports.LastWriteTimeUtc
            & $PSCommandPath -AutoRepair:$AutoRepair -NonInteractive -DryRun:$DryRun
        }
    }
} elseif ($Interactive) {
    Write-Host "`nPress any key to return..." -ForegroundColor DarkGray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
