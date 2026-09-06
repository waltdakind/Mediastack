<#
.SYNOPSIS
    Invoke-MediaStackExecutionSuite.ps1 - Master Launcher for MediaStack Execution, Lifecycles & AI Sentinels.

.DESCRIPTION
    Unified master launcher for all lifecycle controllers, full reboots, clean starts/shutdowns,
    AI collaboration engines, and automated sentinels located in the \invoke-files subdirectory.

.PARAMETER Task
    Specific invoke engine to execute:
    - Lifecycle         : Main stack lifecycle controller & monitoring loop.
    - CleanStart        : Cold clean stack startup with socket drainage.
    - CleanShutdown     : Graceful stack shutdown & container drain.
    - FullReboot        : Full cluster reboot and state engine.
    - DeepAnalysis      : Deep architectural diagnostics & health auditing.
    - AiCollaboration   : Interactive AI collaboration session.
    - HardenedSession   : Hardened AI advisor session with automated logging.
    - VoltaireDeuxAdvisor: VoltaireDeux AI workstation advice generator.
    - VoltaireUnSentinel: VoltaireUn 24/7 cluster monitoring sentinel.
    - VoltaireUnAi      : VoltaireUn AI proactive health sentinel.
    - DailyPoller       : VoltaireUn daily scheduled poller.
    - AutoRepair        : Automated self-healing stack repair engine.
    - JellyWatch        : JellyWatch notification & issue handler.
    - ClusterHandoff    : Multi-node handoff and state synchronizer.

.PARAMETER All
    Executes core operational sentinels sequentially.

.PARAMETER Force
    Bypasses prompts and forces execution.

.PARAMETER NonInteractive
    Runs unattended without interactive menus.

.EXAMPLE
    .\Invoke-MediaStackExecutionSuite.ps1
    .\Invoke-MediaStackExecutionSuite.ps1 -Task DeepAnalysis -NonInteractive
    .\Invoke-MediaStackExecutionSuite.ps1 -Task Lifecycle
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)][string]$Task = "",
    [Parameter(Mandatory = $false)][switch]$All,
    [Parameter(Mandatory = $false)][switch]$Force,
    [Parameter(Mandatory = $false)][switch]$NonInteractive
)

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::InputEncoding  = [System.Text.Encoding]::UTF8

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$BaseDir = $PSScriptRoot
$InvokeDir = Join-Path $BaseDir "invoke-files"
$HandoffsDir = Join-Path $BaseDir "handoffs"

if (-not (Test-Path $HandoffsDir)) { New-Item -ItemType Directory -Force -Path $HandoffsDir | Out-Null }

# Invoke Tasks Catalog
$InvokeCatalog = [ordered]@{}
$InvokeCatalog["Lifecycle"]          = @{ Script="Invoke-MediaStackMainLifecycle.ps1";          Name="Main Stack Lifecycle Controller" }
$InvokeCatalog["CleanStart"]         = @{ Script="Invoke-MediaStackCleanStart.ps1";             Name="Cold Clean Stack Startup Engine" }
$InvokeCatalog["CleanShutdown"]      = @{ Script="Invoke-MediaStackCleanShutdown.ps1";          Name="Graceful Stack Shutdown & Drain" }
$InvokeCatalog["FullReboot"]         = @{ Script="Invoke-MediaStackFullRebootSuite.ps1";         Name="Full Cluster Reboot & State Engine" }
$InvokeCatalog["DeepAnalysis"]       = @{ Script="Invoke-MediaStackDeepAnalysis.ps1";           Name="Deep Architectural Diagnostics & Audit" }
$InvokeCatalog["AiCollaboration"]    = @{ Script="Invoke-MediaStackAiCollaboration.ps1";        Name="AI Collaboration Session Launcher" }
$InvokeCatalog["HardenedSession"]    = @{ Script="Invoke-HardenedAiCollaborationSession.ps1";   Name="Hardened AI Advisor Engine" }
$InvokeCatalog["VoltaireDeuxAdvisor"]= @{ Script="Invoke-VoltaireDeuxAiAdvisor.ps1";           Name="VoltaireDeux AI Workstation Advisor" }
$InvokeCatalog["VoltaireUnSentinel"] = @{ Script="Invoke-VoltaireUn24hrSentinel.ps1";          Name="VoltaireUn 24/7 Monitoring Sentinel" }
$InvokeCatalog["VoltaireUnAi"]       = @{ Script="Invoke-VoltaireUnAiSentinel.ps1";            Name="VoltaireUn AI Health Sentinel" }
$InvokeCatalog["DailyPoller"]        = @{ Script="Invoke-VoltaireUnDailyPoller.ps1";           Name="VoltaireUn Daily Health Poller" }
$InvokeCatalog["AutoRepair"]         = @{ Script="Invoke-StackAutoRepair.ps1";                  Name="Automated Self-Healing Stack Repair" }
$InvokeCatalog["JellyWatch"]         = @{ Script="Invoke-JellyWatchHandler.ps1";                Name="JellyWatch Notification & Issue Handler" }
$InvokeCatalog["ClusterHandoff"]     = @{ Script="Invoke-MediaStackClusterHandoff.ps1";        Name="Cluster Priority Handoff Synchronizer" }
$InvokeCatalog["StopCollab"]         = @{ Script="Stop-MediaStackAiCollaboration.ps1";          Name="AI Collaboration Session Exit & Sentinel Termination" }

# Interactive Selection Menu
if (-not $Task -and -not $All -and -not $NonInteractive) {
    Clear-Host
    Write-Host "================================================================================" -ForegroundColor DarkCyan
    Write-Host "   M E D I A S T A C K   I N V O K E   &   E X E C U T I O N   S U I T E" -ForegroundColor Cyan
    Write-Host "   Master Launcher for Lifecycles, Reboots, AI Sentinels & Auto-Healing" -ForegroundColor DarkGray
    Write-Host "================================================================================" -ForegroundColor DarkCyan
    Write-Host ("   Host: {0} | Timestamp: {1} | Subdirectory: invoke-files/" -f $env:COMPUTERNAME, $timestamp) -ForegroundColor White
    Write-Host "--------------------------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "   [LIFECYCLE & REBOOT CONTROLLERS]" -ForegroundColor Yellow
    Write-Host "   [1]  Execute Main Stack Lifecycle Controller (Invoke-MediaStackMainLifecycle.ps1)" -ForegroundColor Green
    Write-Host "   [2]  Execute Cold Clean Stack Startup (Invoke-MediaStackCleanStart.ps1)" -ForegroundColor Yellow
    Write-Host "   [3]  Execute Graceful Stack Shutdown (Invoke-MediaStackCleanShutdown.ps1)" -ForegroundColor Yellow
    Write-Host "   [4]  Execute Full Cluster Reboot Suite (Invoke-MediaStackFullRebootSuite.ps1)" -ForegroundColor Yellow
    Write-Host "   `n   [AI COLLABORATION & HOST SENTINELS]" -ForegroundColor Yellow
    Write-Host "   [5]  Launch AI Collaboration Session (Invoke-MediaStackAiCollaboration.ps1)" -ForegroundColor Cyan
    Write-Host "   [6]  Launch Hardened AI Advisor Session (Invoke-HardenedAiCollaborationSession.ps1)" -ForegroundColor Cyan
    Write-Host "   [7]  Generate VoltaireDeux AI Advisor Guidance (Invoke-VoltaireDeuxAiAdvisor.ps1)" -ForegroundColor Cyan
    Write-Host "   [8]  Run VoltaireUn 24/7 Cluster Sentinel (Invoke-VoltaireUn24hrSentinel.ps1)" -ForegroundColor Yellow
    Write-Host "   [9]  Run VoltaireUn AI Health Sentinel (Invoke-VoltaireUnAiSentinel.ps1)" -ForegroundColor Yellow
    Write-Host "   [10] Run VoltaireUn Daily Schedule Poller (Invoke-VoltaireUnDailyPoller.ps1)" -ForegroundColor Yellow
    Write-Host "   `n   [DIAGNOSTICS & SYSTEM HANDLERS]" -ForegroundColor Yellow
    Write-Host "   [11] Run Deep Architectural Health Analysis (Invoke-MediaStackDeepAnalysis.ps1)" -ForegroundColor Magenta
    Write-Host "   [12] Run Stack Self-Healing Auto-Repair (Invoke-StackAutoRepair.ps1)" -ForegroundColor Green
    Write-Host "   [13] Trigger JellyWatch Event Handler (Invoke-JellyWatchHandler.ps1)" -ForegroundColor Yellow
    Write-Host "   [14] Execute Cluster Priority Handoff Sync (Invoke-MediaStackClusterHandoff.ps1)" -ForegroundColor Yellow
    Write-Host "   `n   [COLLABORATION SESSION MANAGEMENT]" -ForegroundColor Yellow
    Write-Host "   [15] Conclude AI Collaboration Session & Stop Frequent Polling (Stop-MediaStackAiCollaboration.ps1)" -ForegroundColor Red
    Write-Host "   `n   [0]  Exit" -ForegroundColor DarkGray
    Write-Host "--------------------------------------------------------------------------------" -ForegroundColor DarkGray
    $choice = Read-Host "   Enter selection [1-15, 0]"

    switch ($choice.ToString().Trim()) {
        "1"  { $Task = "Lifecycle" }
        "2"  { $Task = "CleanStart" }
        "3"  { $Task = "CleanShutdown" }
        "4"  { $Task = "FullReboot" }
        "5"  { $Task = "AiCollaboration" }
        "6"  { $Task = "HardenedSession" }
        "7"  { $Task = "VoltaireDeuxAdvisor" }
        "8"  { $Task = "VoltaireUnSentinel" }
        "9"  { $Task = "VoltaireUnAi" }
        "10" { $Task = "DailyPoller" }
        "11" { $Task = "DeepAnalysis" }
        "12" { $Task = "AutoRepair" }
        "13" { $Task = "JellyWatch" }
        "14" { $Task = "ClusterHandoff" }
        "15" { $Task = "StopCollab" }
        default {
            Write-Host "`nExiting Execution Suite.`n" -ForegroundColor DarkGray
            return
        }
    }
}

if (-not $Task) {
    # Default non-interactive: Deep Analysis
    $Task = "DeepAnalysis"
}

$selectedInfo = $null
if ($InvokeCatalog.Contains($Task)) {
    $selectedInfo = $InvokeCatalog[$Task]
} else {
    $match = $InvokeCatalog.Keys | Where-Object { $_ -like "*$Task*" -or $InvokeCatalog[$_].Script -like "*$Task*" } | Select-Object -First 1
    if ($match) {
        $selectedInfo = $InvokeCatalog[$match]
    } else {
        Write-Error "Invoke task '$Task' not found in catalog."
        return
    }
}

$scriptPath = Join-Path $InvokeDir $selectedInfo.Script
if (-not (Test-Path $scriptPath)) {
    Write-Error "Script '$scriptPath' does not exist."
    return
}

Write-Host "`n--------------------------------------------------------------------------------" -ForegroundColor DarkGray
Write-Host ("[*] Launching: {0} ({1})" -f $selectedInfo.Name, $selectedInfo.Script) -ForegroundColor Yellow
Write-Host "--------------------------------------------------------------------------------`n" -ForegroundColor DarkGray

$targetCmd = Get-Command $scriptPath -ErrorAction SilentlyContinue
$acceptedParams = if ($targetCmd) { $targetCmd.Parameters.Keys } else { @() }
$params = @{}
if ($Force -and $acceptedParams -contains "Force") { $params["Force"] = $true }
if ($NonInteractive -and $acceptedParams -contains "NonInteractive") { $params["NonInteractive"] = $true }

& $scriptPath @params
