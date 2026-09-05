<#
.SYNOPSIS
    Invoke-MediaStackStartSuite.ps1 - Master Launcher for MediaStack Boot, Startup & Node Orchestration Engines.

.DESCRIPTION
    Unified master launcher for all stack boot engines, node coordinators, AI watchers,
    and platform startup scripts located in the \start-files subdirectory.

.PARAMETER Target
    Specific startup engine to launch:
    - Fleet           : Master MediaStack Fleet Engine (interactive control & repair).
    - VoltaireUn      : VoltaireUn Primary 24/7 Media Hub Node.
    - VoltaireDeux    : VoltaireDeux AI Workstation & Compute Node.
    - Orchestrator    : Cluster Master Orchestrator.
    - PrimaryStack    : Primary Core Docker Services Stack.
    - AiWatcher       : AI Telemetry Watcher & Autohealer Sentinel.
    - Autonomous      : Autonomous AI Collaborator Daemon.
    - Stack           : Interactive MediaStack Control Panel.
    - X64             : x64 Intel/AMD Architecture Launcher.
    - ARM             : ARM64 / Apple Silicon / Raspberry Pi Launcher.

.PARAMETER Force
    Bypasses node mismatch checks and confirmation prompts.

.PARAMETER NonInteractive
    Runs unattended without interactive menus.

.EXAMPLE
    .\Invoke-MediaStackStartSuite.ps1
    .\Invoke-MediaStackStartSuite.ps1 -Target Fleet -NonInteractive
    .\Invoke-MediaStackStartSuite.ps1 -Target VoltaireDeux
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)][string]$Target = "",
    [Parameter(Mandatory = $false)][switch]$All,
    [Parameter(Mandatory = $false)][switch]$Force,
    [Parameter(Mandatory = $false)][switch]$Fast,
    [Parameter(Mandatory = $false)][switch]$NonInteractive
)

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::InputEncoding  = [System.Text.Encoding]::UTF8

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$BaseDir = $PSScriptRoot
$StartDir = Join-Path $BaseDir "start-files"

# Startup Engines Catalog
$StartCatalog = [ordered]@{}
$StartCatalog["Fleet"]        = @{ Script="Start-MediaStackFleet.ps1";                 Name="Master MediaStack Fleet Engine" }
$StartCatalog["VoltaireUn"]   = @{ Script="Start-VoltaireUn.ps1";                      Name="VoltaireUn Primary 24/7 Media Hub Node" }
$StartCatalog["VoltaireDeux"] = @{ Script="Start-VoltaireDeux.ps1";                    Name="VoltaireDeux AI Workstation & Compute Node" }
$StartCatalog["Orchestrator"] = @{ Script="Start-MediaStackOrchestrator.ps1";          Name="Cluster Master Orchestrator" }
$StartCatalog["PrimaryStack"] = @{ Script="Start-PrimaryStack.ps1";                    Name="Primary Core Docker Services Stack" }
$StartCatalog["AiWatcher"]    = @{ Script="Start-MediaStackAiWatcher.ps1";             Name="AI Telemetry Watcher & Autohealer" }
$StartCatalog["Autonomous"]   = @{ Script="Start-AutonomousMediaStackCollaborator.ps1"; Name="Autonomous AI Collaborator Sentinel" }
$StartCatalog["Stack"]        = @{ Script="Start-MediaStack.ps1";                      Name="Interactive MediaStack Control Panel" }
$StartCatalog["X64"]          = @{ Script="start-x64.ps1";                             Name="x64 Architecture Deployment Launcher" }
$StartCatalog["ARM"]          = @{ Script="start-arm.ps1";                             Name="ARM64 Architecture Deployment Launcher" }

# Interactive Selection
if (-not $Target -and -not $NonInteractive) {
    Clear-Host
    Write-Host "================================================================================" -ForegroundColor DarkCyan
    Write-Host "   M E D I A S T A C K   S T A R T   &   B O O T   S U I T E" -ForegroundColor Cyan
    Write-Host "   Master Launcher for Node Bootstrapping, Fleets & AI Coordinators" -ForegroundColor DarkGray
    Write-Host "================================================================================" -ForegroundColor DarkCyan
    Write-Host ("   Host: {0} | Timestamp: {1} | Subdirectory: start-files/" -f $env:COMPUTERNAME, $timestamp) -ForegroundColor White
    Write-Host "--------------------------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "   [1] Start Master MediaStack Fleet Engine (Interactive Hub)" -ForegroundColor Green
    Write-Host "   [2] Start VoltaireUn Primary Media Server Node (192.168.4.21)" -ForegroundColor Yellow
    Write-Host "   [3] Start VoltaireDeux AI Workstation Node (192.168.4.30)" -ForegroundColor Yellow
    Write-Host "   [4] Start Cluster Master Orchestrator" -ForegroundColor Yellow
    Write-Host "   [5] Start Primary Core Docker Stack" -ForegroundColor Yellow
    Write-Host "   [6] Start AI Telemetry Watcher & Autohealer" -ForegroundColor Yellow
    Write-Host "   [7] Start Autonomous AI Collaborator Daemon" -ForegroundColor Yellow
    Write-Host "   [8] Start Interactive MediaStack Control Panel" -ForegroundColor Yellow
    Write-Host "   [9] Launch Platform Architecture (x64 / ARM64)" -ForegroundColor Cyan
    Write-Host "   [0] Exit" -ForegroundColor DarkGray
    Write-Host "--------------------------------------------------------------------------------" -ForegroundColor DarkGray
    $choice = Read-Host "   Enter selection [1-9, 0]"

    switch ($choice.ToString().ToUpper()) {
        "1" { $Target = "Fleet" }
        "2" { $Target = "VoltaireUn" }
        "3" { $Target = "VoltaireDeux" }
        "4" { $Target = "Orchestrator" }
        "5" { $Target = "PrimaryStack" }
        "6" { $Target = "AiWatcher" }
        "7" { $Target = "Autonomous" }
        "8" { $Target = "Stack" }
        "9" { $Target = if ([System.Environment]::Is64BitOperatingSystem) { "X64" } else { "ARM" } }
        default {
            Write-Host "`nExiting Start Suite.`n" -ForegroundColor DarkGray
            return
        }
    }
}

# Resolve Target Engine
if (-not $Target) {
    # Default non-interactive: Auto-detect appropriate node
    $currentHost = $env:COMPUTERNAME
    if ($currentHost -match "VoltaireDeux" -or $currentHost -match "Laptop") {
        $Target = "VoltaireDeux"
    } elseif ($currentHost -match "VoltaireUn" -or $currentHost -match "Server") {
        $Target = "VoltaireUn"
    } else {
        $Target = "Fleet"
    }
}

$selectedInfo = $null
if ($StartCatalog.Contains($Target)) {
    $selectedInfo = $StartCatalog[$Target]
} else {
    $match = $StartCatalog.Keys | Where-Object { $_ -like "*$Target*" -or $StartCatalog[$_].Script -like "*$Target*" } | Select-Object -First 1
    if ($match) {
        $selectedInfo = $StartCatalog[$match]
    } else {
        Write-Error "Start target '$Target' not found in catalog."
        return
    }
}

$scriptPath = Join-Path $StartDir $selectedInfo.Script
if (-not (Test-Path $scriptPath)) {
    Write-Error "Startup script '$scriptPath' does not exist."
    return
}

Write-Host "`n--------------------------------------------------------------------------------" -ForegroundColor DarkGray
Write-Host ("[*] Launching: {0} ({1})" -f $selectedInfo.Name, $selectedInfo.Script) -ForegroundColor Yellow
Write-Host "--------------------------------------------------------------------------------`n" -ForegroundColor DarkGray

# Dynamically pass supported parameters
$targetCmd = Get-Command $scriptPath -ErrorAction SilentlyContinue
$acceptedParams = if ($targetCmd) { $targetCmd.Parameters.Keys } else { @() }
$params = @{}
if ($Force -and $acceptedParams -contains "Force") { $params["Force"] = $true }
if ($NonInteractive -and $acceptedParams -contains "NonInteractive") { $params["NonInteractive"] = $true }
if ($Fast -and $acceptedParams -contains "Fast") { $params["Fast"] = $true }

& $scriptPath @params
