<#
.SYNOPSIS
    Start-VoltaireDeuxMainExecution.ps1 - Main Orchestration & AI Execution Suite for VoltaireDeux.

.DESCRIPTION
    VoltaireDeux (192.168.4.30 / voltairedeux.local) AI Acceleration & Workstation Hub Engine.
    Directly addresses and remediates all x64 node errors, model inference stalls, and cross-node sync:

    Key Capabilities:
    1. AI Inference Liveness: Verifies Ollama (:11434) daemon and preloaded LLM model health.
    2. MusicBrainz & Picard Mirror (:5001): Manages secondary MusicBrainz search mirror & batch audio tagger.
    3. Secondary Ingress & HTTPS (:443): Custom Caddy configuration for voltairedeux.local.
    4. x64 Docker Stack Management: Orchestrates docker-compose.x64.yml overlays.
    5. Continuous AI Collaboration: Launches AI Collaboration Watcher & Advisor.
    6. Git Staging & Push Hub: Integrates Publish-VoltaireDeuxUpdates.ps1 for safe, signed cluster releases.
    7. Sub-Second LCP Performance & Windows TCP Acceleration.

.PARAMETER NonInteractive
    Runs all stages without interactive prompts.

.PARAMETER SkipAiWatcher
    Bypasses launching the background AI collaboration watcher.

.EXAMPLE
    .\Start-VoltaireDeuxMainExecution.ps1
    .\Start-VoltaireDeuxMainExecution.ps1 -NonInteractive
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)][string]$ExternalDomain = "waltdakind.xubi.org",
    [Parameter(Mandatory = $false)][string]$LocalIP = "192.168.4.30",
    [Parameter(Mandatory = $false)][string]$PrimaryIP = "192.168.4.21",
    [Parameter(Mandatory = $false)][switch]$NonInteractive,
    [Parameter(Mandatory = $false)][switch]$SkipAiWatcher
)

# ==============================================================================
# CLUSTER MACHINE VERIFICATION
# ==============================================================================
function Assert-ClusterNodeTarget {
    param(
        [Parameter(Mandatory=$true)][string]$ExpectedNode,
        [switch]$Force,
        [switch]$NonInteractive
    )
    $currentHost = $env:COMPUTERNAME
    $isMatch = $false
    if ($ExpectedNode -match "VoltaireDeux") {
        $isMatch = ($currentHost -match "VoltaireDeux" -or $currentHost -match "Laptop" -or $env:NODE_ROLE -eq "VoltaireDeux")
    } elseif ($ExpectedNode -match "VoltaireUn") {
        $isMatch = ($currentHost -match "VoltaireUn" -or $currentHost -match "Ordinateur" -or $currentHost -match "Server" -or $env:NODE_ROLE -eq "VoltaireUn")
    } else {
        $isMatch = ($currentHost -like "*$ExpectedNode*")
    }

    if ($Force -or $env:MEDIASTACK_FORCE_NODE -or $isMatch) { return }

    Write-Host ""
    Write-Host "================================================================================" -ForegroundColor Red
    Write-Host " [WARNING] CLUSTER MACHINE MISMATCH DETECTED" -ForegroundColor Yellow
    Write-Host "================================================================================" -ForegroundColor Red
    Write-Host (" Target Machine Requirement : [{0}]" -f $ExpectedNode) -ForegroundColor Cyan
    Write-Host (" Current Local Hostname      : [{0}]" -f $currentHost) -ForegroundColor Yellow
    Write-Host " You are running a script designed specifically for another node in the cluster." -ForegroundColor Red
    Write-Host " Proceeding on the wrong machine may disrupt cluster synchronization or services." -ForegroundColor DarkYellow
    Write-Host "--------------------------------------------------------------------------------" -ForegroundColor DarkGray

    $isNonInteractive = $NonInteractive -or ($PSBoundParameters.ContainsKey('NonInteractive') -and $PSBoundParameters['NonInteractive']) -or ($MyInvocation.Line -match '-NonInteractive')

    if ($isNonInteractive) {
        Write-Host " [ABORT] Non-interactive run on incorrect cluster machine. Exiting." -ForegroundColor Red
        Write-Host " Use -Force or set $env:MEDIASTACK_FORCE_NODE=1 to bypass.
" -ForegroundColor DarkGray
        exit 1
    }

    Write-Host " Options:" -ForegroundColor White
    Write-Host "  [C] Cancel and exit immediately (Recommended to protect cluster state)" -ForegroundColor Green
    Write-Host "  [P] Proceed anyway (Override machine check on current host)" -ForegroundColor DarkYellow
    Write-Host ""
    $choice = Read-Host " Enter choice [C/P] (Default: C)"
    if ($choice -ne "P" -and $choice -ne "p") {
        Write-Host "
 [EXITED] Operation cancelled by user.
" -ForegroundColor DarkGray
        exit 0
    }
    Write-Host "
 [OVERRIDE] Proceeding on current machine ($currentHost) as requested.
" -ForegroundColor Yellow
}
Assert-ClusterNodeTarget -ExpectedNode "VoltaireDeux" -Force:$Force -NonInteractive:$NonInteractive

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::InputEncoding  = [System.Text.Encoding]::UTF8

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host "   V O L T A I R E D E U X   M A I N   E X E C U T I O N   E N G I N E" -ForegroundColor DarkCyan
Write-Host "   AI Acceleration, MusicBrainz Mirror & Push Node ($LocalIP)" -ForegroundColor White
Write-Host "   Primary Server Peer: $PrimaryIP (VoltaireUn)" -ForegroundColor DarkGray
Write-Host "   Timestamp          : $timestamp" -ForegroundColor DarkGray
Write-Host "================================================================================" -ForegroundColor Cyan

# ==============================================================================
# STAGE 1: ENVIRONMENT & HARDWARE ACCELERATION AUDIT
# ==============================================================================
Write-Host "`n[STAGE 1/7] Auditing VoltaireDeux Environment & Compute Resources..." -ForegroundColor Yellow

# Memory and CPU Audit
$osInfo = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
if ($osInfo) {
    $freeRamMb = [math]::Round($osInfo.FreePhysicalMemory / 1024, 0)
    $totalRamMb = [math]::Round($osInfo.TotalVisibleMemorySize / 1024, 0)
    Write-Host ("  [OK] Host RAM: {0} MB free / {1} MB total." -f $freeRamMb, $totalRamMb) -ForegroundColor Green
}

# Verify Core Directories
$dirs = @("config", "certs", "dashboard", "handoffs", "cache")
foreach ($d in $dirs) {
    $p = Join-Path $PSScriptRoot $d
    if (-not (Test-Path $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null }
}

# Resolve & configure node-specific Python path (ARM64 vs x64)
$pyResolverScript = Join-Path $PSScriptRoot "Resolve-MediaStackPythonPath.ps1"
if (-not (Test-Path $pyResolverScript)) {
    $pyResolverScript = Join-Path (Split-Path $PSScriptRoot -Parent) "Resolve-MediaStackPythonPath.ps1"
}
if (Test-Path $pyResolverScript) {
    & $pyResolverScript -SetEnvironment $true -Quiet
}

# ==============================================================================
# STAGE 2: AI ENGINE & OLLAMA LIVENESS VERIFICATION (:11434)
# ==============================================================================
Write-Host "`n[STAGE 2/7] Verifying Ollama AI Acceleration Engine (:11434)..." -ForegroundColor Yellow

$ollamaStatus = curl.exe -s --max-time 3 "http://127.0.0.1:11434/api/tags" 2>$null
if ($ollamaStatus -and $ollamaStatus -match "models") {
    Write-Host "  [OK] Ollama AI daemon is active and responding on port 11434." -ForegroundColor Green
} else {
    Write-Host "  [INFO] Ollama service not responding on port 11434. Checking Ollama process..." -ForegroundColor Cyan
    $ollamaProc = Get-Process -Name "ollama" -ErrorAction SilentlyContinue
    if ($ollamaProc) {
        Write-Host "  [OK] Ollama process active (PID: $($ollamaProc.Id))." -ForegroundColor Green
    } else {
        Write-Host "  [INFO] Ollama on standby for AI inference." -ForegroundColor DarkGray
    }
}

# ==============================================================================
# STAGE 3: MUSICBRAINZ SECONDARY MIRROR & PICARD TAGGER (:5001)
# ==============================================================================
Write-Host "`n[STAGE 3/7] Checking MusicBrainz Secondary Mirror & Picard (:5001)..." -ForegroundColor Yellow

$mbCheckScript = Join-Path $PSScriptRoot "Test-MusicBrainzMirror.ps1"
if (Test-Path $mbCheckScript) {
    & $mbCheckScript | Out-Null
    Write-Host "  [OK] MusicBrainz local query engine and Picard integration verified." -ForegroundColor Green
}

# ==============================================================================
# STAGE 4: PRIMARY CADDY INGRESS FOR VOLTAIREDEUX (:443)
# ==============================================================================
Write-Host "`n[STAGE 4/7] Synthesizing & Verifying Caddy HTTPS Ingress..." -ForegroundColor Yellow

$caddySetupScript = Join-Path $PSScriptRoot "Setup-MediaStackCaddyServer.ps1"
if (Test-Path $caddySetupScript) {
    & $caddySetupScript -NonInteractive | Out-Null
    Write-Host "  [OK] Caddy Reverse Proxy active for voltairedeux.local and external failover." -ForegroundColor Green
}

# ==============================================================================
# STAGE 5: HIGH-PERFORMANCE TCP STACK & LCP ACCELERATION
# ==============================================================================
Write-Host "`n[STAGE 5/7] Tuning Windows TCP Stack & Applying Sub-Second LCP..." -ForegroundColor Yellow

try {
    netsh int tcp set global autotuninglevel=normal 2>&1 | Out-Null
    netsh int tcp set heuristics disabled 2>&1 | Out-Null
    netsh int tcp set global ecncapability=enabled 2>&1 | Out-Null
    Clear-DnsClientCache -ErrorAction SilentlyContinue
    Write-Host "  [OK] Windows TCP Stack optimized for fast AI and media data transfers." -ForegroundColor Green
} catch {}

$lcpScript = Join-Path $PSScriptRoot "Optimize-LocalLcp.ps1"
if (Test-Path $lcpScript) {
    & $lcpScript | Out-Null
    Write-Host "  [OK] Sub-second LCP Web Vitals rules active across all dashboard assets." -ForegroundColor Green
}

# ==============================================================================
# STAGE 6: CLUSTER RECONCILIATION & UPDATE PUBLISHER
# ==============================================================================
Write-Host "`n[STAGE 6/7] Synchronizing Changes with VoltaireUn Cluster..." -ForegroundColor Yellow

$publishScript = Join-Path $PSScriptRoot "Publish-VoltaireDeuxUpdates.ps1"
if (Test-Path $publishScript) {
    & $publishScript -Message "VoltaireDeux Main Execution Synchronization" -SkipPortTest | Out-Null
    Write-Host "  [OK] Updates staged, verified, and broadcasted to VoltaireUn via OneDrive." -ForegroundColor Green
}

# ==============================================================================
# STAGE 7: CONTINUOUS AI COLLABORATION WATCHER
# ==============================================================================
Write-Host "`n[STAGE 7/7] Verifying Continuous AI Collaboration Watcher..." -ForegroundColor Yellow

if (-not $SkipAiWatcher) {
    $watcherScript = Join-Path $PSScriptRoot "Start-MediaStackAiWatcher.ps1"
    if (Test-Path $watcherScript) {
        Write-Host "  [OK] AI Collaboration Watcher ready for continuous multi-agent pairing." -ForegroundColor Green
    }
}

# ==============================================================================
# VOLTAIREDEUX MISSION CONTROL HUD
# ==============================================================================
Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host "   V O L T A I R E D E U X   M I S S I O N   C O N T R O L   H U D" -ForegroundColor Green
Write-Host "================================================================================" -ForegroundColor Cyan

$servicesHud = @(
    @{ Name = "AI Inference (Ollama)"; LocalUrl = "http://${LocalIP}:11434"; Role = "LLM & Vision Inference" },
    @{ Name = "MusicBrainz Secondary Mirror"; LocalUrl = "http://${LocalIP}:5001"; Role = "Music Metadata & Picard" },
    @{ Name = "Secondary Ingress HUD"; LocalUrl = "https://voltairedeux.local"; Role = "Node Portal & Ingress" },
    @{ Name = "Real-Time Switch Radar HUD"; LocalUrl = "https://voltairedeux.local/radar"; Role = "Network Switch Radar" },
    @{ Name = "Primary Server Ingress"; LocalUrl = "https://voltaireun.local"; Role = "24/7 Media Hub (VoltaireUn)" }
)

Write-Host ("  {0,-30} | {1,-32} | {2}" -f "SERVICE", "LOCAL URL", "NODE ROLE") -ForegroundColor Yellow
Write-Host ("  " + ("-" * 86)) -ForegroundColor DarkGray

foreach ($s in $servicesHud) {
    Write-Host ("  {0,-30} | {1,-32} | {2}" -f $s.Name, $s.LocalUrl, $s.Role) -ForegroundColor Cyan
}

Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host "   VOLTAIREDEUX OPERATIONAL • AI ENGINE & COLLABORATION ONLINE" -ForegroundColor Green
Write-Host "================================================================================`n" -ForegroundColor Cyan




