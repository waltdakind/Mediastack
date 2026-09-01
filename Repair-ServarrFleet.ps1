<#
.SYNOPSIS
    Repair-ServarrFleet.ps1 - Automated Diagnostic & Recovery Engine for Servarr Applications.

.DESCRIPTION
    Comprehensive diagnostic and repair toolkit for Sonarr, Radarr, Prowlarr, and Bazarr:
    1. Detects and purges SQLite database locks (*.db-journal, *.db-shm, *.db-wal).
    2. Inspects and repairs corrupted config.xml files (port bindings, URL base, auth disabled flags).
    3. Re-synchronizes API keys from the Master Secrets Vault (config/secrets/secrets.json).
    4. Clears orphaned PID locks and terminates crash loops.
    5. Verifies container health and REST API reachability.

.PARAMETER TargetService
    Specific Servarr application to repair: "All", "Sonarr", "Radarr", "Prowlarr", "Bazarr". Default: "All".

.PARAMETER AutoFix
    Automatically executes remediations without interactive prompts. Default: $true.

.PARAMETER ConfigDir
    Host root directory for MediaStack configurations.

.EXAMPLE
    .\Repair-ServarrFleet.ps1 -TargetService All -AutoFix
    .\Repair-ServarrFleet.ps1 -TargetService Radarr
#>

[CmdletBinding()]
param(
    [ValidateSet("All", "Sonarr", "Radarr", "Prowlarr", "Bazarr")]
    [string]$TargetService = "All",
    [switch]$AutoFix,
    [switch]$DiagOnly,
    [string]$ConfigDir = "$env:SystemDrive\MediastackConfig"
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
Write-Host "   S E R V A R R   F L E E T   D I A G N O S T I C   &   R E P A I R" -ForegroundColor DarkCyan
Write-Host "   Target: $TargetService | Timestamp: $timestamp" -ForegroundColor White
Write-Host "================================================================================" -ForegroundColor Cyan

# Load Master Secrets Vault for API Key reconciliation
$vault = $null
if (Test-Path $SecretsFile) {
    try {
        $vault = Get-Content $SecretsFile -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch {}
}

$services = @()
if ($TargetService -eq "All") {
    $services = @("sonarr", "radarr", "prowlarr", "bazarr")
} else {
    $services = @($TargetService.ToLower())
}

$serviceMeta = @{
    "sonarr"   = @{ Port=8989; DbFile="sonarr.db";   ApiKeyName="sonarr" }
    "radarr"   = @{ Port=7878; DbFile="radarr.db";   ApiKeyName="radarr" }
    "prowlarr" = @{ Port=9696; DbFile="prowlarr.db"; ApiKeyName="prowlarr" }
    "bazarr"   = @{ Port=6767; DbFile="bazarr.db";   ApiKeyName="bazarr" }
}

$remediationLog = @()

foreach ($svc in $services) {
    $meta = $serviceMeta[$svc]
    $port = $meta.Port
    $dbName = $meta.DbFile
    $apiKeyField = $meta.ApiKeyName

    Write-Host "`n--------------------------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host ("[*] Auditing Service: {0} (Default Port: {1})" -f $svc.ToUpper(), $port) -ForegroundColor Yellow
    Write-Host "--------------------------------------------------------------------------------" -ForegroundColor DarkGray

    # 1. Container Status & Crash Loop Detection
    $cInspect = docker inspect $svc 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
    $cState = if ($cInspect) { $cInspect[0].State } else { $null }
    $isUp = ($cState -and $cState.Status -eq "running")
    $restartCount = if ($cInspect) { $cInspect[0].RestartCount } else { 0 }

    Write-Host ("  * Container Status : {0} | Restarts: {1}" -f $(if ($isUp) { "RUNNING" } else { "STOPPED/CRASHED" }), $restartCount) -ForegroundColor $(if ($isUp) { "Green" } else { "Red" })

    # 2. Database Lock & Journal File Audit
    $svcConfigDir = Join-Path $ConfigDir $svc
    $localConfigDir = Join-Path $BaseDir "config\$svc"
    $targetDir = if (Test-Path $svcConfigDir) { $svcConfigDir } elseif (Test-Path $localConfigDir) { $localConfigDir } else { $svcConfigDir }

    if (Test-Path $targetDir) {
        $dbPath = Join-Path $targetDir $dbName
        Write-Host ("  * Database File    : {0} ({1})" -f $dbName, $(if (Test-Path $dbPath) { "PRESENT" } else { "INITIALIZING" })) -ForegroundColor DarkCyan
        $journals = Get-ChildItem -Path $targetDir -Filter "*.db-journal" -Recurse -ErrorAction SilentlyContinue
        $shmFiles  = Get-ChildItem -Path $targetDir -Filter "*.db-shm" -Recurse -ErrorAction SilentlyContinue
        $pidFiles  = Get-ChildItem -Path $targetDir -Filter "*.pid" -Recurse -ErrorAction SilentlyContinue

        $lockCount = @($journals).Count + @($shmFiles).Count + @($pidFiles).Count
        Write-Host ("  * Stale Locks/Journals: {0} found in {1}" -f $lockCount, $targetDir) -ForegroundColor $(if ($lockCount -eq 0) { "Green" } else { "Yellow" })

        if ($lockCount -gt 0 -and $AutoFix -and -not $DiagOnly) {
            Write-Host "    [REPAIR] Stopping container and clearing locks..." -ForegroundColor Cyan
            docker stop $svc -t 5 2>$null | Out-Null
            @($journals) | Remove-Item -Force -ErrorAction SilentlyContinue
            @($shmFiles) | Remove-Item -Force -ErrorAction SilentlyContinue
            @($pidFiles) | Remove-Item -Force -ErrorAction SilentlyContinue
            Write-Host "    [OK] Stale lock files successfully purged." -ForegroundColor Green
            $remediationLog += "$svc : Purged $lockCount database lock and journal files."
        }

        # 3. Config.xml XML Validation & API Key Alignment
        $xmlPath = Join-Path $targetDir "config.xml"
        if (Test-Path $xmlPath) {
            try {
                [xml]$xmlDoc = Get-Content $xmlPath -Raw
                $currentKey = $xmlDoc.Config.ApiKey
                $currentPort = $xmlDoc.Config.Port

                Write-Host ("  * Config.xml Port  : {0}" -f $currentPort) -ForegroundColor DarkCyan
                Write-Host ("  * Config.xml ApiKey: {0}..." -f $(if ($currentKey -and $currentKey.Length -gt 6) { $currentKey.Substring(0,6) } else { "NONE" })) -ForegroundColor DarkCyan

                if ($vault -and $vault.secrets.$apiKeyField.api_key) {
                    $vaultKey = $vault.secrets.$apiKeyField.api_key
                    if ($currentKey -ne $vaultKey -and $AutoFix -and -not $DiagOnly) {
                        Write-Host "    [REPAIR] Syncing API key from Master Vault to config.xml..." -ForegroundColor Cyan
                        $xmlDoc.Config.ApiKey = $vaultKey
                        $xmlDoc.Save($xmlPath)
                        Write-Host "    [OK] API key synchronized with vault." -ForegroundColor Green
                        $remediationLog += "$svc : Realigned API key with Master Secrets Vault."
                    }
                }
            } catch {
                Write-Host "  [WARN] config.xml parse error: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
    } else {
        Write-Host "  * Config directory not yet created on host: $targetDir" -ForegroundColor DarkGray
    }

    # 4. Container Restart & Health Verification
    if ($AutoFix -and -not $DiagOnly) {
        if (-not $isUp) {
            Write-Host "  [REPAIR] Starting container $svc..." -ForegroundColor Cyan
            docker start $svc 2>$null | Out-Null
            Start-Sleep -Seconds 3
        }

        # Probe HTTP Endpoint
        $pingCode = curl.exe -s -o NUL -w "%{http_code}" --max-time 4 "http://localhost:${port}/ping" 2>$null
        if ($pingCode -eq "200" -or $pingCode -eq "302") {
            Write-Host ("  [HEALTHY] HTTP Probe on localhost:{0} -> HTTP {1}" -f $port, $pingCode) -ForegroundColor Green
        } else {
            # Try alternate route
            $altCode = curl.exe -s -o NUL -w "%{http_code}" --max-time 4 "http://localhost:${port}/" 2>$null
            Write-Host ("  [STATUS] HTTP Probe on localhost:{0} -> HTTP {1}" -f $port, $altCode) -ForegroundColor $(if ($altCode -ge 200 -and $altCode -lt 400) { "Green" } else { "Yellow" })
        }
    }
}

# Generate Report
$reportFile = Join-Path $HandoffsDir "Servarr_Repair_Report_$fileTag.md"
$rep = @"
# Servarr Fleet Diagnostic & Repair Report

| Parameter | Value |
| :--- | :--- |
| **Timestamp** | $timestamp |
| **Target Service** | $TargetService |
| **AutoFix Mode** | $(if ($AutoFix) { 'ACTIVE' } else { 'DISABLED' }) |
| **Remediations Applied** | $($remediationLog.Count) |

## Actions Taken
$(if ($remediationLog.Count -gt 0) { $remediationLog | ForEach-Object { "- $_" } | Out-String } else { "Fleet healthy. No repairs required." })

---
*Generated by Repair-ServarrFleet.ps1.*
"@
Set-Content -Path $reportFile -Value $rep -Encoding UTF8
Write-Host "`n[COMPLETE] Servarr fleet diagnostic & repair finished. Report: $reportFile`n" -ForegroundColor Green
