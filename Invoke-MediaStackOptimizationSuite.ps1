<#
.SYNOPSIS
    Invoke-MediaStackOptimizationSuite.ps1 - Master Orchestrator & Launcher for MediaStack Optimization Suite.

.DESCRIPTION
    Unified master launcher for all MediaStack performance, database, caching, and streaming
    optimization engines located in the optimize-files/ subdirectory:
    1. Master Performance Accelerator (Caddy edge compression, keep-alives, RAM metadata caching, TCP stack tuning)
    2. SQLite Database Accelerator (WAL mode, memory page caching, MMAP, PRAGMA optimize)
    3. Dual-Node LCP Optimization (Cross-node asset distribution between VoltaireUn and VoltaireDeux)
    4. Local LCP Optimization (Dashboard & web client Largest Contentful Paint accelerator)
    5. Live TV & Stream Latency Tuning (HLS streaming buffers, HDHomeRun / Tvheadend sockets)

.PARAMETER Target
    Optimization target to run: "All", "Performance", "Database", "DualNodeLcp", "LocalLcp", "LiveTv". Default: "All".

.PARAMETER BenchmarkOnly
    Executes latency and response time benchmark without applying mutations.

.PARAMETER All
    Executes full multi-pillar optimization sweep.

.PARAMETER NonInteractive
    Suppresses interactive terminal prompt.

.EXAMPLE
    .\Invoke-MediaStackOptimizationSuite.ps1 -All
    .\Invoke-MediaStackOptimizationSuite.ps1 -Target Database
    .\Invoke-MediaStackOptimizationSuite.ps1 -BenchmarkOnly
#>

[CmdletBinding(DefaultParameterSetName="Default")]
param(
    [Parameter(ParameterSetName="Target")]
    [ValidateSet("All", "Performance", "Database", "DualNodeLcp", "LocalLcp", "LiveTv")]
    [string]$Target,

    [Parameter(ParameterSetName="All")]
    [switch]$All,

    [switch]$BenchmarkOnly,
    [switch]$NonInteractive
)

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::InputEncoding  = [System.Text.Encoding]::UTF8

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$fileTag = Get-Date -Format "yyyyMMdd_HHmmss"
$BaseDir = $PSScriptRoot
$OptDir = Join-Path $BaseDir "optimize-files"
$HandoffsDir = Join-Path $BaseDir "handoffs"

if (-not (Test-Path $HandoffsDir)) { New-Item -ItemType Directory -Force -Path $HandoffsDir | Out-Null }

$OptCatalog = [ordered]@{
    "Performance" = @{ Script="Optimize-MediaStackPerformance.ps1"; Name="Master Performance & Caddy Edge Tuning"; Key="1" }
    "Database"    = @{ Script="Optimize-MediaStackDatabase.ps1";   Name="SQLite PRAGMA, WAL & Cache Tuning";      Key="2" }
    "DualNodeLcp" = @{ Script="Optimize-DualNodeLcp.ps1";          Name="Dual-Node Cluster LCP Acceleration";     Key="3" }
    "LocalLcp"    = @{ Script="Optimize-LocalLcp.ps1";             Name="Local Browser & Dashboard LCP Tuning";   Key="4" }
    "LiveTv"      = @{ Script="Optimize-MediaStackLive.ps1";       Name="Live TV & HLS Streaming Latency Tuning"; Key="5" }
}

# Interactive Menu
if (-not $All -and -not $Target -and -not $BenchmarkOnly -and -not $NonInteractive) {
    Clear-Host
    Write-Host "`n================================================================================" -ForegroundColor Cyan
    Write-Host "   M E D I A S T A C K   O P T I M I Z A T I O N   S U I T E" -ForegroundColor DarkCyan
    Write-Host "   Master Launcher for Sub-Second Streaming, Database & Edge Performance" -ForegroundColor DarkGray
    Write-Host "================================================================================" -ForegroundColor Cyan
    Write-Host "   Subdirectory: optimize-files/ | Timestamp: $timestamp" -ForegroundColor White
    Write-Host "--------------------------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "   [1] Full Multi-Pillar Optimization Sweep (All Engines)" -ForegroundColor Green
    Write-Host "   [2] Core Edge & Latency Accelerator (Optimize-MediaStackPerformance.ps1)" -ForegroundColor Yellow
    Write-Host "   [3] SQLite Database PRAGMA & Cache Accelerator (Optimize-MediaStackDatabase.ps1)" -ForegroundColor Yellow
    Write-Host "   [4] Dual-Node Cluster LCP Tuning (Optimize-DualNodeLcp.ps1)" -ForegroundColor Yellow
    Write-Host "   [5] Local Dashboard LCP Tuning (Optimize-LocalLcp.ps1)" -ForegroundColor Yellow
    Write-Host "   [6] Live TV & HLS Streaming Buffer Tuning (Optimize-MediaStackLive.ps1)" -ForegroundColor Yellow
    Write-Host "   [7] Benchmark Load Times & Response Latencies Only (-BenchmarkOnly)" -ForegroundColor Cyan
    Write-Host "   [0] Exit" -ForegroundColor DarkGray
    Write-Host "--------------------------------------------------------------------------------" -ForegroundColor DarkGray
    $choice = Read-Host "   Enter selection [1-7, 0]"

    switch ($choice) {
        "1" { $All = $true }
        "2" { $Target = "Performance" }
        "3" { $Target = "Database" }
        "4" { $Target = "DualNodeLcp" }
        "5" { $Target = "LocalLcp" }
        "6" { $Target = "LiveTv" }
        "7" { $BenchmarkOnly = $true; $Target = "Performance" }
        default {
            Write-Host "`nExiting Optimization Suite.`n" -ForegroundColor DarkGray
            return
        }
    }
}

if ($All) { $Target = "All" }
if (-not $Target) { $Target = "All" }

$toRun = @()
if ($Target -eq "All") {
    $toRun = @($OptCatalog.Keys)
} else {
    $toRun = @($Target)
}

Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host "   E X E C U T I N G   O P T I M I Z A T I O N   S U I T E" -ForegroundColor DarkCyan
Write-Host ("   Scope: {0} ({1} module(s)) | BenchmarkOnly: {2}" -f $Target, $toRun.Count, $BenchmarkOnly) -ForegroundColor White
Write-Host "================================================================================" -ForegroundColor Cyan

$results = @()

foreach ($key in $toRun) {
    $meta = $OptCatalog[$key]
    $scriptPath = Join-Path $OptDir $meta.Script

    Write-Host "`n--------------------------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host ("[*] Launching Module: {0} ({1})" -f $key, $meta.Name) -ForegroundColor Cyan
    Write-Host ("    Path: optimize-files\{0}" -f $meta.Script) -ForegroundColor DarkGray
    Write-Host "--------------------------------------------------------------------------------" -ForegroundColor DarkGray

    if (-not (Test-Path $scriptPath)) {
        Write-Host ("  [ERROR] Script missing: {0}" -f $scriptPath) -ForegroundColor Red
        $results += [PSCustomObject]@{
            Module  = $key
            Name    = $meta.Name
            Status  = "FILE_NOT_FOUND"
            Elapsed = "0s"
        }
        continue
    }

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        if ($key -eq "Performance" -and $BenchmarkOnly) {
            & $scriptPath -BenchmarkOnly
        } else {
            & $scriptPath
        }
        $sw.Stop()

        $results += [PSCustomObject]@{
            Module  = $key
            Name    = $meta.Name
            Status  = "OPTIMIZED"
            Elapsed = ("{0:N1}s" -f $sw.Elapsed.TotalSeconds)
        }
    } catch {
        $sw.Stop()
        Write-Host ("  [FAIL] Error executing {0}: $_" -f $key) -ForegroundColor Red
        $results += [PSCustomObject]@{
            Module  = $key
            Name    = $meta.Name
            Status  = "ERROR"
            Elapsed = ("{0:N1}s" -f $sw.Elapsed.TotalSeconds)
        }
    }
}

# Output Summary Matrix
Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host "   O P T I M I Z A T I O N   S U I T E   R E S U L T S" -ForegroundColor DarkCyan
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host ("{0,-15} | {1,-40} | {2,-12} | {3}" -f "MODULE", "NAME", "STATUS", "ELAPSED") -ForegroundColor White
Write-Host "--------------------------------------------------------------------------------" -ForegroundColor DarkGray

foreach ($r in $results) {
    $color = if ($r.Status -eq "OPTIMIZED") { "Green" } else { "Red" }
    Write-Host ("{0,-15} | {1,-40} | {2,-12} | {3}" -f $r.Module, $r.Name, $r.Status, $r.Elapsed) -ForegroundColor $color
}

# Generate Consolidated Report
$reportFile = Join-Path $HandoffsDir "MediaStack_Optimization_Suite_Report_$fileTag.md"
$tableRows = $results | ForEach-Object {
    "| **$($_.Module)** | $($_.Name) | $($_.Status) | $($_.Elapsed) |"
}

$rep = @"
# MediaStack Optimization Suite Execution Report

| Parameter | Value |
| :--- | :--- |
| **Execution Host** | $($env:COMPUTERNAME) |
| **Optimization Scope** | $Target |
| **Benchmark Mode** | $BenchmarkOnly |
| **Timestamp** | $timestamp |
| **Subdirectory** | \optimize-files |

## Execution Matrix

| Module | Description | Status | Elapsed |
| :--- | :--- | :--- | :--- |
$($tableRows -join "`n")

---
*Generated by Invoke-MediaStackOptimizationSuite.ps1.*
"@

Set-Content -Path $reportFile -Value $rep -Encoding UTF8
Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host ("   [COMPLETE] Suite Execution Finished. Full Report: {0}" -f $reportFile) -ForegroundColor Green
Write-Host "================================================================================`n" -ForegroundColor Cyan
