<#
.SYNOPSIS
    Invoke-MediaStackReplicationSuite.ps1 - Master Launcher & Orchestrator for MediaStack Replication Suite.

.DESCRIPTION
    Unified master launcher for cluster replication and synchronization engines located in replicate-files/:
    1. Cluster Multi-Service Replication: MusicBrainz, Syncthing, Servarr, SQLite Databases, SMB Shares.
    2. Node Replication: Deploys complete MediaStack environment onto secondary/satellite nodes.
    3. Architecture Improvements Sync: Propagates x64 improvements to ARM/edge satellites.

.PARAMETER Scope
    Target replication scope: "All", "MusicBrainz", "Syncthing", "Servarr", "Databases", "Shares", "NodeProvision". Default: "All".

.PARAMETER TargetNode
    Peer node name (default: "VoltaireUn").

.PARAMETER TargetIp
    Peer node IP address (default: "192.168.4.21").

.PARAMETER RunOnce
    Runs a single sync pass and exits.

.PARAMETER All
    Executes full multi-service cluster replication sweep.

.PARAMETER NonInteractive
    Suppresses interactive terminal prompt.

.EXAMPLE
    .\Invoke-MediaStackReplicationSuite.ps1 -All -RunOnce
    .\Invoke-MediaStackReplicationSuite.ps1 -Scope MusicBrainz
#>

[CmdletBinding(DefaultParameterSetName="Default")]
param(
    [Parameter(ParameterSetName="Scope")]
    [ValidateSet("All", "MusicBrainz", "Syncthing", "Servarr", "Databases", "Shares", "NodeProvision")]
    [string]$Scope,

    [Parameter(ParameterSetName="All")]
    [switch]$All,

    [string]$TargetNode = "VoltaireUn",
    [string]$TargetIp = "192.168.4.21",
    [switch]$RunOnce,
    [switch]$NonInteractive
)

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::InputEncoding  = [System.Text.Encoding]::UTF8

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$fileTag = Get-Date -Format "yyyyMMdd_HHmmss"
$BaseDir = $PSScriptRoot
$RepDir = Join-Path $BaseDir "replicate-files"
$HandoffsDir = Join-Path $BaseDir "handoffs"

if (-not (Test-Path $HandoffsDir)) { New-Item -ItemType Directory -Force -Path $HandoffsDir | Out-Null }


# Interactive Menu
if (-not $All -and -not $Scope -and -not $NonInteractive) {
    Clear-Host
    Write-Host "`n================================================================================" -ForegroundColor DarkCyan
    Write-Host "   M E D I A S T A C K   R E P L I C A T I O N   S U I T E" -ForegroundColor Cyan
    Write-Host "   Master Launcher for Cluster State, Node Provisioning & Database Sync" -ForegroundColor DarkGray
    Write-Host "================================================================================" -ForegroundColor DarkCyan
    Write-Host ("   Peer Node: {0} ({1}) | Subdirectory: replicate-files/" -f $TargetNode, $TargetIp) -ForegroundColor White
    Write-Host "--------------------------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "   [1] Full Multi-Service Cluster Sync (All Layers)" -ForegroundColor Green
    Write-Host "   [2] MusicBrainz Hourly PostgreSQL Change Stream" -ForegroundColor Yellow
    Write-Host "   [3] Syncthing P2P Mesh Folder Replication" -ForegroundColor Yellow
    Write-Host "   [4] Servarr Indexers & Config Sync" -ForegroundColor Yellow
    Write-Host "   [5] SQLite Hot Database Snapshot Sync" -ForegroundColor Yellow
    Write-Host "   [6] SMB Share Reciprocal Permissions & Validation" -ForegroundColor Yellow
    Write-Host "   [7] Replicate MediaStack Architecture to New Node" -ForegroundColor Cyan
    Write-Host "   [0] Exit" -ForegroundColor DarkGray
    Write-Host "--------------------------------------------------------------------------------" -ForegroundColor DarkGray
    $choice = Read-Host "   Enter selection [1-7, 0]"

    switch ($choice) {
        "1" { $All = $true }
        "2" { $Scope = "MusicBrainz" }
        "3" { $Scope = "Syncthing" }
        "4" { $Scope = "Servarr" }
        "5" { $Scope = "Databases" }
        "6" { $Scope = "Shares" }
        "7" { $Scope = "NodeProvision" }
        default {
            Write-Host "`nExiting Replication Suite.`n" -ForegroundColor DarkGray
            return
        }
    }
}

if ($All) { $Scope = "All" }
if (-not $Scope) { $Scope = "All" }

Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host "   E X E C U T I N G   R E P L I C A T I O N   S U I T E" -ForegroundColor DarkCyan
Write-Host ("   Scope: {0} | Target Node: {1} ({2})" -f $Scope, $TargetNode, $TargetIp) -ForegroundColor White
Write-Host "================================================================================" -ForegroundColor Cyan

$results = @()
$sw = [System.Diagnostics.Stopwatch]::StartNew()

try {
    if ($Scope -eq "NodeProvision") {
        $scriptPath = Join-Path $RepDir "Replicate-MediaStackNode.ps1"
        & $scriptPath -TargetNodeName $TargetNode -PrimaryNodeIp $TargetIp
    } else {
        $scriptPath = Join-Path $RepDir "Replicate-MediaStackCluster.ps1"
        $params = @{
            Service    = $Scope
            TargetNode = $TargetNode
            TargetIp   = $TargetIp
        }
        if ($RunOnce -or $All) { $params["RunOnce"] = $true }
        & $scriptPath @params
    }
    $sw.Stop()

    $results += [PSCustomObject]@{
        Scope   = $Scope
        Target  = "$TargetNode ($TargetIp)"
        Status  = "SUCCESS"
        Elapsed = ("{0:N1}s" -f $sw.Elapsed.TotalSeconds)
    }
} catch {
    $sw.Stop()
    Write-Host ("  [FAIL] Replication error: $_") -ForegroundColor Red
    $results += [PSCustomObject]@{
        Scope   = $Scope
        Target  = "$TargetNode ($TargetIp)"
        Status  = "ERROR"
        Elapsed = ("{0:N1}s" -f $sw.Elapsed.TotalSeconds)
    }
}

# Generate Consolidated Report
$reportFile = Join-Path $HandoffsDir "MediaStack_Replication_Suite_Report_$fileTag.md"
$rep = @"
# MediaStack Replication Suite Execution Report

| Parameter | Value |
| :--- | :--- |
| **Execution Host** | $($env:COMPUTERNAME) |
| **Replication Scope** | $Scope |
| **Peer Node** | $TargetNode ($TargetIp) |
| **Timestamp** | $timestamp |
| **Subdirectory** | \replicate-files |

## Execution Summary
$($results | ForEach-Object { "- **Scope:** $($_.Scope) | **Status:** $($_.Status) | **Elapsed:** $($_.Elapsed)" } | Out-String)

---
*Generated by Invoke-MediaStackReplicationSuite.ps1.*
"@

Set-Content -Path $reportFile -Value $rep -Encoding UTF8
Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host ("   [COMPLETE] Replication Suite Finished. Report: {0}" -f $reportFile) -ForegroundColor Green
Write-Host "================================================================================`n" -ForegroundColor Cyan
