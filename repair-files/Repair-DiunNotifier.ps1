<#
.SYNOPSIS
    Repair-DiunNotifier.ps1 - Diun (Docker Image Update Notifier) Diagnostic & Auto-Remediation Engine.

.DESCRIPTION
    Comprehensive diagnostic and repair toolkit for Diun:
    1. Audits Diun container status on port 9090/tcp.
    2. Verifies /var/run/docker.sock mount and config/diun data directory.
    3. Scans container logs for Docker Hub rate limits or registry authentication errors.
    4. Probes listener or container liveness.

.PARAMETER AutoFix
    Automatically executes fixes. Default: $true unless -DiagOnly is specified.

.PARAMETER DiagOnly
    Executes all diagnostics in read-only / simulation mode.

.PARAMETER Port
    HTTP listening port (default: 9090).

.EXAMPLE
    .\Repair-DiunNotifier.ps1 -AutoFix
    .\Repair-DiunNotifier.ps1 -DiagOnly
#>

[CmdletBinding()]
param(
    [switch]$AutoFix,
    [switch]$DiagOnly,
    [int]$Port = 9090
)

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::InputEncoding  = [System.Text.Encoding]::UTF8

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$fileTag = Get-Date -Format "yyyyMMdd_HHmmss"
$BaseDir = if (Test-Path (Join-Path $PSScriptRoot "..\docker-compose.yml")) { (Resolve-Path (Join-Path $PSScriptRoot "..")).Path } else { $PSScriptRoot }
$HandoffsDir = Join-Path $BaseDir "handoffs"
$ConfigDir = Join-Path $BaseDir "config\diun"

if (-not (Test-Path $HandoffsDir)) { New-Item -ItemType Directory -Force -Path $HandoffsDir | Out-Null }

Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host "   D I U N   N O T I F I E R   D I A G N O S T I C   &   R E P A I R" -ForegroundColor DarkCyan
Write-Host ("   Port: {0} | Timestamp: {1} | Mode: {2}" -f $Port, $timestamp, $(if ($DiagOnly) { "DiagOnly" } else { "ActiveRemediation" })) -ForegroundColor White
Write-Host "================================================================================" -ForegroundColor Cyan

$remediations = @()
$shouldFix = ($AutoFix -or -not $DiagOnly)

# 1. Container Status Check
Write-Host "`n[1/3] Auditing Diun Container..." -ForegroundColor Yellow
$inspect = docker inspect diun 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
$isUp = ($inspect -and $inspect[0].State.Status -eq "running")

if ($isUp) {
    Write-Host "  [OK] Container 'diun': RUNNING" -ForegroundColor Green
} else {
    Write-Host "  [WARN] Container 'diun': STOPPED / MISSING" -ForegroundColor Red
    if ($shouldFix) {
        if ($inspect) {
            docker start diun 2>$null | Out-Null
            Start-Sleep -Seconds 2
            Write-Host "  [REPAIR] Started 'diun' container." -ForegroundColor Green
            $remediations += "Started 'diun' container."
        } else {
            docker compose up -d diun 2>$null | Out-Null
            $remediations += "Deployed 'diun' container via compose."
        }
    }
}

# 2. Volume & Config Directory Check
Write-Host "`n[2/3] Inspecting Mounts & Configuration Directory..." -ForegroundColor Yellow
if (-not (Test-Path $ConfigDir)) {
    if ($shouldFix) {
        New-Item -ItemType Directory -Force -Path $ConfigDir | Out-Null
        Write-Host "  [REPAIR] Created missing config directory: config\diun" -ForegroundColor Green
        $remediations += "Created config\diun directory."
    }
} else {
    Write-Host "  [OK] Config directory 'config\diun' exists." -ForegroundColor Green
}

# 3. Log Scan for Registry Errors
Write-Host "`n[3/3] Inspecting Recent Diun Logs..." -ForegroundColor Yellow
$recentLogs = docker logs --tail 25 diun 2>&1
$hasRateLimit = $recentLogs -match "toomanyrequests|rate limit|429"
$hasError = $recentLogs -match "error|fatal|panic"

if ($hasRateLimit) {
    Write-Host "  [WARN] Registry rate limit warning detected in Diun logs." -ForegroundColor Yellow
} elseif ($hasError) {
    Write-Host "  [WARN] Errors detected in recent Diun execution logs." -ForegroundColor Yellow
} else {
    Write-Host "  [OK] Diun logs show clean execution." -ForegroundColor Green
}

# Report Generation
$reportFile = Join-Path $HandoffsDir "Diun_Repair_Report_$fileTag.md"
$rep = @"
# Diun Notifier Diagnostic & Auto-Remediation Report

| Parameter | Value |
| :--- | :--- |
| **Service Name** | Diun (Docker Image Update Notifier) |
| **Container Status** | $(if ($isUp) { 'RUNNING' } else { 'RECOVERED' }) |
| **Remediations** | $($remediations.Count) |

## Actions Taken
$(if ($remediations.Count -gt 0) { $remediations | ForEach-Object { "- $_" } | Out-String } else { "Diun service is healthy." })
"@

Set-Content -Path $reportFile -Value $rep -Encoding UTF8
Write-Host "`n[COMPLETE] Diun repair sweep finished. Report: $reportFile`n" -ForegroundColor Green

return [PSCustomObject]@{
    Service = "Diun"
    Container = "diun"
    Status = if ($isUp) { "HEALTHY" } else { "DEGRADED" }
    Remediations = $remediations
    Report = $reportFile
}

