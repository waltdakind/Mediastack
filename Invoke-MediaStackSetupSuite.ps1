<#
.SYNOPSIS
    Invoke-MediaStackSetupSuite.ps1 - Master Launcher & Orchestrator for MediaStack Setup & Configuration Suite.

.DESCRIPTION
    Unified master launcher for initial system setup, network provisioning, security safeguards,
    and server configuration engines located in setup-files/:
    1. Caddy Reverse Proxy & Ingress Gateway Setup (Setup-MediaStackCaddyServer.ps1)
    2. Network Users & Reciprocal SMB Share Permissions (Set-MediaStackNetworkUsers.ps1)
    3. Host Safeguards & Resource Limits (Set-MediaStackHostSafeguards.ps1)
    4. DNS Resolver & Static Resolution Configuration (Set-DnsServers.ps1)
    5. Cluster Node Naming & Architectural Conventions (Set-ClusterNodeConvention.ps1)
    6. Ingress Security & Firewall Policy (Set-MediaStackIngressPolicy.ps1)
    7. Picard Local MusicBrainz Mirror Binding (Set-PicardLocalMirror.ps1)
    8. MediaStack Network Shares Provisioning (setup-shares.ps1)

.PARAMETER Task
    Setup task to execute: "All", "CaddyServer", "NetworkUsers", "HostSafeguards", "DnsServers", "ClusterConvention", "IngressPolicy", "PicardMirror", "Shares". Default: "All".

.PARAMETER NonInteractive
    Suppresses interactive terminal prompt.

.EXAMPLE
    .\Invoke-MediaStackSetupSuite.ps1 -All
    .\Invoke-MediaStackSetupSuite.ps1 -Task CaddyServer
    .\Invoke-MediaStackSetupSuite.ps1 -Task HostSafeguards
#>

[CmdletBinding(DefaultParameterSetName="Default")]
param(
    [Parameter(ParameterSetName="Task")]
    [ValidateSet("All", "CaddyServer", "NetworkUsers", "HostSafeguards", "DnsServers", "ClusterConvention", "IngressPolicy", "PicardMirror", "Shares")]
    [string]$Task,

    [Parameter(ParameterSetName="All")]
    [switch]$All,

    [switch]$NonInteractive
)

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::InputEncoding  = [System.Text.Encoding]::UTF8

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$fileTag = Get-Date -Format "yyyyMMdd_HHmmss"
$BaseDir = $PSScriptRoot
$SetupDir = Join-Path $BaseDir "setup-files"
$HandoffsDir = Join-Path $BaseDir "handoffs"

if (-not (Test-Path $HandoffsDir)) { New-Item -ItemType Directory -Force -Path $HandoffsDir | Out-Null }

$TaskCatalog = [ordered]@{
    "CaddyServer"       = @{ Script="Setup-MediaStackCaddyServer.ps1"; Name="Caddy Reverse Proxy & TLS Setup" }
    "NetworkUsers"      = @{ Script="Set-MediaStackNetworkUsers.ps1";  Name="Network Users & SMB Permissions Provisioning" }
    "HostSafeguards"    = @{ Script="Set-MediaStackHostSafeguards.ps1";Name="Host Safeguards, FFmpeg Cleanup & Watchdogs" }
    "DnsServers"        = @{ Script="Set-DnsServers.ps1";              Name="DNS Server & Static IP Resolution Setup" }
    "ClusterConvention" = @{ Script="Set-ClusterNodeConvention.ps1";  Name="Cluster Architectural Node Conventions" }
    "IngressPolicy"     = @{ Script="Set-MediaStackIngressPolicy.ps1"; Name="Zero-Trust Ingress Security & Port Policies" }
    "PicardMirror"      = @{ Script="Set-PicardLocalMirror.ps1";       Name="Picard Tagger Local MusicBrainz Mirror Binding" }
    "Shares"            = @{ Script="setup-shares.ps1";                Name="MediaStack Network Storage Shares Mounts" }
}

# Interactive Menu
if (-not $All -and -not $Task -and -not $NonInteractive) {
    Clear-Host
    Write-Host "`n================================================================================" -ForegroundColor DarkCyan
    Write-Host "   M E D I A S T A C K   S E T U P   &   C O N F I G   S U I T E" -ForegroundColor Cyan
    Write-Host "   Master Launcher for Infrastructure Setup, Security & Network Policies" -ForegroundColor DarkGray
    Write-Host "================================================================================" -ForegroundColor DarkCyan
    Write-Host "   Subdirectory: setup-files/ | Timestamp: $timestamp" -ForegroundColor White
    Write-Host "--------------------------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "   [1] Full Infrastructure Setup Baseline (All Engines)" -ForegroundColor Green
    Write-Host "   [2] Caddy Reverse Proxy, TLS Certificates & Ingress (Setup-MediaStackCaddyServer.ps1)" -ForegroundColor Yellow
    Write-Host "   [3] Provision Network Users & SMB Permissions (Set-MediaStackNetworkUsers.ps1)" -ForegroundColor Yellow
    Write-Host "   [4] Apply Host Safeguards, Watchdogs & Process Limits (Set-MediaStackHostSafeguards.ps1)" -ForegroundColor Yellow
    Write-Host "   [5] Configure DNS Resolvers (Set-DnsServers.ps1)" -ForegroundColor Yellow
    Write-Host "   [6] Enforce Ingress Security Policy (Set-MediaStackIngressPolicy.ps1)" -ForegroundColor Yellow
    Write-Host "   [7] Bind MusicBrainz Local Mirror in Picard (Set-PicardLocalMirror.ps1)" -ForegroundColor Yellow
    Write-Host "   [8] Mount / Provision Network Storage Shares (setup-shares.ps1)" -ForegroundColor Yellow
    Write-Host "   [0] Exit" -ForegroundColor DarkGray
    Write-Host "--------------------------------------------------------------------------------" -ForegroundColor DarkGray
    $choice = Read-Host "   Enter selection [1-8, 0]"

    switch ($choice) {
        "1" { $All = $true }
        "2" { $Task = "CaddyServer" }
        "3" { $Task = "NetworkUsers" }
        "4" { $Task = "HostSafeguards" }
        "5" { $Task = "DnsServers" }
        "6" { $Task = "IngressPolicy" }
        "7" { $Task = "PicardMirror" }
        "8" { $Task = "Shares" }
        default {
            Write-Host "`nExiting Setup Suite.`n" -ForegroundColor DarkGray
            return
        }
    }
}

if ($All) { $Task = "All" }
if (-not $Task) { $Task = "All" }

$toRun = @()
if ($Task -eq "All") {
    $toRun = @($TaskCatalog.Keys)
} else {
    $toRun = @($Task)
}

Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host "   E X E C U T I N G   S E T U P   S U I T E" -ForegroundColor DarkCyan
Write-Host ("   Scope: {0} ({1} task(s))" -f $Task, $toRun.Count) -ForegroundColor White
Write-Host "================================================================================" -ForegroundColor Cyan

$results = @()

foreach ($key in $toRun) {
    $meta = $TaskCatalog[$key]
    $scriptPath = Join-Path $SetupDir $meta.Script

    Write-Host "`n--------------------------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host ("[*] Launching Setup Task: {0} ({1})" -f $key, $meta.Name) -ForegroundColor Cyan
    Write-Host ("    Path: setup-files\{0}" -f $meta.Script) -ForegroundColor DarkGray
    Write-Host "--------------------------------------------------------------------------------" -ForegroundColor DarkGray

    if (-not (Test-Path $scriptPath)) {
        Write-Host ("  [ERROR] Script missing: {0}" -f $scriptPath) -ForegroundColor Red
        $results += [PSCustomObject]@{ Task=$key; Name=$meta.Name; Status="FILE_NOT_FOUND"; Elapsed="0s" }
        continue
    }

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        if ($key -eq "CaddyServer") {
            & $scriptPath -NonInteractive
        } else {
            & $scriptPath
        }
        $sw.Stop()

        $results += [PSCustomObject]@{
            Task    = $key
            Name    = $meta.Name
            Status  = "SUCCESS"
            Elapsed = ("{0:N1}s" -f $sw.Elapsed.TotalSeconds)
        }
    } catch {
        $sw.Stop()
        Write-Host ("  [FAIL] Error executing {0}: $_" -f $key) -ForegroundColor Red
        $results += [PSCustomObject]@{
            Task    = $key
            Name    = $meta.Name
            Status  = "ERROR"
            Elapsed = ("{0:N1}s" -f $sw.Elapsed.TotalSeconds)
        }
    }
}

# Output Summary Matrix
Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host "   S E T U P   S U I T E   R E S U L T S" -ForegroundColor DarkCyan
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host ("{0,-18} | {1,-42} | {2,-10} | {3}" -f "TASK", "NAME", "STATUS", "ELAPSED") -ForegroundColor White
Write-Host "--------------------------------------------------------------------------------" -ForegroundColor DarkGray

foreach ($r in $results) {
    $color = if ($r.Status -eq "SUCCESS") { "Green" } else { "Red" }
    Write-Host ("{0,-18} | {1,-42} | {2,-10} | {3}" -f $r.Task, $r.Name, $r.Status, $r.Elapsed) -ForegroundColor $color
}

# Generate Consolidated Report
$reportFile = Join-Path $HandoffsDir "MediaStack_Setup_Suite_Report_$fileTag.md"
$tableRows = $results | ForEach-Object {
    "| **$($_.Task)** | $($_.Name) | $($_.Status) | $($_.Elapsed) |"
}

$rep = @"
# MediaStack Setup Suite Execution Report

| Parameter | Value |
| :--- | :--- |
| **Execution Host** | $($env:COMPUTERNAME) |
| **Setup Scope** | $Task |
| **Timestamp** | $timestamp |
| **Subdirectory** | \setup-files |

## Execution Matrix

| Task | Name | Status | Elapsed |
| :--- | :--- | :--- | :--- |
$($tableRows -join "`n")

---
*Generated by Invoke-MediaStackSetupSuite.ps1.*
"@

Set-Content -Path $reportFile -Value $rep -Encoding UTF8
Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host ("   [COMPLETE] Setup Suite Execution Finished. Full Report: {0}" -f $reportFile) -ForegroundColor Green
Write-Host "================================================================================`n" -ForegroundColor Cyan
