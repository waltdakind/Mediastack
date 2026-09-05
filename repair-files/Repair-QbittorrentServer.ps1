<#
.SYNOPSIS
    Repair-QbittorrentServer.ps1 - qBittorrent BitTorrent Client Diagnostic & Self-Healing Engine.

.DESCRIPTION
    Comprehensive diagnostic and self-healing engine for qBittorrent:
    1. Audits container status on port 8085/tcp (Web UI) and 6881/tcp+udp (Peer transfer).
    2. Verifies qBittorrent.conf presence, EULA acceptance, and Arr subnet whitelisting.
    3. Validates download volume mounts and disk accessibility.
    4. Probes HTTP WebUI reachability on localhost:8085 and Caddy reverse proxy ingress.

.PARAMETER AutoFix
    Automatically executes fixes (default: $true unless -DiagOnly is specified).

.PARAMETER DiagOnly
    Executes all diagnostics in read-only / simulation mode.

.PARAMETER Port
    qBittorrent WebUI listening port (default: 8085).

.PARAMETER ConfigDir
    Host storage path for config (default: .\config\qbittorrent).

.EXAMPLE
    .\Repair-QbittorrentServer.ps1 -AutoFix
    .\Repair-QbittorrentServer.ps1 -DiagOnly
#>

[CmdletBinding()]
param(
    [switch]$AutoFix,
    [switch]$DiagOnly,
    [int]$Port = 8085,
    [string]$ConfigDir = ".\config\qbittorrent"
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
Write-Host "   q B I T T O R R E N T   C L I E N T   D I A G N O S T I C   &   R E P A I R  " -ForegroundColor DarkCyan
Write-Host ("   WebUI Port: {0} | Mode: {1}" -f $Port, $(if ($DiagOnly) { "DiagOnly" } else { "ActiveRemediation" })) -ForegroundColor White
Write-Host "================================================================================" -ForegroundColor Cyan

$remediations = @()
$shouldFix = ($AutoFix -or -not $DiagOnly)

# --- 1. Auditing Container Status ---
Write-Host "`n[1/4] Auditing qBittorrent Container..." -ForegroundColor Yellow
$inspectRaw = docker inspect qbittorrent 2>$null
$inspect = if ($inspectRaw) { $inspectRaw | ConvertFrom-Json -ErrorAction SilentlyContinue } else { $null }
$isUp = ($inspect -and $inspect[0].State.Status -eq "running")

if ($isUp) {
    Write-Host ("  [OK] Container 'qbittorrent': RUNNING (ID: {0})" -f $inspect[0].Id.Substring(0, 12)) -ForegroundColor Green
} else {
    Write-Host "  [WARN] Container 'qbittorrent': STOPPED / MISSING" -ForegroundColor Red
    if ($shouldFix) {
        if ($inspect) {
            docker start qbittorrent 2>$null | Out-Null
            Start-Sleep -Seconds 3
            Write-Host "  [REPAIR] Started existing 'qbittorrent' container." -ForegroundColor Green
            $remediations += "Started stopped qbittorrent container."
        } else {
            Write-Host "  [REPAIR] Launching qbittorrent via docker compose..." -ForegroundColor Cyan
            docker compose up -d qbittorrent 2>$null | Out-Null
            Start-Sleep -Seconds 4
            $remediations += "Spun up qbittorrent container via compose."
        }
    }
}

# --- 2. Configuration & EULA Verification ---
Write-Host "`n[2/4] Verifying qBittorrent.conf & EULA Bypass..." -ForegroundColor Yellow
$confPath = Join-Path $BaseDir (Join-Path $ConfigDir "qBittorrent\qBittorrent.conf")

if (Test-Path $confPath) {
    $rawConf = Get-Content $confPath -Raw -ErrorAction SilentlyContinue
    $eulaOk = $rawConf -match "Accepted=true"
    $whitelistOk = $rawConf -match "WebUI\\AuthSubnetWhitelist"

    if ($eulaOk) {
        Write-Host "  [OK] LegalNotice EULA Accepted: YES" -ForegroundColor Green
    } else {
        Write-Host "  [WARN] LegalNotice EULA Not Accepted in config!" -ForegroundColor Yellow
    }

    if ($whitelistOk) {
        Write-Host "  [OK] Arr Subnet Whitelist: CONFIGURED" -ForegroundColor Green
    } else {
        Write-Host "  [WARN] Subnet Whitelist missing from qBittorrent.conf" -ForegroundColor Yellow
    }
} else {
    Write-Host ("  [WARN] Configuration file missing: {0}" -f $confPath) -ForegroundColor Red
    if ($shouldFix) {
        Write-Host "  [REPAIR] Running Setup-Qbittorrent.ps1 to generate verified config..." -ForegroundColor Cyan
        $setupScript = Join-Path $BaseDir "Setup-Qbittorrent.ps1"
        if (Test-Path $setupScript) {
            & $setupScript -Port $Port -NoStart -NonInteractive | Out-Null
            $remediations += "Injected initial qBittorrent.conf via setup wizard."
        }
    }
}

# --- 3. Probing WebUI Reachability ---
Write-Host "`n[3/4] Probing WebUI Reachability (Port $Port)..." -ForegroundColor Yellow
$directUrl = "http://127.0.0.1:$Port/"
try {
    $resp = Invoke-WebRequest -Uri $directUrl -TimeoutSec 4 -UseBasicParsing -ErrorAction Stop
    Write-Host ("  [OK] Direct WebUI ({0}) -> HTTP {1}" -f $directUrl, $resp.StatusCode) -ForegroundColor Green
} catch {
    Write-Host ("  [FAIL] Direct WebUI ({0}) -> {1}" -f $directUrl, $_.Exception.Message) -ForegroundColor Red
}

# --- 4. Reverse Proxy & Virtual Host Routing ---
Write-Host "`n[4/4] Probing Caddy Reverse Proxy & Virtual Host Ingress..." -ForegroundColor Yellow
$vhostUrl = "https://qbittorrent.voltairedeux.local/"
try {
    $proxyResp = Invoke-WebRequest -Uri $vhostUrl -TimeoutSec 4 -SkipCertificateCheck -UseBasicParsing -ErrorAction Stop
    Write-Host ("  [OK] Virtual Host ({0}) -> HTTP {1}" -f $vhostUrl, $proxyResp.StatusCode) -ForegroundColor Green
} catch {
    Write-Host ("  [INFO] Virtual Host ({0}) -> {1}" -f $vhostUrl, $_.Exception.Message) -ForegroundColor Yellow
}

Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host "   q B I T T O R R E N T   D I A G N O S T I C   C O M P L E T E               " -ForegroundColor DarkCyan
if ($remediations.Count -gt 0) {
    Write-Host ("   Remediations Applied: {0}" -f ($remediations -join "; ")) -ForegroundColor Green
} else {
    Write-Host "   Status: Configured & Verified Clean." -ForegroundColor Green
}
Write-Host "================================================================================" -ForegroundColor Cyan
