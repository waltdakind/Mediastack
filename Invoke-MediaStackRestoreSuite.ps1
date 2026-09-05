<#
.SYNOPSIS
    Invoke-MediaStackRestoreSuite.ps1 - Master Launcher & Orchestrator for MediaStack Restore & Recovery Suite.

.DESCRIPTION
    Unified master launcher for backup restoration and disaster recovery engines located in restore-files/:
    1. MediaStack Config Restore: Restores Caddyfile, .env, docker-compose.yml, and config hierarchy from backup archives.
    2. Sonarr Database Restore: Recovers Sonarr database from scheduled backups or emergency zip packages.

.PARAMETER Target
    Restore target: "MediaStackConfig", "SonarrBackup", "SonarrZip", "All". Default: "MediaStackConfig".

.PARAMETER FromBackup
    Optional path to a specific backup zip file.

.PARAMETER Force
    Overwrites configuration files with verified templates without interactive confirmation.

.PARAMETER SkipDockerStart
    Restores files only without starting the Docker stack.

.PARAMETER NonInteractive
    Suppresses interactive terminal prompt.

.EXAMPLE
    .\Invoke-MediaStackRestoreSuite.ps1 -Target MediaStackConfig -Force
    .\Invoke-MediaStackRestoreSuite.ps1 -FromBackup .\backups\MediaStack_Backup_Latest.zip
#>

[CmdletBinding(DefaultParameterSetName="Default")]
param(
    [Parameter(ParameterSetName="Target")]
    [ValidateSet("MediaStackConfig", "SonarrBackup", "SonarrZip", "All")]
    [string]$Target,

    [string]$FromBackup = "",
    [switch]$Force,
    [switch]$SkipDockerStart,
    [switch]$NonInteractive
)

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::InputEncoding  = [System.Text.Encoding]::UTF8

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$fileTag = Get-Date -Format "yyyyMMdd_HHmmss"
$BaseDir = $PSScriptRoot
$ResDir = Join-Path $BaseDir "restore-files"
$HandoffsDir = Join-Path $BaseDir "handoffs"

if (-not (Test-Path $HandoffsDir)) { New-Item -ItemType Directory -Force -Path $HandoffsDir | Out-Null }

# Interactive Menu
if (-not $Target -and -not $FromBackup -and -not $NonInteractive) {
    Clear-Host
    Write-Host "`n================================================================================" -ForegroundColor DarkCyan
    Write-Host "   M E D I A S T A C K   R E S T O R E   &   R E C O V E R Y   S U I T E" -ForegroundColor Cyan
    Write-Host "   Master Launcher for Disaster Recovery, Configuration & DB Restoration" -ForegroundColor DarkGray
    Write-Host "================================================================================" -ForegroundColor DarkCyan
    Write-Host "   Subdirectory: restore-files/ | Timestamp: $timestamp" -ForegroundColor White
    Write-Host "--------------------------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "   [1] Restore Full MediaStack Configuration (Latest Backup / Golden Template)" -ForegroundColor Green
    Write-Host "   [2] Restore Sonarr Database from Scheduled Backup" -ForegroundColor Yellow
    Write-Host "   [3] Restore Sonarr Database from Emergency Zip Package" -ForegroundColor Yellow
    Write-Host "   [0] Exit" -ForegroundColor DarkGray
    Write-Host "--------------------------------------------------------------------------------" -ForegroundColor DarkGray
    $choice = Read-Host "   Enter selection [1-3, 0]"

    switch ($choice) {
        "1" { $Target = "MediaStackConfig" }
        "2" { $Target = "SonarrBackup" }
        "3" { $Target = "SonarrZip" }
        default {
            Write-Host "`nExiting Restore Suite.`n" -ForegroundColor DarkGray
            return
        }
    }
}

if (-not $Target) { $Target = "MediaStackConfig" }

Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host "   E X E C U T I N G   R E S T O R E   S U I T E" -ForegroundColor DarkCyan
Write-Host ("   Target: {0} | Force: {1} | SkipDockerStart: {2}" -f $Target, $Force, $SkipDockerStart) -ForegroundColor White
Write-Host "================================================================================" -ForegroundColor Cyan

$sw = [System.Diagnostics.Stopwatch]::StartNew()
$status = "SUCCESS"

try {
    switch ($Target) {
        "MediaStackConfig" {
            $script = Join-Path $ResDir "Restore-MediaStackConfig.ps1"
            $params = @{}
            if ($FromBackup) { $params["FromBackup"] = $FromBackup }
            if ($Force) { $params["Force"] = $true }
            if ($SkipDockerStart) { $params["SkipDockerStart"] = $true }
            & $script @params
        }
        "SonarrBackup" {
            $script = Join-Path $ResDir "Restore-SonarrFromBackup.ps1"
            & $script
        }
        "SonarrZip" {
            $script = Join-Path $ResDir "Restore-SonarrFromZip.ps1"
            & $script
        }
    }
    $sw.Stop()
} catch {
    $sw.Stop()
    $status = "ERROR"
    Write-Host ("  [FAIL] Restore operation failed: $_") -ForegroundColor Red
}

# Generate Consolidated Report
$reportFile = Join-Path $HandoffsDir "MediaStack_Restore_Suite_Report_$fileTag.md"
$rep = @"
# MediaStack Restore Suite Execution Report

| Parameter | Value |
| :--- | :--- |
| **Execution Host** | $($env:COMPUTERNAME) |
| **Restore Target** | $Target |
| **Status** | $status |
| **Elapsed** | $("0:N1" -f $sw.Elapsed.TotalSeconds)s |
| **Timestamp** | $timestamp |
| **Subdirectory** | \restore-files |

---
*Generated by Invoke-MediaStackRestoreSuite.ps1.*
"@

Set-Content -Path $reportFile -Value $rep -Encoding UTF8
Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host ("   [COMPLETE] Restore Suite Finished. Report: {0}" -f $reportFile) -ForegroundColor Green
Write-Host "================================================================================`n" -ForegroundColor Cyan
