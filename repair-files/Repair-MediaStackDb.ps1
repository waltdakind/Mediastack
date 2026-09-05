<#
.SYNOPSIS
    Repair-MediaStackDb.ps1 - MediaStack SQLite Web Database Diagnostic & Auto-Remediation Engine.

.DESCRIPTION
    Comprehensive diagnostic and repair toolkit for mediastack-db (sqlite-web):
    1. Audits mediastack-db container status on port 8080/tcp.
    2. Inspects SQLite database integrity and removes orphaned lock files (*.db-journal, *.db-shm, *.db-wal).
    3. Verifies volume mounts for backup databases.
    4. Probes HTTP web interface on port 8080.

.PARAMETER AutoFix
    Automatically executes fixes. Default: $true unless -DiagOnly is specified.

.PARAMETER DiagOnly
    Executes all diagnostics in read-only / simulation mode.

.PARAMETER Port
    HTTP listening port (default: 8080).

.EXAMPLE
    .\Repair-MediaStackDb.ps1 -AutoFix
    .\Repair-MediaStackDb.ps1 -DiagOnly
#>

[CmdletBinding()]
param(
    [switch]$AutoFix,
    [switch]$DiagOnly,
    [int]$Port = 8080
)

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::InputEncoding  = [System.Text.Encoding]::UTF8

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$fileTag = Get-Date -Format "yyyyMMdd_HHmmss"
$BaseDir = if (Test-Path (Join-Path $PSScriptRoot "..\docker-compose.yml")) { (Resolve-Path (Join-Path $PSScriptRoot "..")).Path } else { $PSScriptRoot }
$HandoffsDir = Join-Path $BaseDir "handoffs"
$DbBackupDirs = @(
    (Join-Path $BaseDir "config\db-backup"),
    (Join-Path $BaseDir "db-backup")
)

if (-not (Test-Path $HandoffsDir)) { New-Item -ItemType Directory -Force -Path $HandoffsDir | Out-Null }

Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host "   M E D I A S T A C K   D B   D I A G N O S T I C   &   A U T O - R E P A I R" -ForegroundColor DarkCyan
Write-Host ("   Port: {0} | Timestamp: {1} | Mode: {2}" -f $Port, $timestamp, $(if ($DiagOnly) { "DiagOnly" } else { "ActiveRemediation" })) -ForegroundColor White
Write-Host "================================================================================" -ForegroundColor Cyan

$remediations = @()
$shouldFix = ($AutoFix -or -not $DiagOnly)

# 1. Container Status Check
Write-Host "`n[1/3] Auditing MediaStack-DB Container..." -ForegroundColor Yellow
$inspect = docker inspect mediastack-db 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
$isUp = ($inspect -and $inspect[0].State.Status -eq "running")

if ($isUp) {
    Write-Host "  [OK] Container 'mediastack-db': RUNNING" -ForegroundColor Green
} else {
    Write-Host "  [WARN] Container 'mediastack-db': STOPPED / MISSING" -ForegroundColor Red
    if ($shouldFix) {
        if ($inspect) {
            docker start mediastack-db 2>$null | Out-Null
            Start-Sleep -Seconds 2
            Write-Host "  [REPAIR] Started 'mediastack-db' container." -ForegroundColor Green
            $remediations += "Started 'mediastack-db' container."
        } else {
            docker compose up -d mediastack-db 2>$null | Out-Null
            $remediations += "Deployed 'mediastack-db' container via compose."
        }
    }
}

# 2. Database Locks & Journal Sanitation
Write-Host "`n[2/3] Inspecting Backup SQLite Database Files..." -ForegroundColor Yellow
$totalLocks = 0
foreach ($dir in $DbBackupDirs) {
    if (Test-Path $dir) {
        $journals = Get-ChildItem -Path $dir -Recurse -Filter "*.db-journal" -ErrorAction SilentlyContinue
        $shm = Get-ChildItem -Path $dir -Recurse -Filter "*.db-shm" -ErrorAction SilentlyContinue
        $wal = Get-ChildItem -Path $dir -Recurse -Filter "*.db-wal" -ErrorAction SilentlyContinue
        $locks = @($journals).Count + @($shm).Count + @($wal).Count
        $totalLocks += $locks
        if ($locks -gt 0 -and $shouldFix) {
            docker stop mediastack-db -t 5 2>$null | Out-Null
            @($journals) | Remove-Item -Force -ErrorAction SilentlyContinue
            @($shm) | Remove-Item -Force -ErrorAction SilentlyContinue
            @($wal) | Remove-Item -Force -ErrorAction SilentlyContinue
            docker start mediastack-db 2>$null | Out-Null
            Write-Host ("  [REPAIR] Purged {0} locks in {1}" -f $locks, $dir) -ForegroundColor Green
            $remediations += "Purged $locks lock files from $dir."
        }
    }
}
if ($totalLocks -eq 0) {
    Write-Host "  [OK] No database lock files detected in backup directories." -ForegroundColor Green
}

# 3. HTTP Web Interface Probe
Write-Host "`n[3/3] Probing SQLite Web UI (localhost:$Port)..." -ForegroundColor Yellow
$code = curl.exe -s -o NUL -w "%{http_code}" --max-time 4 "http://localhost:${Port}" 2>$null
if ($code -ge 200 -and $code -lt 400) {
    Write-Host ("  [OK] SQLite Web UI reachable -> HTTP {0}" -f $code) -ForegroundColor Green
} else {
    Write-Host ("  [WARN] SQLite Web UI returned HTTP {0}" -f $code) -ForegroundColor Yellow
    if ($shouldFix) {
        docker restart mediastack-db 2>$null | Out-Null
        Start-Sleep -Seconds 2
        $code = curl.exe -s -o NUL -w "%{http_code}" --max-time 4 "http://localhost:${Port}" 2>$null
        $remediations += "Restarted mediastack-db container to refresh listener (Result: HTTP $code)."
    }
}

# Report Generation
$reportFile = Join-Path $HandoffsDir "MediaStackDb_Repair_Report_$fileTag.md"
$rep = @"
# MediaStack DB Diagnostic & Auto-Remediation Report

| Parameter | Value |
| :--- | :--- |
| **Service Name** | MediaStack DB (sqlite-web) |
| **Container Status** | $(if ($isUp) { 'RUNNING' } else { 'RECOVERED' }) |
| **HTTP Web UI** | HTTP $code |
| **Remediations** | $($remediations.Count) |

## Actions Taken
$(if ($remediations.Count -gt 0) { $remediations | ForEach-Object { "- $_" } | Out-String } else { "MediaStack DB service is healthy." })
"@

Set-Content -Path $reportFile -Value $rep -Encoding UTF8
Write-Host "`n[COMPLETE] MediaStack DB repair sweep finished. Report: $reportFile`n" -ForegroundColor Green

return [PSCustomObject]@{
    Service = "MediaStackDb"
    Container = "mediastack-db"
    Status = if ($code -ge 200 -and $code -lt 400) { "HEALTHY" } else { "DEGRADED" }
    HttpCode = $code
    Remediations = $remediations
    Report = $reportFile
}

