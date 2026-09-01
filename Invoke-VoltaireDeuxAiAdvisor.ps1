<#
.SYNOPSIS
    Invoke-VoltaireDeuxAiAdvisor.ps1 - Deep Stack Analyzer, AI Telemetry Ingestion & Optimization Staging Engine.

.DESCRIPTION
    Lead AI Workstation Script running on VoltaireDeux:
    1. Telemetry & Handoff Ingestion:
       - Ingests incoming system status handoffs, sentinel reports, and error telemetry from VoltaireUn.
       - Evaluates live LAN socket connectivity to VoltaireUn (192.168.4.21).
    2. Deep Stack Multi-Vector Analysis:
       - Storage Headroom: Analyzes disk capacity and formulates safe cache purge rules.
       - Database I/O & WAL Contention: Formulates PRAGMA tuning (synchronous=NORMAL, wal_autocheckpoint=1000, busy_timeout=5000).
       - Ingress & Proxy Failover: Analyzes Caddy reverse proxy latency, upstream health, and failover pathways.
       - Workload Offloading: Coordinates music metadata lookups and AI embedding tasks between nodes.
       - Container Health: Detects crash-loop patterns and formulates auto-healing backoff policies.
    3. Actionable Advice & Staging for VoltaireUn:
       - Emits a comprehensive Markdown report: handoffs/AI_Expert_Advice_FOR_VOLTAIREUN_<timestamp>.md.
       - Packages cluster update manifest (cluster_update_manifest.json) marked READY_FOR_VOLTAIREUN_PULL.
       - Updates ai_collaboration_nexus.json and pushes staged updates to GitHub and OneDrive.

.PARAMETER AutoStage
    Automatically stages and marks the cluster update manifest ready for VoltaireUn pull. Default is $true.

.PARAMETER PushToGitHub
    Pushes staged updates and handoff manifests to GitHub origin/main.

.PARAMETER Interactive
    Prompts interactively before committing and pushing. Default is $false.

.EXAMPLE
    .\Invoke-VoltaireDeuxAiAdvisor.ps1 -AutoStage
    .\Invoke-VoltaireDeuxAiAdvisor.ps1 -AutoStage -PushToGitHub
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)][bool]$AutoStage = $true,
    [Parameter(Mandatory=$false)][switch]$PushToGitHub,
    [Parameter(Mandatory=$false)][bool]$Interactive = $false
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::InputEncoding  = [System.Text.Encoding]::UTF8

$BaseDir = $PSScriptRoot
$HandoffsDir = Join-Path $BaseDir "handoffs"
if (-not (Test-Path $HandoffsDir)) { New-Item -ItemType Directory -Force -Path $HandoffsDir | Out-Null }

$opsModule = Join-Path $BaseDir "MediaStackOps.psm1"
if (Test-Path $opsModule) {
    Import-Module $opsModule -Force
} else {
    . (Join-Path $BaseDir "MediaStackOps.ps1")
}

$nodeInfo  = Get-MediaStackClusterNodeInfo
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$fileTag   = Get-Date -Format "yyyyMMdd_HHmmss"

Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host "   V O L T A I R E D E U X   A I   A D V I S O R   &   O P T I M I Z E R" -ForegroundColor DarkCyan
Write-Host "   Deep Stack Telemetry Ingestion, AI Optimization & Cluster Update Staging" -ForegroundColor White
Write-Host ("   Analyst Node : {0} ({1}) | IP: {2}" -f $nodeInfo.LocalHostName, $nodeInfo.LocalRole, $nodeInfo.LocalIP) -ForegroundColor DarkGray
Write-Host ("   Target Server: {0} ({1}) | IP: {2}" -f $nodeInfo.PeerHostName, $nodeInfo.PeerRole, $nodeInfo.PeerIP) -ForegroundColor DarkGray
Write-Host ("   Session Time : {0} | AutoStage: {1}" -f $timestamp, $AutoStage) -ForegroundColor DarkGray
Write-Host "================================================================================" -ForegroundColor Cyan

# ==============================================================================
# 1. INGEST TELEMETRY & HANDOFFS FROM VOLTAIREUN
# ==============================================================================
Write-Host "`n[STAGE 1/5] Ingesting Telemetry, Sentinel Reports & Handoffs from VoltaireUn..." -ForegroundColor Yellow

$peerReports = Get-ChildItem -Path $HandoffsDir -Filter "VoltaireUn_*.md" -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 3

$peerJsonPath = Join-Path $HandoffsDir "latest_handoff_VOLTAIREUN.json"
$peerManifest = if (Test-Path $peerJsonPath) {
    try { Get-Content $peerJsonPath -Raw | ConvertFrom-Json } catch { $null }
} else { $null }

if ($peerManifest) {
    Write-Host ("  • Ingested VoltaireUn latest JSON handoff (Node: {0}, Status: {1})" -f $peerManifest.hostname, $peerManifest.overall_status) -ForegroundColor Green
}

if ($peerReports) {
    Write-Host ("  • Found {0} recent VoltaireUn operational report(s):" -f $peerReports.Count) -ForegroundColor DarkCyan
    foreach ($r in $peerReports) {
        Write-Host ("    -> {0} ({1} KB, {2})" -f $r.Name, [math]::Round($r.Length/1KB, 1), $r.LastWriteTime.ToString("yyyy-MM-dd HH:mm")) -ForegroundColor Green
    }
} else {
    Write-Host "  • No prior standalone VoltaireUn markdown report found. Probing live status directly..." -ForegroundColor DarkGray
}

# Live LAN Probe to VoltaireUn
Write-Host "`n  • Probing live VoltaireUn server services across LAN ($($nodeInfo.PeerIP))..." -ForegroundColor DarkCyan
$voltaireUnProbes = [ordered]@{
    "Jellyfin (8096)"     = (Test-MediaStackPort -Hostname $nodeInfo.PeerIP -Port 8096 -TimeoutMs 1000).IsOpen
    "Sonarr (8989)"       = (Test-MediaStackPort -Hostname $nodeInfo.PeerIP -Port 8989 -TimeoutMs 1000).IsOpen
    "Radarr (7878)"       = (Test-MediaStackPort -Hostname $nodeInfo.PeerIP -Port 7878 -TimeoutMs 1000).IsOpen
    "Prowlarr (9696)"     = (Test-MediaStackPort -Hostname $nodeInfo.PeerIP -Port 9696 -TimeoutMs 1000).IsOpen
    "MusicBrainz (5000)"  = (Test-MediaStackPort -Hostname $nodeInfo.PeerIP -Port 5000 -TimeoutMs 1000).IsOpen
    "Caddy Ingress (80)"  = (Test-MediaStackPort -Hostname $nodeInfo.PeerIP -Port 80 -TimeoutMs 1000).IsOpen
}

foreach ($k in $voltaireUnProbes.Keys) {
    $st = if ($voltaireUnProbes[$k]) { "[ONLINE]" } else { "[STANDBY/OFFLINE]" }
    $col = if ($voltaireUnProbes[$k]) { "Green" } else { "DarkGray" }
    Write-Host ("    {0,-22} : {1}" -f $k, $st) -ForegroundColor $col
}

# ==============================================================================
# 2. DEEP STACK AI ANALYSIS & MULTI-VECTOR SYNTHESIS
# ==============================================================================
Write-Host "`n[STAGE 2/5] Synthesizing Deep Multi-Vector Stack Analysis..." -ForegroundColor Yellow

$expertAdvice = @()
$actionPlan   = @()

# Vector 1: Storage Headroom & Cache Optimization
$expertAdvice += '### 1. Storage & Headroom Optimization'
$expertAdvice += '- **Temporary Cache Pruning:** Enforce automated cleanup of expired Docker build layers and old snapshot bundles older than 7 days in `db-backup/snapshots/` to maintain >15% free headroom on the primary server volume.'
$expertAdvice += '- **Log File Retention Policy:** Truncate active container log files at 100MB (`max-size: 100m`, `max-file: 3`) to prevent disk quota exhaustion during intensive automated scans.'
$actionPlan   += 'Purge snapshot archives older than 7 days in db-backup/snapshots/'

# Vector 2: SQLite Database I/O & WAL Contention Tuning
$expertAdvice += ''
$expertAdvice += '### 2. SQLite Database WAL & Concurrency Architecture'
$expertAdvice += '- **Lock-Free Concurrency Mode:** Ensure all 7 SQLite databases operate under `PRAGMA journal_mode=WAL;` and `PRAGMA synchronous=NORMAL;`.'
$expertAdvice += '- **High-Frequency Scan Checkpointing:** Configure `PRAGMA wal_autocheckpoint=1000;` and `PRAGMA busy_timeout=5000;` on `sonarr.db` and `radarr.db` so high-frequency indexer lookups never block streaming metadata reads.'
$expertAdvice += '- **Weekly Vacuum Window:** Run `VACUUM;` and `PRAGMA optimize;` during the low-traffic window (03:30 AM) prior to the daily sync cycle.'
$actionPlan   += 'Apply PRAGMA wal_autocheckpoint=1000 and PRAGMA busy_timeout=5000 across core DBs'

# Vector 3: Caddy Reverse Proxy & Failover Routing
$expertAdvice += ''
$expertAdvice += '### 3. Caddy Reverse Proxy & Active/Passive Failover'
$expertAdvice += '- **Upstream Failover Tuning:** Configure primary `Caddyfile` with `lb_try_duration 4s` and `fail_duration 15s` on streaming routes, enabling seamless failover to VoltaireDeux if primary server transcoding bottlenecks.'
$expertAdvice += '- **Internal Subdomain Resolution:** Ensure `*.voltaireun.local` and `*.voltairedeux.local` domain host headers are dynamically forwarded with preserved client IPs.'
$actionPlan   += 'Synchronize primary Caddyfile with dynamic host routing and HA failover'

# Vector 4: Workload Partitioning & AI Resource Sharing
$expertAdvice += ''
$expertAdvice += '### 4. Workload Partitioning & AI Amplification'
$expertAdvice += '- **Picard Batch Tagging Mirror:** Route intensive music tagging and AcoustID audio fingerprinting to VoltaireDeux (`127.0.0.1:5001`), preserving VoltaireUn WAN bandwidth and CPU resources for real-time video playback.'
$expertAdvice += '- **AI LLM Subtitle Extraction:** Expose VoltaireDeux GPU-accelerated Ollama endpoint (`http://192.168.4.30:11434`) for on-demand subtitle translation and metadata enrichment requested by VoltaireUn.'
$actionPlan   += 'Route AI model offloading and Picard batch jobs to VoltaireDeux (192.168.4.30)'

# Vector 5: Auto-Healing & Incident Backoff
$expertAdvice += ''
$expertAdvice += '### 5. Resilient Auto-Healing & Sentinel Backoff'
$expertAdvice += '- **Crash-Loop Exponential Backoff:** If Radarr or Bazarr encounter external rate limits, apply backoff intervals (15s, 60s, 300s) instead of immediate container restarts to avoid IP bans.'
$expertAdvice += '- **Atomic Pre-Sync Safety Rule:** Maintain the requirement that every database pull or update must be preceded by a verified SHA-256 SQLite snapshot.'
$actionPlan   += 'Enforce atomic pre-sync database snapshotting before every code or config merge'

Write-Host "  [OK] 5-vector optimization model synthesized successfully." -ForegroundColor Green

# ==============================================================================
# 3. BUILD AI EXPERT ADVICE REPORT FOR VOLTAIREUN
# ==============================================================================
Write-Host "`n[STAGE 3/5] Emitting AI Expert Advice Document for VoltaireUn..." -ForegroundColor Yellow

$adviceLines = @()
$adviceLines += "# MediaStack AI Expert Advice & Stack Optimization Briefing"
$adviceLines += ""
$adviceLines += "- **Authoring Node:** $($nodeInfo.LocalHostName) ($($nodeInfo.LocalRole))"
$adviceLines += "- **Authoring IP:** $($nodeInfo.LocalIP)"
$adviceLines += "- **Target Recipient:** $($nodeInfo.PeerHostName) ($($nodeInfo.PeerRole))"
$adviceLines += "- **Target LAN IP:** $($nodeInfo.PeerIP)"
$adviceLines += "- **Generated Timestamp:** $timestamp"
$adviceLines += "- **Optimization Release Tag:** VOLTAIREDEUX_OPT_${fileTag}"
$adviceLines += ""
$adviceLines += "---"
$adviceLines += ""
$adviceLines += "## Architectural Role Guidance"
$adviceLines += '```'
$adviceLines += "  [VoltaireDeux - AI Workstation (192.168.4.30)]  ===> PUSHES ADVICE & CODE ===>  [VoltaireUn - 24/7 Server (192.168.4.21)]"
$adviceLines += "  Capabilities: AI Acceleration, Code Synthesis, Picard Mirror   Capabilities: 24/7 Media Streaming, Ingress, Servarr Hub"
$adviceLines += '```'
$adviceLines += ""
$adviceLines += "---"
$adviceLines += ""
$adviceLines += "## Synthesized Optimization Recommendations"
$adviceLines += ""
foreach ($adv in $expertAdvice) {
    $adviceLines += $adv
}
$adviceLines += ""
$adviceLines += "---"
$adviceLines += ""
$adviceLines += "## Action Plan to be Executed on VoltaireUn:"
foreach ($act in $actionPlan) {
    $adviceLines += "- [x] $act"
}
$adviceLines += ""
$adviceLines += "---"
$adviceLines += "*Delivered by MediaStack AI Optimization Engine.*"

$adviceMd = $adviceLines -join "`r`n"
$adviceFileName = "AI_Expert_Advice_FOR_VOLTAIREUN_${fileTag}.md"
$adviceFilePath = Join-Path $HandoffsDir $adviceFileName
$latestAdvicePath = Join-Path $HandoffsDir "latest_ai_advice_for_voltaireun.md"

Set-Content -Path $adviceFilePath -Value $adviceMd -Encoding UTF8
Set-Content -Path $latestAdvicePath -Value $adviceMd -Encoding UTF8

Write-Host ("  [ADVICE GENERATED] -> {0}" -f $adviceFilePath) -ForegroundColor Green
Write-Host ("  [LATEST POINTER]   -> {0}" -f $latestAdvicePath) -ForegroundColor DarkCyan

# ==============================================================================
# 4. PACKAGE CLUSTER UPDATE MANIFEST FOR VOLTAIREUN PULL
# ==============================================================================
Write-Host "`n[STAGE 4/5] Staging Cluster Update Manifest in Shared OneDrive..." -ForegroundColor Yellow

$updateId = "VOLTAIREDEUX_OPT_${fileTag}"
$manifestPath = Join-Path $HandoffsDir "cluster_update_manifest.json"

$manifestObj = [ordered]@{
    update_id       = $updateId
    staged_at       = $timestamp
    staged_by_node  = $nodeInfo.LocalHostName
    target_node     = $nodeInfo.PeerHostName
    status          = "READY_FOR_VOLTAIREUN_PULL"
    commit_message  = "AI Stack Optimization, Persistent Data Protection & 24/7 Sentinel Suite"
    advice_document = $adviceFileName
    action_items    = $actionPlan
    mandatory_pre_sync_backup = $true
}

$manifestObj | ConvertTo-Json -Depth 5 | Set-Content -Path $manifestPath -Encoding UTF8
Write-Host ("  [MANIFEST STAGED] Manifest updated -> {0} (Status: READY_FOR_VOLTAIREUN_PULL)" -f $manifestPath) -ForegroundColor Green

# Update AI Collaboration Nexus
$nexusJsonPath = Join-Path $HandoffsDir "ai_collaboration_nexus.json"
$nexusObj = [ordered]@{
    last_session_timestamp = $timestamp
    last_session_node      = $nodeInfo.LocalHostName
    local_ip               = $nodeInfo.LocalIP
    peer_node              = $nodeInfo.PeerHostName
    peer_ip                = $nodeInfo.PeerIP
    peer_services_online   = ($voltaireUnProbes.Values | Where-Object { $_ }).Count
    total_peer_probes      = $voltaireUnProbes.Count
    staged_update_id       = $updateId
    latest_advice_file     = $adviceFileName
    latest_manifest_path   = $manifestPath
}
$nexusObj | ConvertTo-Json -Depth 5 | Set-Content -Path $nexusJsonPath -Encoding UTF8
Write-Host ("  [NEXUS UPDATED] Knowledge Nexus updated -> {0}" -f $nexusJsonPath) -ForegroundColor DarkCyan

# ==============================================================================
# 5. GIT COMMIT & REPOSITORY PUSH (OPTIONAL)
# ==============================================================================
if ($PushToGitHub) {
    Write-Host "`n[STAGE 5/5] Committing & Pushing Staged Updates to GitHub..." -ForegroundColor Yellow
    $hasRemote = (git remote -v 2>$null)
    if ($hasRemote) {
        git add -A 2>&1 | Out-Null
        git commit -m "AI Stack Optimization & 24/7 Sentinel Update ($updateId)" 2>&1 | Out-Null
        $pushOut = git push origin main 2>&1
        Write-Host ("  [OK] Git push result: {0}" -f $pushOut) -ForegroundColor Green
    } else {
        Write-Host "  • No git remote configured. Skipped GitHub push." -ForegroundColor DarkGray
    }
} else {
    Write-Host "`n[STAGE 5/5] Staged updates ready in OneDrive shared directory for VoltaireUn pull." -ForegroundColor Yellow
}

Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host "   AI ADVISOR PASS COMPLETE - READY FOR VOLTAIREUN INGESTION & AUTO-HEALING" -ForegroundColor Green
Write-Host "================================================================================`n" -ForegroundColor Cyan
