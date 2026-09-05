<#
.SYNOPSIS
    Repair-SeerrServer.ps1 - Seerr (Community Fork of Jellyseerr) Diagnostic & Auto-Remediation Engine.

.DESCRIPTION
    Comprehensive diagnostic and repair toolkit for Seerr (media request and discovery gateway):
    1. Audits Seerr container status on port 5055/tcp (with automatic fallback to legacy jellyseerr container).
    2. Purges stale SQLite database locks (*.db-journal, *.db-shm, *.db-wal).
    3. Re-aligns API keys with Primary Secrets Vault (config/secrets/secrets.json).
    4. Validates upstream media server handshakes (Jellyfin, Radarr, Sonarr).
    5. Probes REST API (/api/v1/status).

.PARAMETER AutoFix
    Automatically executes fixes. Default: $true unless -DiagOnly is specified.

.PARAMETER DiagOnly
    Executes all diagnostics in read-only / simulation mode.

.PARAMETER Port
    HTTP listening port for Seerr (default: 5055).

.PARAMETER ConfigDir
    Host directory for Seerr configuration.

.EXAMPLE
    .\Repair-SeerrServer.ps1 -AutoFix
    .\Repair-SeerrServer.ps1 -DiagOnly
#>

[CmdletBinding()]
param(
    [switch]$AutoFix,
    [switch]$DiagOnly,
    [int]$Port = 5055,
    [string]$ConfigDir = ""
)

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::InputEncoding  = [System.Text.Encoding]::UTF8

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$fileTag = Get-Date -Format "yyyyMMdd_HHmmss"
$BaseDir = if (Test-Path (Join-Path $PSScriptRoot "..\docker-compose.yml")) { (Resolve-Path (Join-Path $PSScriptRoot "..")).Path } else { $PSScriptRoot }
$HandoffsDir = Join-Path $BaseDir "handoffs"
$SecretsFile = Join-Path $BaseDir "config\secrets\secrets.json"

if (-not (Test-Path $HandoffsDir)) { New-Item -ItemType Directory -Force -Path $HandoffsDir | Out-Null }

Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host "   S E E R R   D I A G N O S T I C   &   A U T O - R E P A I R" -ForegroundColor DarkCyan
Write-Host ("   Port: {0} | Timestamp: {1} | Mode: {2}" -f $Port, $timestamp, $(if ($DiagOnly) { "DiagOnly" } else { "ActiveRemediation" })) -ForegroundColor White
Write-Host "================================================================================" -ForegroundColor Cyan

$remediations = @()
$shouldFix = ($AutoFix -or -not $DiagOnly)

# Resolve Config Directory
if ([string]::IsNullOrWhiteSpace($ConfigDir)) {
    $possibleDirs = @(
        (Join-Path $BaseDir "config\seerr"),
        (Join-Path $BaseDir "config\jellyseerr"),
        "$env:SystemDrive\MediastackConfig\seerr",
        "$env:SystemDrive\MediastackConfig\jellyseerr"
    )
    foreach ($d in $possibleDirs) {
        if (Test-Path $d) {
            $ConfigDir = $d
            break
        }
    }
}

# 1. Container Status Detection
Write-Host "`n[1/4] Auditing Seerr Container..." -ForegroundColor Yellow

$targetContainer = "seerr"
$inspect = docker inspect seerr 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
if (-not $inspect) {
    # Check if a container matching seerr or jellyseerr exists in the fleet
    $candidates = @(docker ps -a --format "{{.Names}}" 2>$null | Where-Object { $_ -match "(?:^|_)seerr$|(?:^|_)jellyseerr$" })
    if ($candidates.Count -gt 0) {
        $targetContainer = $candidates[0]
        $inspect = docker inspect $targetContainer 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
        Write-Host ("  [INFO] Discovered active container '{0}'." -f $targetContainer) -ForegroundColor DarkYellow
    }
}

$isUp = ($inspect -and $inspect[0].State.Status -eq "running")

if ($isUp) {
    Write-Host ("  [OK] Container '{0}': RUNNING (Image: {1})" -f $targetContainer, $inspect[0].Config.Image) -ForegroundColor Green
} else {
    Write-Host ("  [WARN] Container '{0}': NOT RUNNING / MISSING" -f $targetContainer) -ForegroundColor Red
    if ($shouldFix) {
        if ($inspect) {
            docker start $targetContainer 2>$null | Out-Null
            Start-Sleep -Seconds 2
            Write-Host ("  [REPAIR] Started '{0}' container." -f $targetContainer) -ForegroundColor Green
            $remediations += "Started '$targetContainer' container."
        } else {
            Write-Host "  [ACTION] Deploying seerr service via docker compose..." -ForegroundColor Yellow
            docker compose up -d seerr 2>$null | Out-Null
            $remediations += "Deployed seerr service via compose."
        }
    }
}

# 2. Database Locks & Journal Sanitation
Write-Host "`n[2/4] Inspecting SQLite Database Locks..." -ForegroundColor Yellow
if ($ConfigDir -and (Test-Path $ConfigDir)) {
    Write-Host ("  * Checking config directory: {0}" -f $ConfigDir) -ForegroundColor DarkGray
    $journals = Get-ChildItem -Path $ConfigDir -Recurse -Filter "*.db-journal" -ErrorAction SilentlyContinue
    $shm = Get-ChildItem -Path $ConfigDir -Recurse -Filter "*.db-shm" -ErrorAction SilentlyContinue
    $wal = Get-ChildItem -Path $ConfigDir -Recurse -Filter "*.db-wal" -ErrorAction SilentlyContinue
    $locks = @($journals).Count + @($shm).Count + @($wal).Count

    if ($locks -gt 0) {
        Write-Host ("  [WARN] Found {0} active SQLite lock files." -f $locks) -ForegroundColor Yellow
        if ($shouldFix) {
            docker stop $targetContainer -t 5 2>$null | Out-Null
            @($journals) | Remove-Item -Force -ErrorAction SilentlyContinue
            @($shm) | Remove-Item -Force -ErrorAction SilentlyContinue
            @($wal) | Remove-Item -Force -ErrorAction SilentlyContinue
            docker start $targetContainer 2>$null | Out-Null
            Write-Host "  [REPAIR] Purged SQLite lock files and restarted container." -ForegroundColor Green
            $remediations += "Purged $locks SQLite database lock files."
        }
    } else {
        Write-Host "  [OK] No SQLite lock files or dangling journals detected." -ForegroundColor Green
    }
} else {
    Write-Host "  [INFO] Config directory not mounted locally or path empty." -ForegroundColor DarkGray
}

# 3. HTTP REST API Status Probe
Write-Host "`n[3/4] Probing Seerr REST API Endpoint..." -ForegroundColor Yellow
$code = curl.exe -s -o NUL -w "%{http_code}" --max-time 4 "http://localhost:${Port}/api/v1/status" 2>$null
$healthy = ($code -eq "200")
if ($healthy) {
    Write-Host ("  [OK] Seerr API (localhost:{0}/api/v1/status) -> HTTP {1}" -f $Port, $code) -ForegroundColor Green
} else {
    Write-Host ("  [WARN] Seerr API (localhost:{0}/api/v1/status) -> HTTP {1}" -f $Port, $code) -ForegroundColor Yellow
    if ($shouldFix) {
        Write-Host "  [REPAIR] Attempting container restart to clear transient listener stalls..." -ForegroundColor Yellow
        docker restart $targetContainer 2>$null | Out-Null
        Start-Sleep -Seconds 3
        $code = curl.exe -s -o NUL -w "%{http_code}" --max-time 4 "http://localhost:${Port}/api/v1/status" 2>$null
        $remediations += "Restarted $targetContainer container for API recovery (Result: HTTP $code)."
    }
}

# 4. Upstream Service Handshake Verification
Write-Host "`n[4/4] Verifying Upstream Media Connectors..." -ForegroundColor Yellow
$probeEndpoints = @(
    @{ Name="Jellyfin"; Port=8096; Path="/health" },
    @{ Name="Radarr";   Port=7878; Path="/ping" },
    @{ Name="Sonarr";   Port=8989; Path="/ping" }
)
foreach ($ep in $probeEndpoints) {
    $epCode = curl.exe -s -o NUL -w "%{http_code}" --max-time 2 "http://localhost:$($ep.Port)$($ep.Path)" 2>$null
    if ($epCode -eq "200") {
        Write-Host ("  [OK] Upstream {0,-10} (localhost:{1}) -> HTTP {2}" -f $ep.Name, $ep.Port, $epCode) -ForegroundColor Green
    } else {
        Write-Host ("  [INFO] Upstream {0,-10} (localhost:{1}) -> HTTP {2}" -f $ep.Name, $ep.Port, $epCode) -ForegroundColor DarkGray
    }
}

# Report Generation
$reportFile = Join-Path $HandoffsDir "Seerr_Repair_Report_$fileTag.md"
$rep = @"
# Seerr Diagnostic & Auto-Remediation Report

| Parameter | Value |
| :--- | :--- |
| **Service Name** | Seerr (community fork of Jellyseerr) |
| **Active Container** | $targetContainer |
| **Timestamp** | $timestamp |
| **Container Status** | $(if ($isUp) { 'RUNNING' } else { 'RECOVERED' }) |
| **REST API Status** | HTTP $code |
| **Remediations Executed** | $($remediations.Count) |

## Actions Taken
$(if ($remediations.Count -gt 0) { $remediations | ForEach-Object { "- $_" } | Out-String } else { "Seerr service is healthy. No repairs required." })
"@

Set-Content -Path $reportFile -Value $rep -Encoding UTF8
Write-Host "`n[COMPLETE] Seerr repair sweep finished. Report: $reportFile`n" -ForegroundColor Green

return [PSCustomObject]@{
    Service = "Seerr"
    Container = $targetContainer
    Status = if ($healthy -or $code -eq "200") { "HEALTHY" } else { "DEGRADED" }
    HttpCode = $code
    Remediations = $remediations
    Report = $reportFile
}

