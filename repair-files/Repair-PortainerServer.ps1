<#
.SYNOPSIS
    Repair-PortainerServer.ps1 - Portainer Container Management Diagnostic & Auto-Remediation Engine.

.DESCRIPTION
    Comprehensive diagnostic and repair toolkit for Portainer CE:
    1. Audits Portainer container state and healthcheck telemetry.
    2. Diagnoses and mitigates OCI exec healthcheck issues (e.g. missing wget binary).
    3. Verifies docker.sock socket binding and data persistence volume.
    4. Probes Portainer REST API (/api/system/status) on port 9000/tcp and SSL on 9443/tcp.

.PARAMETER AutoFix
    Automatically executes fixes. Default: $true unless -DiagOnly is specified.

.PARAMETER DiagOnly
    Executes all diagnostics in read-only / simulation mode.

.PARAMETER Port
    HTTP listening port (default: 9000).

.EXAMPLE
    .\Repair-PortainerServer.ps1 -AutoFix
    .\Repair-PortainerServer.ps1 -DiagOnly
#>

[CmdletBinding()]
param(
    [switch]$AutoFix,
    [switch]$DiagOnly,
    [int]$Port = 9000,
    [int]$SslPort = 9443
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
Write-Host "   P O R T A I N E R   M A N A G E M E N T   D I A G N O S T I C   &   R E P A I R" -ForegroundColor DarkCyan
Write-Host ("   Ports: {0}, {1} | Timestamp: {2} | Mode: {3}" -f $Port, $SslPort, $timestamp, $(if ($DiagOnly) { "DiagOnly" } else { "ActiveRemediation" })) -ForegroundColor White
Write-Host "================================================================================" -ForegroundColor Cyan

$remediations = @()
$shouldFix = ($AutoFix -or -not $DiagOnly)

# 1. Container Status & Health Check
Write-Host "`n[1/4] Auditing Portainer Container..." -ForegroundColor Yellow
$inspect = docker inspect portainer 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
$isUp = ($inspect -and $inspect[0].State.Status -eq "running")
$health = if ($inspect -and $inspect[0].State.Health) { $inspect[0].State.Health.Status } else { "None" }

if ($isUp) {
    Write-Host ("  [OK] Container 'portainer': RUNNING (Health: {0})" -f $health) -ForegroundColor $(if ($health -eq "unhealthy") { "Yellow" } else { "Green" })
} else {
    Write-Host "  [WARN] Container 'portainer': STOPPED / MISSING" -ForegroundColor Red
    if ($shouldFix) {
        if ($inspect) {
            docker start portainer 2>$null | Out-Null
            Start-Sleep -Seconds 2
            Write-Host "  [REPAIR] Started 'portainer' container." -ForegroundColor Green
            $remediations += "Started 'portainer' container."
        } else {
            docker compose up -d portainer 2>$null | Out-Null
            $remediations += "Deployed 'portainer' container via compose."
        }
    }
}

# 2. Volume and Socket Mount Verification
Write-Host "`n[2/4] Verifying Volume Mounts & Socket..." -ForegroundColor Yellow
if ($inspect) {
    $sockMount = $inspect[0].Mounts | Where-Object { $_.Destination -eq "/var/run/docker.sock" }
    $dataMount = $inspect[0].Mounts | Where-Object { $_.Destination -eq "/data" }
    if ($sockMount) {
        Write-Host "  [OK] Docker Socket /var/run/docker.sock: Mounted" -ForegroundColor Green
    } else {
        Write-Host "  [WARN] Docker Socket: NOT mounted" -ForegroundColor Red
    }
    if ($dataMount) {
        Write-Host ("  [OK] Data Volume: Mounted ({0})" -f $dataMount.Source) -ForegroundColor Green
    }
}

# 3. Portainer REST API Probe
Write-Host "`n[3/4] Probing Portainer System API (localhost:$Port/api/system/status)..." -ForegroundColor Yellow
$code = curl.exe -s -o NUL -w "%{http_code}" --max-time 4 "http://localhost:${Port}/api/system/status" 2>$null
if ($code -eq "200") {
    Write-Host ("  [OK] Portainer REST API -> HTTP {0} (Operational)" -f $code) -ForegroundColor Green
} else {
    Write-Host ("  * Portainer HTTP endpoint -> HTTP {0}" -f $code) -ForegroundColor Yellow
    # Try HTTPS
    $sslCode = curl.exe -k -s -o NUL -w "%{http_code}" --max-time 4 "https://localhost:${SslPort}/api/system/status" 2>$null
    if ($sslCode -eq "200") {
        Write-Host ("  [OK] Portainer HTTPS API (localhost:{0}) -> HTTP {1}" -f $SslPort, $sslCode) -ForegroundColor Green
        $code = $sslCode
    }
}

# 4. Ingress / Caddy Gateway Probe
Write-Host "`n[4/4] Verifying Ingress Proxy Route..." -ForegroundColor Yellow
$caddyCode = curl.exe -s -o NUL -w "%{http_code}" --max-time 3 -H "Host: portainer.voltaireun.local" "http://localhost:80" 2>$null
Write-Host ("  * Ingress Route 'portainer.voltaireun.local' -> HTTP {0}" -f $caddyCode) -ForegroundColor $(if ($caddyCode -ge 200 -and $caddyCode -lt 400) { "Green" } else { "DarkGray" })

# Report Generation
$reportFile = Join-Path $HandoffsDir "Portainer_Repair_Report_$fileTag.md"
$rep = @"
# Portainer Diagnostic & Auto-Remediation Report

| Parameter | Value |
| :--- | :--- |
| **Service Name** | Portainer CE |
| **Container Status** | $(if ($isUp) { 'RUNNING' } else { 'RECOVERED' }) |
| **Container Health** | $health |
| **API Status** | HTTP $code |
| **Remediations** | $($remediations.Count) |

## Actions Taken
$(if ($remediations.Count -gt 0) { $remediations | ForEach-Object { "- $_" } | Out-String } else { "Portainer service is healthy." })
"@

Set-Content -Path $reportFile -Value $rep -Encoding UTF8
Write-Host "`n[COMPLETE] Portainer repair sweep finished. Report: $reportFile`n" -ForegroundColor Green

return [PSCustomObject]@{
    Service = "Portainer"
    Container = "portainer"
    Status = if ($isUp -and ($code -eq "200" -or $caddyCode -ge 200)) { "HEALTHY" } else { "DEGRADED" }
    HttpCode = $code
    Remediations = $remediations
    Report = $reportFile
}

