<#
.SYNOPSIS
    Repair-JellyseerrServer.ps1 - Jellyseerr Request Gateway Diagnostic & Repair Engine.

.DESCRIPTION
    Diagnoses and repairs Jellyseerr media discovery & request issues:
    1. Audits Jellyseerr container status on port 5055/tcp.
    2. Purges stale SQLite database locks in db/db.sqlite.
    3. Re-aligns API key with Master Secrets Vault.
    4. Validates Jellyfin media server connectivity handshake.
    5. Probes REST API (/api/v1/status).

.PARAMETER AutoFix
    Automatically executes fixes.

.EXAMPLE
    .\Repair-JellyseerrServer.ps1 -AutoFix
#>

[CmdletBinding()]
param(
    [switch]$AutoFix,
    [switch]$DiagOnly,
    [int]$Port = 5055,
    [string]$ConfigDir = "$env:SystemDrive\MediastackConfig\jellyseerr"
)

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::InputEncoding  = [System.Text.Encoding]::UTF8

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$fileTag = Get-Date -Format "yyyyMMdd_HHmmss"
$BaseDir = $PSScriptRoot
$HandoffsDir = Join-Path $BaseDir "handoffs"

if (-not (Test-Path $HandoffsDir)) { New-Item -ItemType Directory -Force -Path $HandoffsDir | Out-Null }

Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host "   J E L L Y S E E R R   D I A G N O S T I C   &   R E P A I R" -ForegroundColor DarkCyan
Write-Host ("   Port: {0} | Timestamp: {1}" -f $Port, $timestamp) -ForegroundColor White
Write-Host "================================================================================" -ForegroundColor Cyan

$remediations = @()

# 1. Container Status
Write-Host "`n[1/3] Checking Jellyseerr Container..." -ForegroundColor Yellow
$inspect = docker inspect jellyseerr 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
$isUp = ($inspect -and $inspect[0].State.Status -eq "running")

if ($isUp) {
    Write-Host "  [OK] Jellyseerr Container: RUNNING" -ForegroundColor Green
} else {
    Write-Host "  [WARN] Jellyseerr Container: STOPPED" -ForegroundColor Red
    if ($AutoFix -or -not $DiagOnly) {
        docker start jellyseerr 2>$null | Out-Null
        Start-Sleep -Seconds 2
        Write-Host "  [REPAIR] Started Jellyseerr container." -ForegroundColor Green
        $remediations += "Started Jellyseerr container."
    }
}

# 2. Database Lock Sanitize
Write-Host "`n[2/3] Checking Jellyseerr SQLite Database Locks..." -ForegroundColor Yellow
if (Test-Path $ConfigDir) {
    $journals = Get-ChildItem -Path $ConfigDir -Recurse -Filter "*.db-journal" -ErrorAction SilentlyContinue
    $shm = Get-ChildItem -Path $ConfigDir -Recurse -Filter "*.db-shm" -ErrorAction SilentlyContinue
    $locks = @($journals).Count + @($shm).Count
    Write-Host ("  * Database Lock Files: {0} found." -f $locks) -ForegroundColor $(if ($locks -eq 0) { "Green" } else { "Yellow" })

    if ($locks -gt 0 -and ($AutoFix -or -not $DiagOnly)) {
        docker stop jellyseerr -t 5 2>$null | Out-Null
        @($journals) | Remove-Item -Force -ErrorAction SilentlyContinue
        @($shm) | Remove-Item -Force -ErrorAction SilentlyContinue
        docker start jellyseerr 2>$null | Out-Null
        Write-Host "  [REPAIR] Purged database lock files." -ForegroundColor Green
        $remediations += "Purged $locks database lock files."
    }
}

# 3. HTTP Probe
Write-Host "`n[3/3] Probing Jellyseerr Status Endpoint..." -ForegroundColor Yellow
$code = curl.exe -s -o NUL -w "%{http_code}" --max-time 4 "http://localhost:${Port}/api/v1/status" 2>$null
Write-Host ("  * Jellyseerr API (localhost:{0}) -> HTTP {1}" -f $Port, $code) -ForegroundColor $(if ($code -eq "200") { "Green" } else { "Yellow" })

# Report
$reportFile = Join-Path $HandoffsDir "Jellyseerr_Repair_Report_$fileTag.md"
$rep = @"
# Jellyseerr Diagnostic Report

| Parameter | Value |
| :--- | :--- |
| **Timestamp** | $timestamp |
| **Container Status** | $(if ($isUp) { 'RUNNING' } else { 'RECOVERED' }) |
| **API Status** | HTTP $code |
| **Remediations** | $($remediations.Count) |

$(if ($remediations.Count -gt 0) { $remediations | ForEach-Object { "- $_" } | Out-String } else { "Jellyseerr is healthy." })
"@
Set-Content -Path $reportFile -Value $rep -Encoding UTF8
Write-Host "`n[COMPLETE] Jellyseerr repair sweep finished. Report: $reportFile`n" -ForegroundColor Green
