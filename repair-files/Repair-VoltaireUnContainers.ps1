<#
.SYNOPSIS
    Repair-VoltaireUnContainers.ps1 - Automated Container Prefix & Orphan Reconciler for VoltaireUn.

.DESCRIPTION
    Scans for and resolves Docker Desktop / Compose orphaned container naming collisions:
    1. Removes blocking "created" but inactive containers (e.g. musicbrainz search, db, valkey, seerr).
    2. Renames hash-prefixed running containers back to their canonical fleet names:
       - b99f16a6f279_api-gateway -> api-gateway
       - e78cf9f352e4_musicbrainz-docker-search-1 -> musicbrainz-docker-search-1
       - 8aa0c3ee97cd_musicbrainz-docker-db-1 -> musicbrainz-docker-db-1
       - 983c4f45ea36_musicbrainz-docker-valkey-2 -> musicbrainz-docker-valkey-2
    3. Verifies canonical container names and inspect health.
    4. Probes API Gateway on localhost:3000.

.EXAMPLE
    .\Repair-VoltaireUnContainers.ps1
#>

[CmdletBinding()]
param(
    [switch]$Force
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
Write-Host "   V O L T A I R E U N   C O N T A I N E R   R E C O N C I L I E R" -ForegroundColor DarkCyan
Write-Host ("   Timestamp: {0} | BaseDir: {1}" -f $timestamp, $BaseDir) -ForegroundColor White
Write-Host "================================================================================" -ForegroundColor Cyan

$remediations = @()

# 1. Audit all containers
Write-Host "`n[1/4] Auditing Local Docker Container Topology..." -ForegroundColor Yellow
$allContainers = docker ps -a --format "{{.ID}}|{{.Names}}|{{.State}}|{{.Status}}" 2>$null

# Target pairs: Prefixed/Orphaned running container -> Canonical target name
$canonicalMap = @{
    "api-gateway"                      = @{ Pattern = "*api-gateway*";                 Expected = "api-gateway" }
    "musicbrainz-docker-search-1"     = @{ Pattern = "*musicbrainz-docker-search-1*"; Expected = "musicbrainz-docker-search-1" }
    "musicbrainz-docker-db-1"         = @{ Pattern = "*musicbrainz-docker-db-1*";     Expected = "musicbrainz-docker-db-1" }
    "musicbrainz-docker-valkey-2"     = @{ Pattern = "*musicbrainz-docker-valkey-2*"; Expected = "musicbrainz-docker-valkey-2" }
}

# Stale created containers that block canonical names
$staleCreated = @("musicbrainz-docker-search-1", "musicbrainz-docker-db-1", "musicbrainz-docker-valkey-2", "seerr")

Write-Host "`n[2/4] Purging Stale Blocked Containers in 'Created' State..." -ForegroundColor Yellow
foreach ($staleName in $staleCreated) {
    $inspect = docker inspect $staleName 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
    if ($inspect -and $inspect[0].State.Status -eq "created") {
        Write-Host "  [REMOVE] Removing stale non-running container: $staleName" -ForegroundColor Cyan
        docker rm -f $staleName 2>$null | Out-Null
        $remediations += "Removed stale created container '$staleName'."
    }
}

Write-Host "`n[3/4] Reconciling Hash-Prefixed Containers to Canonical Names..." -ForegroundColor Yellow
foreach ($target in $canonicalMap.Keys) {
    $expectedName = $canonicalMap[$target].Expected
    $pattern = $canonicalMap[$target].Pattern

    # Check if canonical name is already running
    $canonicalInspect = docker inspect $expectedName 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
    if ($canonicalInspect -and $canonicalInspect[0].State.Status -eq "running") {
        Write-Host "  [OK] Canonical container '$expectedName' is already running." -ForegroundColor Green
        continue
    }

    # Find matching prefixed containers
    $candidates = docker ps -a --filter "name=$pattern" --format "{{.Names}}|{{.State}}|{{.Status}}" 2>$null
    $renamed = $false
    foreach ($cand in $candidates) {
        $parts = $cand.Split("|")
        $cName = $parts[0]
        $cState = if ($parts.Length -gt 1) { $parts[1] } else { "" }
        $cStatus = if ($parts.Length -gt 2) { $parts[2] } else { "" }

        if ($cName -ne $expectedName) {
            Write-Host "  [DETECTED] Prefixed container '$cName' (State: $cState, Status: $cStatus)" -ForegroundColor Yellow
            if ($cState -eq "running") {
                Write-Host "  [REPAIR] Renaming '$cName' -> '$expectedName'..." -ForegroundColor Cyan
                docker rename $cName $expectedName 2>&1 | Write-Host
                $verify = docker inspect $expectedName 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
                if ($verify -and $verify[0].State.Status -eq "running") {
                    Write-Host "  [SUCCESS] Container '$expectedName' is now active under canonical name!" -ForegroundColor Green
                    $remediations += "Renamed '$cName' to canonical '$expectedName'."
                    $renamed = $true
                    break
                }
            } else {
                Write-Host "  [CLEANUP] Removing dead prefixed container: $cName" -ForegroundColor DarkGray
                docker rm -f $cName 2>$null | Out-Null
            }
        }
    }

    if (-not $renamed -and (-not $canonicalInspect -or $canonicalInspect[0].State.Status -ne "running")) {
        Write-Host "  [DEPLOY] Canonical container '$expectedName' not running. Attempting compose up..." -ForegroundColor Yellow
        Push-Location $BaseDir
        docker compose up -d $expectedName 2>&1 | Write-Host
        Pop-Location
        $remediations += "Deployed '$expectedName' via compose."
    }
}

# 4. Verification Probe
Write-Host "`n[4/4] Probing API Gateway and Canonical Services..." -ForegroundColor Yellow
$apiCode = curl.exe -s -o NUL -w "%{http_code}" --max-time 3 "http://localhost:3000/api/system/status" 2>$null
if ($apiCode -eq "200") {
    Write-Host "  [OK] Local API Gateway (http://localhost:3000/api/system/status) -> HTTP 200" -ForegroundColor Green
} else {
    Write-Host ("  [WARN] Local API Gateway probe returned HTTP {0}" -f $apiCode) -ForegroundColor Yellow
}

# Summary Report
$reportFile = Join-Path $HandoffsDir "VoltaireUn_Container_Reconciliation_$fileTag.md"
$rep = @"
# VoltaireUn Container Reconciliation & Parity Report

| Parameter | Value |
| :--- | :--- |
| **Node Target** | VoltaireUn / VoltaireDeux |
| **Execution Timestamp** | $timestamp |
| **API Gateway HTTP** | HTTP $apiCode |
| **Remediations Executed** | $($remediations.Count) |

## Actions Executed
$(if ($remediations.Count -gt 0) { $remediations | ForEach-Object { "- $_" } | Out-String } else { "All containers were already canonical and healthy." })
"@

Set-Content -Path $reportFile -Value $rep -Encoding UTF8
Write-Host "`n[COMPLETE] Reconciliation sweep finished. Report: $reportFile`n" -ForegroundColor Green
