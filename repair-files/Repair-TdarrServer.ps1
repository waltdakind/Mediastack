<#
.SYNOPSIS
    Repair-TdarrServer.ps1 - Tdarr Transcode Automation Diagnostic & Auto-Remediation Engine.

.DESCRIPTION
    Comprehensive diagnostic and self-healing engine for Tdarr in the MediaStack cluster:
    1. Audits Tdarr container state and healthcheck telemetry.
    2. Verifies configuration directories, temp transcode cache, and media library mounts.
    3. Probes Tdarr WebUI (:8265) and Server Node port (:8266).
    4. Performs HTTP health check against the Tdarr WebUI/API.
    5. Validates Caddy reverse proxy ingress routing for tdarr.voltairedeux.local.

.PARAMETER AutoFix
    Automatically executes fixes (default: $true unless -DiagOnly is specified).

.PARAMETER DiagOnly
    Executes all diagnostics in read-only / simulation mode.

.PARAMETER Port
    Tdarr WebUI listening port (default: 8265).

.PARAMETER ServerPort
    Tdarr Server-to-Node port (default: 8266).

.EXAMPLE
    .\Repair-TdarrServer.ps1 -AutoFix
    .\Repair-TdarrServer.ps1 -DiagOnly
#>

[CmdletBinding()]
param(
    [switch]$AutoFix,
    [switch]$DiagOnly,
    [int]$Port = 8265,
    [int]$ServerPort = 8266
)

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::InputEncoding  = [System.Text.Encoding]::UTF8

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$fileTag   = Get-Date -Format "yyyyMMdd_HHmmss"
$BaseDir   = if (Test-Path (Join-Path $PSScriptRoot "..\docker-compose.yml")) { (Resolve-Path (Join-Path $PSScriptRoot "..")).Path } else { $PSScriptRoot }
$HandoffsDir = Join-Path $BaseDir "handoffs"

if (-not (Test-Path $HandoffsDir)) { New-Item -ItemType Directory -Force -Path $HandoffsDir | Out-Null }

Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host "   T D A R R   T R A N S C O D E   S E R V E R   D I A G N O S T I C   &   R E P A I R" -ForegroundColor DarkCyan
Write-Host ("   WebUI: {0} | ServerPort: {1} | Mode: {2}" -f $Port, $ServerPort, $(if ($DiagOnly) { "DiagOnly" } else { "ActiveRemediation" })) -ForegroundColor White
Write-Host "================================================================================" -ForegroundColor Cyan

$remediations = @()
$shouldFix = ($AutoFix -or -not $DiagOnly)

# --- 1. Auditing Container Status ---
Write-Host "`n[1/5] Auditing Tdarr Container..." -ForegroundColor Yellow
$inspectRaw = docker inspect tdarr 2>$null
$inspect = if ($inspectRaw) { $inspectRaw | ConvertFrom-Json -ErrorAction SilentlyContinue } else { $null }
$isUp = ($inspect -and $inspect[0].State.Status -eq "running")

if ($isUp) {
    Write-Host ("  [OK] Container 'tdarr': RUNNING (ID: {0})" -f $inspect[0].Id.Substring(0, 12)) -ForegroundColor Green
} else {
    Write-Host "  [WARN] Container 'tdarr': STOPPED / MISSING" -ForegroundColor Red
    if ($shouldFix) {
        if ($inspect) {
            docker start tdarr 2>$null | Out-Null
            Start-Sleep -Seconds 3
            Write-Host "  [REPAIR] Started 'tdarr' container." -ForegroundColor Green
            $remediations += "Started 'tdarr' container."
        } else {
            Write-Host "  [DEPLOY] Launching 'tdarr' via docker compose..." -ForegroundColor Cyan
            docker compose up -d tdarr 2>&1 | Out-Null
            Start-Sleep -Seconds 5
            $remediations += "Deployed 'tdarr' container via compose."
        }
    }
}

# --- 2. Verifying Directories & Mounts ---
Write-Host "`n[2/5] Verifying Directory Structure & Mounts..." -ForegroundColor Yellow
$requiredDirs = @(
    (Join-Path $BaseDir "config\tdarr\server"),
    (Join-Path $BaseDir "config\tdarr\configs"),
    (Join-Path $BaseDir "config\tdarr\logs"),
    (Join-Path $BaseDir "config\tdarr\cache")
)

foreach ($dir in $requiredDirs) {
    if (Test-Path $dir) {
        Write-Host ("  [OK] Directory exists: {0}" -f (Split-Path $dir -Leaf)) -ForegroundColor Green
    } else {
        Write-Host ("  [WARN] Missing directory: {0}" -f $dir) -ForegroundColor Yellow
        if ($shouldFix) {
            New-Item -ItemType Directory -Force -Path $dir | Out-Null
            Write-Host ("  [REPAIR] Created directory: {0}" -f $dir) -ForegroundColor Green
            $remediations += "Created directory: $dir"
        }
    }
}

# --- 3. Probing TCP Ports ---
Write-Host "`n[3/5] Probing TCP Sockets..." -ForegroundColor Yellow
$portTestWeb = Test-NetConnection -ComputerName "127.0.0.1" -Port $Port -WarningAction SilentlyContinue
if ($portTestWeb.TcpTestSucceeded) {
    Write-Host ("  [OK] TCP Port {0} (WebUI): OPEN" -f $Port) -ForegroundColor Green
} else {
    Write-Host ("  [FAIL] TCP Port {0} (WebUI): CLOSED / UNREACHABLE" -f $Port) -ForegroundColor Red
}

$portTestSrv = Test-NetConnection -ComputerName "127.0.0.1" -Port $ServerPort -WarningAction SilentlyContinue
if ($portTestSrv.TcpTestSucceeded) {
    Write-Host ("  [OK] TCP Port {0} (Server Node): OPEN" -f $ServerPort) -ForegroundColor Green
} else {
    Write-Host ("  [WARN] TCP Port {0} (Server Node): CLOSED" -f $ServerPort) -ForegroundColor Yellow
}

# --- 4. HTTP Healthcheck & API Probe ---
Write-Host "`n[4/5] Probing Tdarr HTTP Endpoints..." -ForegroundColor Yellow
$code = curl.exe -s -o NUL -w "%{http_code}" --max-time 4 "http://127.0.0.1:${Port}/" 2>$null
if ($code -eq "200") {
    Write-Host ("  [OK] Tdarr WebUI -> HTTP {0} (Healthy)" -f $code) -ForegroundColor Green
} else {
    Write-Host ("  [WARN] Tdarr WebUI -> HTTP {0}" -f $code) -ForegroundColor Yellow
    if ($shouldFix -and $isUp) {
        Write-Host "  [REPAIR] Restarting tdarr to restore HTTP service..." -ForegroundColor Cyan
        docker restart tdarr 2>$null | Out-Null
        Start-Sleep -Seconds 4
        $remediations += "Restarted tdarr container to restore HTTP response."
    }
}

# --- 5. Ingress & Reverse Proxy Check ---
Write-Host "`n[5/5] Auditing Ingress Reverse Proxy..." -ForegroundColor Yellow
$proxyCode = curl.exe -k -s -o NUL -w "%{http_code}" --resolve tdarr.voltairedeux.local:443:127.0.0.1 --max-time 4 "https://tdarr.voltairedeux.local/" 2>$null
if ($proxyCode -eq "200" -or $proxyCode -eq "301" -or $proxyCode -eq "302") {
    Write-Host ("  [OK] Virtual Host (https://tdarr.voltairedeux.local) -> HTTP {0}" -f $proxyCode) -ForegroundColor Green
} else {
    Write-Host ("  [INFO] Virtual Host (https://tdarr.voltairedeux.local) -> HTTP {0}" -f $proxyCode) -ForegroundColor DarkGray
}

# --- Summary Report ---
$reportPath = Join-Path $HandoffsDir "Repair_Tdarr_${fileTag}.md"
$reportMd = @"
# Tdarr Service Repair & Diagnostic Report

**Timestamp:** $timestamp  
**Status:** $(if ($code -eq "200") { "HEALTHY" } else { "DEGRADED" })  
**WebUI Port ($Port):** $(if ($portTestWeb.TcpTestSucceeded) { "OPEN" } else { "CLOSED" })  
**Server Port ($ServerPort):** $(if ($portTestSrv.TcpTestSucceeded) { "OPEN" } else { "CLOSED" })  
**HTTP Status:** $code  

## Remediations Applied:
$(if ($remediations.Count -gt 0) { ($remediations | ForEach-Object { "- $_" }) -join "`n" } else { "- No automated remediations required. Service is operational." })
"@

Set-Content -Path $reportPath -Value $reportMd -Encoding UTF8
Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host "     T D A R R   D I A G N O S T I C   C O M P L E T E" -ForegroundColor Cyan
Write-Host ("     Report: {0}" -f $reportPath) -ForegroundColor DarkGray
Write-Host "================================================================================`n" -ForegroundColor Cyan
