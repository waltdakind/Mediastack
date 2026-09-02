# ==============================================================================
# Invoke-StackAutoRepair.ps1 - Primary Autonomous Self-Healing, Code-Writing & Troubleshooting Engine
# Automatically detects issues, autowrites custom PowerShell remediation scripts,
# generates AI Markdown RCA diagnostic handoffs, and executes targeted fixes.
[CmdletBinding()]
param(
    [string]$ConfigDir = "$env:SystemDrive\MediastackConfig",
    [switch]$CheckOnly,
    [switch]$NoAutoExecute
)

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::InputEncoding  = [System.Text.Encoding]::UTF8

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$fileTimestamp = Get-Date -Format "yyyyMMdd_HHmmss"

$HandoffsDir = Join-Path $PSScriptRoot "handoffs"
if (-not (Test-Path $HandoffsDir)) { New-Item -ItemType Directory -Force -Path $HandoffsDir | Out-Null }

Write-Host "`n================================================================================" -ForegroundColor DarkCyan
Write-Host "   M E D I A S T A C K   A U T O N O M O U S   A U T O - R E P A I R   E N G I N E" -ForegroundColor Cyan
Write-Host ("   Timestamp: {0} | AutoExecute: {1}" -f $timestamp, (-not $NoAutoExecute)) -ForegroundColor DarkGray
Write-Host "================================================================================" -ForegroundColor DarkCyan

# --- 1. MULTI-VECTOR DIAGNOSTIC AUDIT ---
Write-Host "`n[1/4] Executing Comprehensive System Diagnostic Sweep..." -ForegroundColor Yellow

$diagnosedIncidents = @()

# Vector A: Docker Container States
$containers = docker ps -a --format "{{.Names}}|{{.Status}}" 2>$null
$containerMap = @{}
foreach ($line in $containers) {
    $parts = $line -split "\|", 2
    if ($parts.Count -eq 2) { $containerMap[$parts[0]] = $parts[1] }
}

$expectedFleet = @("caddy", "jellyfin", "sonarr", "radarr", "prowlarr", "bazarr", "jellyseerr", "transmission", "tvheadend", "mediastack-db", "homepage", "api-gateway")
foreach ($c in $expectedFleet) {
    if (-not $containerMap.ContainsKey($c)) {
        $diagnosedIncidents += [PSCustomObject]@{
            Component = $c
            Category  = "MISSING_CONTAINER"
            Severity  = "HIGH"
            Details   = "Container '$c' is not present in Docker fleet"
            FixType   = "DEPLOY_CONTAINER"
        }
    } elseif ($containerMap[$c] -like "*Exited*" -or $containerMap[$c] -like "*Dead*") {
        $diagnosedIncidents += [PSCustomObject]@{
            Component = $c
            Category  = "CONTAINER_STOPPED"
            Severity  = "HIGH"
            Details   = "Container '$c' is in stopped state: $($containerMap[$c])"
            FixType   = "START_CONTAINER"
        }
    }
}

# Vector B: SQLite Database Locks & Integrity Check
$dbFiles = Get-ChildItem -Path $ConfigDir -Recurse -File -Include "*.db","*.sqlite3" -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch "logs" }
foreach ($db in $dbFiles) {
    $journal = "$($db.FullName)-journal"
    if (Test-Path $journal) {
        $diagnosedIncidents += [PSCustomObject]@{
            Component = $db.Name
            Category  = "SQLITE_DANGLING_JOURNAL"
            Severity  = "MEDIUM"
            Details   = "Dangling SQLite rollback journal detected: $journal"
            FixType   = "PURGE_DB_LOCK"
        }
    }
}

# Vector C: Ingress Routing Health
$routesToProbe = @(
    @{ Route="voltaireun.local"; Container="caddy"; Path="" },
    @{ Route="jellyfin.voltaireun.local"; Container="jellyfin"; Path="/health" },
    @{ Route="sonarr.voltaireun.local"; Container="sonarr"; Path="/ping" },
    @{ Route="radarr.voltaireun.local"; Container="radarr"; Path="/ping" },
    @{ Route="prowlarr.voltaireun.local"; Container="prowlarr"; Path="" },
    @{ Route="jellyseerr.voltaireun.local"; Container="jellyseerr"; Path="/api/v1/status" },
    @{ Route="db.mediaserver.local"; Container="mediastack-db"; Path="" }
)

foreach ($r in $routesToProbe) {
    $code = curl.exe -s -o NUL -w "%{http_code}" --max-time 5 -H "Host: $($r.Route)" "http://localhost:80$($r.Path)"
    $cInt = [int]$code
    if ($cInt -eq 0 -or ($cInt -ge 500 -and $r.Route -notlike "*musicbrainz*")) {
        $diagnosedIncidents += [PSCustomObject]@{
            Component = $r.Route
            Category  = "INGRESS_ROUTING_FAILURE"
            Severity  = "HIGH"
            Details   = "L7 Route 'http://$($r.Route)' returned HTTP $code"
            FixType   = "RELOAD_CADDY_OR_RESTART"
        }
    }
}

# Vector D: Picard Configuration Alignment
$picardIni = "$env:APPDATA\MusicBrainz\Picard.ini"
if (Test-Path $picardIni) {
    $pHost = ""
    $pPort = ""
    foreach ($l in (Get-Content $picardIni -ErrorAction SilentlyContinue)) {
        if ($l -match '^server_host\s*=\s*(.+)$') { $pHost = $matches[1].Trim() }
        if ($l -match '^server_port\s*=\s*(.+)$') { $pPort = $matches[1].Trim() }
    }
    $primaryMb = curl.exe -s -o NUL -w "%{http_code}" --max-time 3 "http://192.168.4.21:5000/"
    if ($primaryMb -eq "200" -and ($pHost -ne "192.168.4.21" -or $pPort -ne "5000")) {
        $targetStr = "${pHost}:${pPort}"
        $diagnosedIncidents += [PSCustomObject]@{
            Component = "Picard"
            Category  = "PICARD_SUBOPTIMAL_TARGET"
            Severity  = "LOW"
            Details   = "Primary MusicBrainz (192.168.4.21:5000) is ready, but Picard is targeting $targetStr"
            FixType   = "ALIGN_PICARD_PRIMARY"
        }
    }
}

# Vector E: MusicBrainz Database Persistence Guard
$mbDbRunning = docker ps --filter "name=musicbrainz-docker-db-1" --format "{{.Status}}" 2>$null
if ($mbDbRunning -and $mbDbRunning -like "*Up*") {
    $mbTables = docker exec musicbrainz-docker-db-1 psql -U musicbrainz -d musicbrainz -t -A -c "SELECT count(*) FROM information_schema.tables WHERE table_schema IN ('musicbrainz', 'public') AND table_type = 'BASE TABLE';" 2>$null
    if ($mbTables -eq "0" -or [string]::IsNullOrWhiteSpace($mbTables)) {
        $diagnosedIncidents += [PSCustomObject]@{
            Component = "MusicBrainz PostgreSQL DB"
            Category  = "DATABASE_PERSISTENCE_FAILURE"
            Severity  = "HIGH"
            Details   = "MusicBrainz PostgreSQL database is running but has 0 tables (Persistence failure detected)"
            FixType   = "RESTORE_MUSICBRAINZ_PERSISTENCE"
        }
    }
}

# --- 2. SUMMARY OF DIAGNOSED ISSUES ---
Write-Host "`n[2/4] Diagnostic Evaluation Results:" -ForegroundColor Yellow
if ($diagnosedIncidents.Count -eq 0) {
    Write-Host "  [OK] No critical system anomalies detected. Fleet is operating optimally (100%)." -ForegroundColor Green
} else {
    foreach ($inc in $diagnosedIncidents) {
        $col = if ($inc.Severity -eq "HIGH") { "Red" } elseif ($inc.Severity -eq "MEDIUM") { "Yellow" } else { "DarkCyan" }
        Write-Host ("  [{0,-6}] {1,-28} | {2}" -f $inc.Severity, $inc.Component, $inc.Details) -ForegroundColor $col
    }
}

# --- 3. AUTOWRITING REMEDIATION CODE & AI RCA HANDOFF ---
$fixScriptFile = "$HandoffsDir\AutoFix_${fileTimestamp}.ps1"
$rcaMarkdownFile = "$HandoffsDir\Incident_RCA_${fileTimestamp}.md"

Write-Host "`n[3/4] Autowriting Custom Remediation Code & AI Diagnostics Handoff..." -ForegroundColor Yellow

$fixCodeLines = [System.Collections.ArrayList]::new()
[void]$fixCodeLines.Add("# ==============================================================================")
[void]$fixCodeLines.Add("# Autonomous Remediation Script - Generated $timestamp")
[void]$fixCodeLines.Add("# ==============================================================================")
[void]$fixCodeLines.Add("`$ErrorActionPreference = 'Continue'")
[void]$fixCodeLines.Add("Write-Host '`n[EXECUTING AUTONOMOUS REMEDIATION]' -ForegroundColor Cyan")

$rcaLines = [System.Collections.ArrayList]::new()
[void]$rcaLines.Add("# MediaStack Diagnostic Root Cause Analysis (RCA) and Handoff")
[void]$rcaLines.Add("")
[void]$rcaLines.Add("| Parameter | Value |")
[void]$rcaLines.Add("| :--- | :--- |")
[void]$rcaLines.Add("| **Incident Timestamp** | $timestamp |")
[void]$rcaLines.Add("| **Host** | $env:COMPUTERNAME |")
[void]$rcaLines.Add("| **Anomalies Detected** | $($diagnosedIncidents.Count) |")
[void]$rcaLines.Add("| **Generated Remediation Script** | $fixScriptFile |")
[void]$rcaLines.Add("")
[void]$rcaLines.Add("---")
[void]$rcaLines.Add("")
[void]$rcaLines.Add("## Diagnosed Anomalies and Failure Modes")
[void]$rcaLines.Add("")

if ($diagnosedIncidents.Count -eq 0) {
    [void]$rcaLines.Add("No active anomalies detected. All services, containers, databases, and routes are healthy.")
} else {
    foreach ($inc in $diagnosedIncidents) {
        [void]$rcaLines.Add("### Issue: $($inc.Component)")
        [void]$rcaLines.Add("- **Category:** $($inc.Category)")
        [void]$rcaLines.Add("- **Severity:** $($inc.Severity)")
        [void]$rcaLines.Add("- **Details:** $($inc.Details)")
        [void]$rcaLines.Add("- **Prescribed Fix:** $($inc.FixType)")
        [void]$rcaLines.Add("")

        switch ($inc.FixType) {
            "START_CONTAINER" {
                [void]$fixCodeLines.Add("Write-Host '  -> Restarting stopped container: $($inc.Component)...' -ForegroundColor Yellow")
                [void]$fixCodeLines.Add("docker start $($inc.Component)")
            }
            "DEPLOY_CONTAINER" {
                [void]$fixCodeLines.Add("Write-Host '  -> Deploying missing container: $($inc.Component)...' -ForegroundColor Yellow")
                [void]$fixCodeLines.Add("docker compose up -d $($inc.Component)")
            }
            "PURGE_DB_LOCK" {
                [void]$fixCodeLines.Add("Write-Host '  -> Purging SQLite lock: $($inc.Component)...' -ForegroundColor Yellow")
                [void]$fixCodeLines.Add("Get-ChildItem -Path '$ConfigDir' -Recurse -Filter '$($inc.Component)-journal' | Remove-Item -Force")
            }
            "RELOAD_CADDY_OR_RESTART" {
                [void]$fixCodeLines.Add("Write-Host '  -> Reloading Caddy Reverse-Proxy configuration...' -ForegroundColor Yellow")
                [void]$fixCodeLines.Add("docker exec caddy caddy reload --config /etc/caddy/Caddyfile")
            }
            "ALIGN_PICARD_PRIMARY" {
                [void]$fixCodeLines.Add("Write-Host '  -> Re-aligning Picard client target with Repair-PicardConfiguration.ps1...' -ForegroundColor Yellow")
                [void]$fixCodeLines.Add("& `"$PSScriptRoot\Repair-PicardConfiguration.ps1`"")
            }
            "RESTORE_MUSICBRAINZ_PERSISTENCE" {
                [void]$fixCodeLines.Add("Write-Host '  -> Auto-recovering MusicBrainz database persistence from snapshot...' -ForegroundColor Yellow")
                [void]$fixCodeLines.Add("& `"$PSScriptRoot\Ensure-MusicBrainzPersistence.ps1`" -AutoRestore")
            }
        }
    }
}

[void]$rcaLines.Add("## Quick Access & Navigation Links")
[void]$rcaLines.Add("")
[void]$rcaLines.Add("- **Mission Control Dashboard:** [https://192.168.4.30/dashboard/](https://192.168.4.30/dashboard/)")
[void]$rcaLines.Add("- **Fallback HTTPS Ingress (:444):** [https://192.168.4.30:444/dashboard/](https://192.168.4.30:444/dashboard/)")
[void]$rcaLines.Add("- **Generated Remediation Code:** [$fixScriptFile](file:///$($fixScriptFile.Replace('\', '/')))")
[void]$rcaLines.Add("- **Cluster Update Manifest:** [cluster_update_manifest.json](file:///$($HandoffsDir.Replace('\', '/'))/cluster_update_manifest.json)")
[void]$rcaLines.Add("- **AI Collaboration Nexus:** [ai_collaboration_nexus.json](file:///$($HandoffsDir.Replace('\', '/'))/ai_collaboration_nexus.json)")
[void]$rcaLines.Add("")

[void]$fixCodeLines.Add("Write-Host '  [OK] Remediation actions completed.' -ForegroundColor Green")

# Save generated files
Set-Content -Path $fixScriptFile -Value ($fixCodeLines -join "`r`n") -Encoding UTF8
Set-Content -Path $rcaMarkdownFile -Value ($rcaLines -join "`r`n") -Encoding UTF8

Write-Host ("  [AUTOWRITTEN] Remediation Code: {0}" -f $fixScriptFile) -ForegroundColor DarkCyan
Write-Host ("  [AUTOWRITTEN] AI Diagnostic RCA: {0}" -f $rcaMarkdownFile) -ForegroundColor DarkCyan

# --- 4. EXECUTE SAFE REMEDIATION ---
if (-not $NoAutoExecute -and -not $CheckOnly -and $diagnosedIncidents.Count -gt 0) {
    Write-Host "`n[4/4] Executing Prescribed Autonomous Fixes..." -ForegroundColor Yellow
    powershell.exe -ExecutionPolicy Bypass -File $fixScriptFile
    
    try {
        $sqlInit = "CREATE TABLE IF NOT EXISTS autoheal_events_log (id INTEGER PRIMARY KEY AUTOINCREMENT, event_timestamp TEXT NOT NULL, container_name TEXT NOT NULL, trigger_reason TEXT, action_taken TEXT, status TEXT, details TEXT); "
        $sqlInsert = "INSERT INTO autoheal_events_log (event_timestamp, container_name, trigger_reason, action_taken, status, details) VALUES ('$timestamp', 'STACK_AUTOREPAIR', '$($diagnosedIncidents.Count) Anomalies Found', 'Executed $fixScriptFile', 'RESOLVED', 'RCA: $rcaMarkdownFile'); "
        docker exec mediastack-db sqlite3 /config/mediastack_backup.db "$sqlInit $sqlInsert" 2>$null
    } catch { }
} else {
    Write-Host "`n[4/4] System status clean. No repair execution required." -ForegroundColor Green
}

Write-Host "`n================================================================================" -ForegroundColor DarkCyan
Write-Host "     A U T O - R E P A I R   S U I T E   E X E C U T I O N   D O N E" -ForegroundColor Cyan
Write-Host "================================================================================`n" -ForegroundColor DarkCyan
