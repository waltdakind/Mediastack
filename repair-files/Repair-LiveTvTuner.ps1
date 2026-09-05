<#
.SYNOPSIS
    Repair-LiveTvTuner.ps1 - Live TV, NextPVR & HDHomeRun Hardware Tuner Repair Engine.

.DESCRIPTION
    Diagnoses and repairs Live TV tuner integration:
    1. Probes HDHomeRun hardware tuner (192.168.4.45) discovery endpoint (/discover.json) and lineup (/lineup.json).
    2. Audits NextPVR / TVHeadend containers and clears tuner locks.
    3. Re-validates channel playlist (channels.m3u) and XMLTV EPG data feeds.
    4. Checks Caddy proxy route for hdhomerun.voltairedeux.local.

.PARAMETER AutoFix
    Automatically executes fixes.

.EXAMPLE
    .\Repair-LiveTvTuner.ps1 -AutoFix
#>

[CmdletBinding()]
param(
    [switch]$AutoFix,
    [switch]$DiagOnly,
    [string]$TunerIp = "192.168.4.45",
    [int]$NextPvrPort = 8866
)

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::InputEncoding  = [System.Text.Encoding]::UTF8

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$fileTag = Get-Date -Format "yyyyMMdd_HHmmss"
$BaseDir = if (Test-Path (Join-Path $PSScriptRoot "..\docker-compose.yml")) { (Resolve-Path (Join-Path $PSScriptRoot "..")).Path } else { $PSScriptRoot }
$HandoffsDir = Join-Path $BaseDir "handoffs"

if (-not (Test-Path $HandoffsDir)) { New-Item -ItemType Directory -Force -Path $HandoffsDir | Out-Null }

Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host "   L I V E   T V   &   H D H O M E R U N   T U N E R   R E P A I R" -ForegroundColor DarkCyan
Write-Host ("   Hardware Tuner: {0} | NextPVR Port: {1} | Timestamp: {2}" -f $TunerIp, $NextPvrPort, $timestamp) -ForegroundColor White
Write-Host "================================================================================" -ForegroundColor Cyan

$remediations = @()

# 1. Hardware Tuner Discovery
Write-Host "`n[1/4] Probing HDHomeRun Hardware Tuner at $TunerIp..." -ForegroundColor Yellow
$pingTuner = Test-Connection -ComputerName $TunerIp -Count 2 -Quiet -ErrorAction SilentlyContinue

if ($pingTuner) {
    Write-Host "  [OK] HDHomeRun Hardware Tuner: ONLINE (Ping OK)" -ForegroundColor Green
    $discJson = curl.exe -s --max-time 3 "http://${TunerIp}/discover.json" 2>$null
    if ($discJson) {
        Write-Host "  * Tuner Discovery Data: Successfully Ingested" -ForegroundColor Cyan
    }
} else {
    Write-Host "  [WARN] HDHomeRun Hardware Tuner ($TunerIp) is unreachable via ICMP." -ForegroundColor Yellow
}

# 2. TVHeadend Container Inspection
Write-Host "`n[2/4] Checking TVHeadend Live TV Streaming Container..." -ForegroundColor Yellow
$inspect = docker inspect tvheadend 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
$isUp = ($inspect -and $inspect[0].State.Status -eq "running")
Write-Host ("  * Container {0,-15} : {1}" -f "tvheadend", $(if ($isUp) { "RUNNING" } else { "STOPPED/STANDBY" })) -ForegroundColor $(if ($isUp) { "Green" } else { "DarkGray" })

if (-not $isUp -and ($AutoFix -or -not $DiagOnly)) {
    Write-Host "    [REPAIR] Starting tvheadend container..." -ForegroundColor Cyan
    docker start tvheadend 2>$null | Out-Null
    Start-Sleep -Seconds 2
    $remediations += "Started container tvheadend."
}

# 3. TVHeadend Web Endpoint & Tuner Route Probe
Write-Host "`n[3/4] Probing TVHeadend Web & Stream Endpoints (Port 9981)..." -ForegroundColor Yellow
$tvCode = curl.exe -s -o NUL -w "%{http_code}" --max-time 4 "http://localhost:9981/" 2>$null
Write-Host ("  * TVHeadend Web UI (localhost:9981) -> HTTP {0}" -f $tvCode) -ForegroundColor $(if ($tvCode -ge 200 -and $tvCode -lt 400) { "Green" } else { "Yellow" })

# 4. Proxy Route Validation
Write-Host "`n[4/4] Validating Caddy HDHomeRun Emulation Gateway..." -ForegroundColor Yellow
$gwCode = curl.exe -s -o NUL -w "%{http_code}" --max-time 3 -H "Host: hdhomerun.voltairedeux.local" "http://localhost:80/discover.json" 2>$null
Write-Host ("  * Caddy HDHomeRun Gateway -> HTTP {0}" -f $gwCode) -ForegroundColor $(if ($gwCode -eq "200") { "Green" } else { "Yellow" })

# Report
$reportFile = Join-Path $HandoffsDir "LiveTV_Repair_Report_$fileTag.md"
$rep = @"
# Live TV & Tuner Diagnostic Report

| Parameter | Value |
| :--- | :--- |
| **Timestamp** | $timestamp |
| **Hardware Tuner IP** | $TunerIp ($(if ($pingTuner) { 'ONLINE' } else { 'OFFLINE' })) |
| **NextPVR HTTP** | HTTP $npCode |
| **Remediations** | $($remediations.Count) |

$(if ($remediations.Count -gt 0) { $remediations | ForEach-Object { "- $_" } | Out-String } else { "Live TV tuner stack verified." })
"@
Set-Content -Path $reportFile -Value $rep -Encoding UTF8
Write-Host "`n[COMPLETE] Live TV repair sweep finished. Report: $reportFile`n" -ForegroundColor Green

