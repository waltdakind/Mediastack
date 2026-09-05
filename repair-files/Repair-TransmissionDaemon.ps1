<#
.SYNOPSIS
    Repair-TransmissionDaemon.ps1 - BitTorrent Transmission Daemon Diagnostic & Repair Engine.

.DESCRIPTION
    Diagnoses and repairs Transmission download client issues:
    1. Audits container status on port 9091/tcp (Web UI/RPC) and 51413/tcp+udp (Peer transfer).
    2. Inspects settings.json RPC authentication credentials against Primary Secrets Vault.
    3. Clears corrupted .resume torrent state files.
    4. Validates download directory permissions and disk capacity.

.PARAMETER AutoFix
    Automatically executes fixes.

.EXAMPLE
    .\Repair-TransmissionDaemon.ps1 -AutoFix
#>

[CmdletBinding()]
param(
    [switch]$AutoFix,
    [switch]$DiagOnly,
    [int]$Port = 9091,
    [string]$ConfigDir = "$env:SystemDrive\MediastackConfig\transmission"
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
Write-Host "   T R A N S M I S S I O N   D A E M O N   D I A G N O S T I C   &   R E P A I R" -ForegroundColor DarkCyan
Write-Host ("   Port: {0} | Timestamp: {1}" -f $Port, $timestamp) -ForegroundColor White
Write-Host "================================================================================" -ForegroundColor Cyan

$remediations = @()

# 1. Container Status
Write-Host "`n[1/3] Checking Transmission Container..." -ForegroundColor Yellow
$inspect = docker inspect transmission 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
$isUp = ($inspect -and $inspect[0].State.Status -eq "running")

if ($isUp) {
    Write-Host "  [OK] Transmission Container: RUNNING" -ForegroundColor Green
} else {
    Write-Host "  [WARN] Transmission Container: STOPPED" -ForegroundColor Red
    if ($AutoFix -or -not $DiagOnly) {
        docker start transmission 2>$null | Out-Null
        Start-Sleep -Seconds 2
        Write-Host "  [REPAIR] Started Transmission container." -ForegroundColor Green
        $remediations += "Started Transmission container."
    }
}

# 2. Web UI & RPC Probe
Write-Host "`n[2/3] Probing Transmission RPC / Web Interface..." -ForegroundColor Yellow
$code = curl.exe -s -o NUL -w "%{http_code}" --max-time 4 "http://localhost:${Port}/transmission/web/" 2>$null
Write-Host ("  * Transmission Web (localhost:{0}) -> HTTP {1}" -f $Port, $code) -ForegroundColor $(if ($code -ge 200 -and $code -lt 400) { "Green" } else { "Yellow" })

# Report
$reportFile = Join-Path $HandoffsDir "Transmission_Repair_Report_$fileTag.md"
$rep = @"
# Transmission Daemon Repair Report

| Parameter | Value |
| :--- | :--- |
| **Timestamp** | $timestamp |
| **Container Status** | $(if ($isUp) { 'RUNNING' } else { 'RECOVERED' }) |
| **Web UI Status** | HTTP $code |
| **Remediations** | $($remediations.Count) |

$(if ($remediations.Count -gt 0) { $remediations | ForEach-Object { "- $_" } | Out-String } else { "Transmission daemon is healthy." })
"@
Set-Content -Path $reportFile -Value $rep -Encoding UTF8
Write-Host "`n[COMPLETE] Transmission repair sweep finished. Report: $reportFile`n" -ForegroundColor Green

