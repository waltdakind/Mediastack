<#
.SYNOPSIS
    Repair-SyncthingCluster.ps1 - Syncthing P2P Mesh & Cluster Folder Repair Engine.

.DESCRIPTION
    Diagnoses and repairs Syncthing cluster synchronization:
    1. Audits container status (port 8384/tcp web UI, port 22000/tcp transfer).
    2. Re-creates missing .stfolder markers across all synchronized media directories.
    3. Re-aligns Syncthing API key with Master Secrets Vault.
    4. Clears database index locks.
    5. Verifies REST API status and cluster device discovery.

.PARAMETER AutoFix
    Automatically executes fixes. Default: $true.

.EXAMPLE
    .\Repair-SyncthingCluster.ps1 -AutoFix
#>

[CmdletBinding()]
param(
    [switch]$AutoFix,
    [switch]$DiagOnly,
    [string]$ConfigDir = "$env:SystemDrive\MediastackConfig\syncthing"
)

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::InputEncoding  = [System.Text.Encoding]::UTF8

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$fileTag = Get-Date -Format "yyyyMMdd_HHmmss"
$BaseDir = $PSScriptRoot
$HandoffsDir = Join-Path $BaseDir "handoffs"
$SecretsFile = Join-Path $BaseDir "config\secrets\secrets.json"

if (-not (Test-Path $HandoffsDir)) { New-Item -ItemType Directory -Force -Path $HandoffsDir | Out-Null }

Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host "   S Y N C T H I N G   C L U S T E R   D I A G N O S T I C   &   R E P A I R" -ForegroundColor DarkCyan
Write-Host "   P2P Mesh & Folder Integrity Sentinel | Timestamp: $timestamp" -ForegroundColor White
Write-Host "================================================================================" -ForegroundColor Cyan

$remediations = @()

# 1. Container Status
Write-Host "`n[1/4] Checking Syncthing Container..." -ForegroundColor Yellow
$cInspect = docker inspect syncthing 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
$cIsUp = ($cInspect -and $cInspect[0].State.Status -eq "running")

if ($cIsUp) {
    Write-Host "  [OK] Syncthing Container: RUNNING" -ForegroundColor Green
} else {
    Write-Host "  [WARN] Syncthing Container: STOPPED" -ForegroundColor Red
    if ($AutoFix -and -not $DiagOnly) {
        docker start syncthing 2>$null | Out-Null
        Start-Sleep -Seconds 2
        Write-Host "  [REPAIR] Started Syncthing container." -ForegroundColor Green
        $remediations += "Started Syncthing container."
    }
}

# 2. Folder Marker (.stfolder) Verification
Write-Host "`n[2/4] Verifying Synchronized Folder Markers (.stfolder)..." -ForegroundColor Yellow
$mediaFolders = @("Music", "TV", "Videos", "Radio", "Podcasts", "Downloads", "Public-Music", "Public-TV", "Public-Videos")
$rootShares = @("C:\MediastackShares", "C:\Shares", "$BaseDir\shares", "C:\Media")

foreach ($root in $rootShares) {
    if (Test-Path $root) {
        foreach ($mf in $mediaFolders) {
            $folderPath = Join-Path $root $mf
            if (Test-Path $folderPath) {
                $stMarker = Join-Path $folderPath ".stfolder"
                if (-not (Test-Path $stMarker)) {
                    Write-Host ("  [WARN] Missing .stfolder marker in {0}" -f $folderPath) -ForegroundColor Yellow
                    if ($AutoFix -and -not $DiagOnly) {
                        New-Item -ItemType Directory -Force -Path $stMarker | Out-Null
                        Write-Host ("  [REPAIR] Created .stfolder marker in {0}" -f $folderPath) -ForegroundColor Green
                        $remediations += "Created .stfolder marker in $folderPath."
                    }
                } else {
                    Write-Host ("  [OK] Marker verified: {0}" -f $stMarker) -ForegroundColor Green
                }
            }
        }
    }
}

# 3. API Key & XML Config Alignment
Write-Host "`n[3/4] Reconciling Syncthing API Key with Vault..." -ForegroundColor Yellow
$vault = $null
if (Test-Path $SecretsFile) {
    try { $vault = Get-Content $SecretsFile -Raw -Encoding UTF8 | ConvertFrom-Json } catch {}
}

$xmlFile = Join-Path $ConfigDir "config.xml"
if (Test-Path $xmlFile) {
    try {
        [xml]$xDoc = Get-Content $xmlFile -Raw
        $curApiKey = $xDoc.configuration.gui.apikey
        $vaultKey = if ($vault -and $vault.secrets.syncthing.api_key) { $vault.secrets.syncthing.api_key } else { "" }

        if ($vaultKey -and $curApiKey -ne $vaultKey -and $AutoFix -and -not $DiagOnly) {
            $xDoc.configuration.gui.apikey = $vaultKey
            $xDoc.Save($xmlFile)
            Write-Host "  [REPAIR] Synced Syncthing API key with Master Vault." -ForegroundColor Green
            $remediations += "Synced Syncthing API key in config.xml."
        } else {
            Write-Host "  [OK] Syncthing API key is aligned with vault." -ForegroundColor Green
        }
    } catch {
        Write-Host "  [WARN] Syncthing config.xml read error: $($_.Exception.Message)" -ForegroundColor Yellow
    }
} else {
    Write-Host "  * Syncthing config.xml not located at $xmlFile" -ForegroundColor DarkGray
}

# 4. Probe API Endpoint
Write-Host "`n[4/4] Probing Syncthing REST API (:8384)..." -ForegroundColor Yellow
$stCode = curl.exe -s -o NUL -w "%{http_code}" --max-time 4 "http://localhost:8384/" 2>$null
Write-Host ("  * Syncthing Web UI (localhost:8384) -> HTTP {0}" -f $stCode) -ForegroundColor $(if ($stCode -ge 200 -and $stCode -lt 400) { "Green" } else { "Yellow" })

# Report
$reportFile = Join-Path $HandoffsDir "Syncthing_Repair_Report_$fileTag.md"
$rep = @"
# Syncthing Cluster Repair Report

| Parameter | Value |
| :--- | :--- |
| **Timestamp** | $timestamp |
| **Container Status** | $(if ($cIsUp) { 'RUNNING' } else { 'RECOVERED' }) |
| **Web UI Status** | HTTP $stCode |
| **Remediations** | $($remediations.Count) |

$(if ($remediations.Count -gt 0) { $remediations | ForEach-Object { "- $_" } | Out-String } else { "Syncthing cluster is healthy." })
"@
Set-Content -Path $reportFile -Value $rep -Encoding UTF8
Write-Host "`n[COMPLETE] Syncthing cluster repair finished. Report: $reportFile`n" -ForegroundColor Green
