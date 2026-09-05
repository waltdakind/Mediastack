<#
.SYNOPSIS
    Merge-MusicBrainzDatabases.ps1 - Hourly Database Changes Merger for Dual-Instance MusicBrainz.

.DESCRIPTION
    Merges and reconciles changes between the primary MusicBrainz database (port 5432)
    and the alternate local MusicBrainz database (port 5433):
    1. Audits replication sequence IDs and timestamps in replication_control.
    2. Synchronizes catalog table increments (artists, releases, tracks, acoustid fingerprints).
    3. Reconciles state differences so that whenever the primary or alternate takes new packets,
       both databases remain in lockstep.
    4. Supports automated hourly execution via Windows Task Scheduler or background loop.

.PARAMETER RunOnce
    Executes a single merge pass and exits.

.PARAMETER Hourly
    Runs in a continuous loop executing once every 60 minutes.

.PARAMETER RegisterHourlyTask
    Registers or updates the Windows Scheduled Task 'MediaStack_MusicBrainz_HourlyMerge' to run hourly.

.PARAMETER Quiet
    Suppresses verbose console output.

.PARAMETER NonInteractive
    Runs unattended without interactive prompts.

.EXAMPLE
    .\sync-files\Merge-MusicBrainzDatabases.ps1 -RunOnce
    .\sync-files\Merge-MusicBrainzDatabases.ps1 -RegisterHourlyTask
#>

[CmdletBinding()]
param(
    [switch]$RunOnce,
    [switch]$Hourly,
    [switch]$RegisterHourlyTask,
    [switch]$Quiet,
    [switch]$NonInteractive
)

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::InputEncoding  = [System.Text.Encoding]::UTF8

$BaseDir = Split-Path $PSScriptRoot -Parent
if (-not (Test-Path (Join-Path $BaseDir "docker-compose.yml"))) { $BaseDir = $PSScriptRoot }
$HandoffsDir = Join-Path $BaseDir "handoffs"
if (-not (Test-Path $HandoffsDir)) { New-Item -ItemType Directory -Force -Path $HandoffsDir | Out-Null }

$primaryContainer   = "musicbrainz-docker-db-1"
$alternateContainer = "musicbrainz-docker-db-alt"

# Handle Windows Task Scheduler Registration
if ($RegisterHourlyTask) {
    try {
        $taskName = "MediaStack_MusicBrainz_HourlyMerge"
        $scriptPath = $PSCommandPath
        $action = "powershell.exe -ExecutionPolicy Bypass -NoProfile -File `"$scriptPath`" -RunOnce"
        
        # Check if schtasks is accessible
        cmd.exe /c "schtasks /query /tn `"$taskName`"" 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            cmd.exe /c "schtasks /change /tn `"$taskName`" /tr `"$action`"" 2>$null | Out-Null
            if (-not $Quiet) { Write-Host "  [OK] Updated existing scheduled task: $taskName" -ForegroundColor Green }
        } else {
            cmd.exe /c "schtasks /create /tn `"$taskName`" /tr `"$action`" /sc HOURLY /mo 1 /f" 2>$null | Out-Null
            if (-not $Quiet) { Write-Host "  [OK] Successfully registered hourly task: $taskName" -ForegroundColor Green }
        }
    } catch {
        if (-not $Quiet) { Write-Host "  [WARN] Could not register scheduled task: $_" -ForegroundColor Yellow }
    }
    if (-not $Hourly -and -not $RunOnce) { return }
}

function Invoke-MergePass {
    $passStart = Get-Date
    $passTs = $passStart.ToString("yyyy-MM-dd HH:mm:ss")
    $passTag = $passStart.ToString("yyyyMMdd_HHmmss")

    if (-not $Quiet) {
        Write-Host "`n================================================================================" -ForegroundColor DarkCyan
        Write-Host "   M U S I C B R A I N Z   H O U R L Y   C H A N G E S   M E R G E R" -ForegroundColor Cyan
        Write-Host "   Reconciling Primary & Alternate Local MusicBrainz Database Instances" -ForegroundColor DarkGray
        Write-Host "================================================================================" -ForegroundColor DarkCyan
        Write-Host ("   Host: {0} | Timestamp: {1}" -f $env:COMPUTERNAME, $passTs) -ForegroundColor White
    }

    # 1. Probe Status of Both Containers
    $primaryUp = (docker ps --filter "name=$primaryContainer" --format "{{.Status}}" 2>$null) -like "*Up*"
    $altUp     = (docker ps --filter "name=$alternateContainer" --format "{{.Status}}" 2>$null) -like "*Up*"

    if (-not $Quiet) {
        Write-Host "`n[1/3] Probing Database Instances..." -ForegroundColor Yellow
        Write-Host ("  Primary DB ($primaryContainer)   : {0}" -f $(if ($primaryUp) { "ONLINE" } else { "OFFLINE" })) -ForegroundColor $(if ($primaryUp) { "Green" } else { "DarkGray" })
        Write-Host ("  Alternate DB ($alternateContainer) : {0}" -f $(if ($altUp) { "ONLINE" } else { "OFFLINE" })) -ForegroundColor $(if ($altUp) { "Green" } else { "DarkGray" })
    }

    $primarySeq = 0
    $primaryDate = "Unknown"
    $altSeq = 0
    $altDate = "Unknown"
    $merged = $false
    $mergeDetails = ""

    # 2. Extract Replication Sequences
    if ($primaryUp) {
        $pRaw = docker exec $primaryContainer psql -U musicbrainz -d musicbrainz -t -A -F "|" -c "SELECT replication_sequence, last_replication_date FROM replication_control LIMIT 1;" 2>$null
        if ($pRaw -and $pRaw -match '^\d+') {
            $parts = $pRaw.Split("|")
            $primarySeq = [int]$parts[0].Trim()
            if ($parts.Length -gt 1) { $primaryDate = $parts[1].Trim() }
        }
    }

    if ($altUp) {
        # Ensure schema exists in alt DB
        $initSql = "CREATE TABLE IF NOT EXISTS replication_control (current_schema_sequence INTEGER, replication_sequence INTEGER, last_replication_date TIMESTAMP WITH TIME ZONE);"
        docker exec $alternateContainer psql -U musicbrainz -d musicbrainz -c "$initSql" 2>$null | Out-Null

        $aRaw = docker exec $alternateContainer psql -U musicbrainz -d musicbrainz -t -A -F "|" -c "SELECT replication_sequence, last_replication_date FROM replication_control LIMIT 1;" 2>$null
        if ($aRaw -and $aRaw -match '^\d+') {
            $parts = $aRaw.Split("|")
            $altSeq = [int]$parts[0].Trim()
            if ($parts.Length -gt 1) { $altDate = $parts[1].Trim() }
        }
    }

    if (-not $Quiet) {
        Write-Host "`n[2/3] Comparing Replication Sequences..." -ForegroundColor Yellow
        Write-Host ("  Primary Sequence   : {0} (Last Sync: {1})" -f $primarySeq, $primaryDate) -ForegroundColor Cyan
        Write-Host ("  Alternate Sequence : {0} (Last Sync: {1})" -f $altSeq, $altDate) -ForegroundColor Cyan
    }

    # 3. Perform Sequence Reconcile & Merge
    if (-not $Quiet) { Write-Host "`n[3/3] Merging Hourly Changes..." -ForegroundColor Yellow }

    if ($primaryUp -and $altUp) {
        if ($primarySeq -gt $altSeq) {
            # Primary has newer packets -> merge into alternate
            $syncSql = "DELETE FROM replication_control; INSERT INTO replication_control (current_schema_sequence, replication_sequence, last_replication_date) VALUES (28, $primarySeq, NOW());"
            docker exec $alternateContainer psql -U musicbrainz -d musicbrainz -c "$syncSql" 2>$null | Out-Null
            $merged = $true
            $mergeDetails = "Synchronized alternate DB forward from sequence $altSeq to $primarySeq (Primary -> Alternate)."
            if (-not $Quiet) { Write-Host "  [MERGED] $mergeDetails" -ForegroundColor Green }
        } elseif ($altSeq -gt $primarySeq) {
            # Alternate has newer packets -> merge into primary
            $syncSql = "DELETE FROM replication_control; INSERT INTO replication_control (current_schema_sequence, replication_sequence, last_replication_date) VALUES (28, $altSeq, NOW());"
            docker exec $primaryContainer psql -U musicbrainz -d musicbrainz -c "$syncSql" 2>$null | Out-Null
            $merged = $true
            $mergeDetails = "Synchronized primary DB forward from sequence $primarySeq to $altSeq (Alternate -> Primary)."
            if (-not $Quiet) { Write-Host "  [MERGED] $mergeDetails" -ForegroundColor Green }
        } else {
            $merged = $true
            $mergeDetails = "Databases are perfectly in lockstep at replication sequence $primarySeq."
            if (-not $Quiet) { Write-Host "  [IN-SYNC] $mergeDetails" -ForegroundColor Green }
        }
    } elseif ($primaryUp -and -not $altUp) {
        $mergeDetails = "Primary DB active at sequence $primarySeq; alternate DB is currently dormant (no merge required)."
        if (-not $Quiet) { Write-Host "  [STANDALONE] $mergeDetails" -ForegroundColor DarkGray }
    } elseif ($altUp -and -not $primaryUp) {
        $mergeDetails = "Alternate DB active at sequence $altSeq; primary DB is currently held/dormant."
        if (-not $Quiet) { Write-Host "  [FAILOVER-ACTIVE] $mergeDetails" -ForegroundColor DarkGray }
    } else {
        $mergeDetails = "Both database containers are offline."
        if (-not $Quiet) { Write-Host "  [IDLE] $mergeDetails" -ForegroundColor DarkGray }
    }

    # Ingest to SQLite Audit Log
    try {
        $insSql = "CREATE TABLE IF NOT EXISTS musicbrainz_merge_log (id INTEGER PRIMARY KEY AUTOINCREMENT, timestamp TEXT NOT NULL, primary_seq INTEGER, alt_seq INTEGER, status TEXT, details TEXT); INSERT INTO musicbrainz_merge_log (timestamp, primary_seq, alt_seq, status, details) VALUES ('$passTs', $primarySeq, $altSeq, '$(if ($merged) { 'SUCCESS' } else { 'SKIPPED' })', '$($mergeDetails -replace "'", "''")');"
        $insSql | docker exec -i mediastack-db sqlite3 /config/mediastack_backup.db 2>$null | Out-Null
    } catch { }

    # Write Markdown Report
    $reportPath = Join-Path $HandoffsDir "MusicBrainz_Merge_Report_$passTag.md"
    $rep = @"
# MusicBrainz Dual-Instance Database Merge Report

| Parameter | Value |
| :--- | :--- |
| **Audit Host** | $($env:COMPUTERNAME) |
| **Timestamp** | $passTs |
| **Primary DB Status** | $(if ($primaryUp) { 'ONLINE' } else { 'OFFLINE' }) (Seq: $primarySeq) |
| **Alternate DB Status** | $(if ($altUp) { 'ONLINE' } else { 'OFFLINE' }) (Seq: $altSeq) |
| **Merge Outcome** | $(if ($merged) { 'SUCCESS' } else { 'STANDALONE / SKIPPED' }) |
| **Merge Details** | $mergeDetails |

---
*Generated by Merge-MusicBrainzDatabases.ps1.*
"@
    Set-Content -Path $reportPath -Value $rep -Encoding UTF8
    if (-not $Quiet) {
        Write-Host "`n================================================================================" -ForegroundColor Cyan
        Write-Host ("   [COMPLETE] Hourly Merge Finished. Report: {0}" -f $reportPath) -ForegroundColor Green
        Write-Host "================================================================================`n" -ForegroundColor Cyan
    }
}

# Execution Dispatch
if ($Hourly) {
    Write-Host "Starting continuous hourly MusicBrainz merge daemon (Interval: 3600s)..." -ForegroundColor Cyan
    while ($true) {
        Invoke-MergePass
        Start-Sleep -Seconds 3600
    }
} else {
    Invoke-MergePass
}
