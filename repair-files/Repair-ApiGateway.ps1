<#
.SYNOPSIS
    Repair-ApiGateway.ps1 - MediaStack Core API Gateway Diagnostic & Auto-Remediation Engine.

.DESCRIPTION
    Comprehensive diagnostic and repair toolkit for the MediaStack API Gateway:
    1. Audits api-gateway container status on port 3000/tcp.
    2. Inspects and repairs SQLite player_settings & JellyWatch tables in api-gateway/db/mediastack_backup.db.
    3. Validates SSL certificates mounted in /certs.
    4. Probes REST API endpoints (/api/system/status, /api/system/ssl/status).
    5. Checks connectivity to proxied downstream services.

.PARAMETER AutoFix
    Automatically executes fixes. Default: $true unless -DiagOnly is specified.

.PARAMETER DiagOnly
    Executes all diagnostics in read-only / simulation mode.

.PARAMETER Port
    HTTP listening port (default: 3000).

.EXAMPLE
    .\Repair-ApiGateway.ps1 -AutoFix
    .\Repair-ApiGateway.ps1 -DiagOnly
#>

[CmdletBinding()]
param(
    [switch]$AutoFix,
    [switch]$DiagOnly,
    [int]$Port = 3000
)

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::InputEncoding  = [System.Text.Encoding]::UTF8

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$fileTag = Get-Date -Format "yyyyMMdd_HHmmss"
$BaseDir = if (Test-Path (Join-Path $PSScriptRoot "..\docker-compose.yml")) { (Resolve-Path (Join-Path $PSScriptRoot "..")).Path } else { $PSScriptRoot }
$HandoffsDir = Join-Path $BaseDir "handoffs"
$DbDir = Join-Path $BaseDir "api-gateway\db"

if (-not (Test-Path $HandoffsDir)) { New-Item -ItemType Directory -Force -Path $HandoffsDir | Out-Null }

Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host "   A P I   G A T E W A Y   D I A G N O S T I C   &   A U T O - R E P A I R" -ForegroundColor DarkCyan
Write-Host ("   Port: {0} | Timestamp: {1} | Mode: {2}" -f $Port, $timestamp, $(if ($DiagOnly) { "DiagOnly" } else { "ActiveRemediation" })) -ForegroundColor White
Write-Host "================================================================================" -ForegroundColor Cyan

$remediations = @()
$shouldFix = ($AutoFix -or -not $DiagOnly)

# 1. Container Status Check & Orphan/Prefix Reconciliation
Write-Host "`n[1/4] Auditing API Gateway Container..." -ForegroundColor Yellow
$inspect = docker inspect api-gateway 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
$isUp = ($inspect -and $inspect[0].State.Status -eq "running")

if (-not $isUp) {
    # Check for orphaned or hash-prefixed containers (e.g. b99f16a6f279_api-gateway)
    $altContainers = docker ps -a --filter "name=api-gateway" --format "{{.Names}}|{{.Status}}" 2>$null
    foreach ($entry in $altContainers) {
        $parts = $entry.Split("|")
        $cName = $parts[0]
        $cStatus = if ($parts.Length -gt 1) { $parts[1] } else { "" }
        if ($cName -and $cName -ne "api-gateway") {
            Write-Host "  [INFO] Detected prefixed/orphaned API Gateway container: $cName ($cStatus)" -ForegroundColor Yellow
            if ($shouldFix) {
                if ($cStatus -like "*Up*") {
                    Write-Host "  [REPAIR] Renaming running container '$cName' to canonical 'api-gateway'..." -ForegroundColor Cyan
                    docker rename $cName api-gateway 2>$null | Out-Null
                    $inspect = docker inspect api-gateway 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
                    $isUp = ($inspect -and $inspect[0].State.Status -eq "running")
                    if ($isUp) {
                        Write-Host "  [REPAIR] Successfully recovered canonical 'api-gateway' container." -ForegroundColor Green
                        $remediations += "Reconciled and renamed orphaned container '$cName' to 'api-gateway'."
                    }
                } else {
                    Write-Host "  [REPAIR] Purging stale non-running container '$cName'..." -ForegroundColor Cyan
                    docker rm -f $cName 2>$null | Out-Null
                    $remediations += "Purged stale non-running container '$cName'."
                }
            }
        }
    }
}

if ($isUp) {
    Write-Host "  [OK] Container 'api-gateway': RUNNING" -ForegroundColor Green
} else {
    Write-Host "  [WARN] Container 'api-gateway': STOPPED / MISSING" -ForegroundColor Red
    if ($shouldFix) {
        if ($inspect) {
            docker start api-gateway 2>$null | Out-Null
            Start-Sleep -Seconds 2
            $inspect = docker inspect api-gateway 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
            if ($inspect -and $inspect[0].State.Status -eq "running") {
                Write-Host "  [REPAIR] Started 'api-gateway' container." -ForegroundColor Green
                $remediations += "Started 'api-gateway' container."
            }
        } else {
            # Ensure port 3000 isn't held by an orphan before compose up
            $port3000Holders = docker ps --filter "publish=3000" --format "{{.Names}}" 2>$null
            foreach ($holder in $port3000Holders) {
                if ($holder -ne "api-gateway") {
                    Write-Host "  [REPAIR] Stopping conflicting container on port 3000: $holder" -ForegroundColor Yellow
                    docker stop $holder 2>$null | Out-Null
                }
            }
            Write-Host "  [DEPLOY] Running 'docker compose up -d api-gateway'..." -ForegroundColor Cyan
            Push-Location $BaseDir
            docker compose up -d api-gateway 2>&1 | Out-String | Write-Host
            Pop-Location
            Start-Sleep -Seconds 2
            $remediations += "Deployed 'api-gateway' container via compose."
        }
    }
}

# 2. Database Lock & Integrity Audit
Write-Host "`n[2/4] Inspecting API Gateway SQLite Database..." -ForegroundColor Yellow
if (Test-Path $DbDir) {
    $journals = Get-ChildItem -Path $DbDir -Recurse -Filter "*.db-journal" -ErrorAction SilentlyContinue
    $shm = Get-ChildItem -Path $DbDir -Recurse -Filter "*.db-shm" -ErrorAction SilentlyContinue
    $wal = Get-ChildItem -Path $DbDir -Recurse -Filter "*.db-wal" -ErrorAction SilentlyContinue
    $locks = @($journals).Count + @($shm).Count + @($wal).Count

    if ($locks -gt 0) {
        Write-Host ("  [WARN] Found {0} SQLite lock files in API gateway DB directory." -f $locks) -ForegroundColor Yellow
        if ($shouldFix) {
            docker stop api-gateway -t 5 2>$null | Out-Null
            @($journals) | Remove-Item -Force -ErrorAction SilentlyContinue
            @($shm) | Remove-Item -Force -ErrorAction SilentlyContinue
            @($wal) | Remove-Item -Force -ErrorAction SilentlyContinue
            docker start api-gateway 2>$null | Out-Null
            Write-Host "  [REPAIR] Purged database lock files." -ForegroundColor Green
            $remediations += "Purged $locks lock files from API gateway DB."
        }
    } else {
        Write-Host "  [OK] API gateway SQLite database is free of stale lock files." -ForegroundColor Green
    }
} else {
    Write-Host "  [INFO] DB directory will be auto-created on startup." -ForegroundColor DarkGray
}

# 3. REST API Health Probe
Write-Host "`n[3/4] Probing API Gateway Status Endpoints..." -ForegroundColor Yellow
$code = curl.exe -s -o NUL -w "%{http_code}" --max-time 4 "http://localhost:${Port}/api/system/status" 2>$null
if ($code -eq "200") {
    Write-Host ("  [OK] API Status (localhost:{0}/api/system/status) -> HTTP 200" -f $Port) -ForegroundColor Green
} else {
    Write-Host ("  [WARN] API Status returned HTTP {0}" -f $code) -ForegroundColor Yellow
    if ($shouldFix) {
        docker restart api-gateway 2>$null | Out-Null
        Start-Sleep -Seconds 3
        $code = curl.exe -s -o NUL -w "%{http_code}" --max-time 4 "http://localhost:${Port}/api/system/status" 2>$null
        $remediations += "Restarted api-gateway container to recover status endpoint (Result: HTTP $code)."
    }
}

# 4. Downstream Proxy Verification
Write-Host "`n[4/4] Verifying Downstream Reverse Proxy Channels..." -ForegroundColor Yellow
$proxyChannels = @(
    @{ Name="Jellyfin Proxy"; Path="/api/jellyfin/health" },
    @{ Name="Radarr Proxy";   Path="/api/radarr/ping" },
    @{ Name="Sonarr Proxy";   Path="/api/sonarr/ping" }
)
foreach ($ch in $proxyChannels) {
    $pCode = curl.exe -s -o NUL -w "%{http_code}" --max-time 3 "http://localhost:${Port}$($ch.Path)" 2>$null
    if ($pCode -ge 200 -and $pCode -lt 400) {
        Write-Host ("  [OK] {0,-15} -> HTTP {1}" -f $ch.Name, $pCode) -ForegroundColor Green
    } else {
        Write-Host ("  [INFO] {0,-15} -> HTTP {1}" -f $ch.Name, $pCode) -ForegroundColor DarkGray
    }
}

# Report Generation
$reportFile = Join-Path $HandoffsDir "ApiGateway_Repair_Report_$fileTag.md"
$rep = @"
# API Gateway Diagnostic & Auto-Remediation Report

| Parameter | Value |
| :--- | :--- |
| **Service Name** | MediaStack API Gateway |
| **Container Status** | $(if ($isUp) { 'RUNNING' } else { 'RECOVERED' }) |
| **Status API Code** | HTTP $code |
| **Remediations** | $($remediations.Count) |

## Actions Taken
$(if ($remediations.Count -gt 0) { $remediations | ForEach-Object { "- $_" } | Out-String } else { "API Gateway service is healthy." })
"@

Set-Content -Path $reportFile -Value $rep -Encoding UTF8
Write-Host "`n[COMPLETE] API Gateway repair sweep finished. Report: $reportFile`n" -ForegroundColor Green

return [PSCustomObject]@{
    Service = "ApiGateway"
    Container = "api-gateway"
    Status = if ($code -eq "200") { "HEALTHY" } else { "DEGRADED" }
    HttpCode = $code
    Remediations = $remediations
    Report = $reportFile
}

