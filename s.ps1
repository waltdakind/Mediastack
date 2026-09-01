[CmdletBinding()]
param(
    [Alias("u", "1")][switch]$VoltaireUn,
    [Alias("d", "2")][switch]$VoltaireDeux,
    [Alias("l", "3")][switch]$Lcp,
    [Alias("r", "4")][switch]$Radar,
    [Alias("j", "5")][switch]$Repair,
    [Alias("m", "6")][switch]$Sync,
    [Alias("a", "8", "main")][switch]$Lifecycle,
    [Alias("n", "9", "shares")][switch]$NetworkShares,
    [Alias("0", "upgrade")][switch]$Update,
    [Alias("f", "full", "reboot")][switch]$FullSuite,
    [Alias("rp", "repairfleet")][switch]$RepairFleet,
    [Alias("bk", "backupfleet")][switch]$BackupFleet,
    [Alias("chk", "checkfleet", "connectivity")][switch]$CheckFleet,
    [Alias("rep", "syncfleet", "replicate")][switch]$SyncFleet,
    [Alias("v", "verifyfleet")][switch]$VerifyFleet,
    [Alias("da", "deepanalysis", "handoffs")][switch]$DeepAnalysis,
    [Parameter(Mandatory = $false)][switch]$NonInteractive
)

<#
.SYNOPSIS
    s.ps1 - MediaStack Dual-Node Master Quick Command Shortcut.
.DESCRIPTION
    Ultra-fast single-command / single-key shortcut for managing, starting, and optimizing
    both VoltaireUn (192.168.4.21) and VoltaireDeux (192.168.4.30).
#>

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::InputEncoding  = [System.Text.Encoding]::UTF8

# Direct flag dispatch
if ($VoltaireUn) {
    & "$PSScriptRoot\Start-VoltaireUn.ps1" -NonInteractive:$NonInteractive
    return
}
if ($VoltaireDeux) {
    & "$PSScriptRoot\Start-VoltaireDeux.ps1" -NonInteractive:$NonInteractive
    return
}
if ($Lcp) {
    & "$PSScriptRoot\Optimize-DualNodeLcp.ps1"
    return
}
if ($Radar) {
    & "$PSScriptRoot\Test-LocalNetworkSwitch.ps1"
    return
}
if ($Repair) {
    & "$PSScriptRoot\Repair-JellyfinServer.ps1" -AutoFix
    return
}
if ($Sync) {
    & "$PSScriptRoot\Merge-OneDriveMediaStack.ps1"
    return
}
if ($Lifecycle) {
    & "$PSScriptRoot\Invoke-MediaStackMainLifecycle.ps1"
    return
}
if ($NetworkShares) {
    & "$PSScriptRoot\Set-MediaStackNetworkUsers.ps1"
    return
}
if ($Update) {
    & "$PSScriptRoot\Install-MediaStackUpdate.ps1"
    return
}
if ($FullSuite) {
    & "$PSScriptRoot\Invoke-MediaStackFullRebootSuite.ps1"
    return
}
if ($RepairFleet) {
    & "$PSScriptRoot\Repair-MediaStackFleet.ps1" -All -AutoFix
    return
}
if ($BackupFleet) {
    & "$PSScriptRoot\Backup-MediaStackFleet.ps1" -All
    return
}
if ($CheckFleet) {
    & "$PSScriptRoot\Test-MediaStackFleetConnectivity.ps1" -All -DeepAuth
    return
}
if ($SyncFleet) {
    & "$PSScriptRoot\Replicate-MediaStackCluster.ps1" -All -RunOnce
    return
}
if ($VerifyFleet) {
    & "$PSScriptRoot\Test-MediaStackFleetVerification.ps1" -All
    return
}
if ($DeepAnalysis) {
    & "$PSScriptRoot\Invoke-MediaStackDeepAnalysis.ps1"
    return
}

# Interactive Single-Key HUD Menu
Clear-Host
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "   M E D I A S T A C K   D U A L - N O D E   M A I N   S H O R T C U T" -ForegroundColor DarkCyan
Write-Host "   VoltaireUn (192.168.4.21) <===================> VoltaireDeux (192.168.4.30)" -ForegroundColor White
Write-Host "================================================================================" -ForegroundColor Cyan

Write-Host "`n  [1] " -NoNewline -ForegroundColor Yellow
Write-Host "Start VoltaireUn (Main 24/7 Server)           -> Shortcut: .\s-v1.ps1 or s-v1" -ForegroundColor White

Write-Host "  [2] " -NoNewline -ForegroundColor Yellow
Write-Host "Start VoltaireDeux (AI Node and Workstation)   -> Shortcut: .\s-v2.ps1 or s-v2" -ForegroundColor White

Write-Host "  [3] " -NoNewline -ForegroundColor Yellow
Write-Host "Optimize LCP and Latency Across BOTH Servers   -> Shortcut: .\s.ps1 -l" -ForegroundColor Cyan

Write-Host "  [4] " -NoNewline -ForegroundColor Yellow
Write-Host "Run Network Switch Radar and Reachability Check -> Shortcut: .\s.ps1 -r" -ForegroundColor White

Write-Host "  [5] " -NoNewline -ForegroundColor Yellow
Write-Host "Run Jellyfin Self-Healing and Diagnostic Engine -> Shortcut: .\s.ps1 -j" -ForegroundColor White

Write-Host "  [6] " -NoNewline -ForegroundColor Yellow
Write-Host "Synchronize and Reconcile Cluster (OneDrive)   -> Shortcut: .\s.ps1 -m" -ForegroundColor White

Write-Host "  [7] " -NoNewline -ForegroundColor Yellow
Write-Host "Enforce 24/7 Host Safeguards (No-Sleep and Autoheal) -> Shortcut: .\s.ps1 -p" -ForegroundColor Green

Write-Host "  [8] " -NoNewline -ForegroundColor Yellow
Write-Host "Main Lifecycle: Analyze, Backup, Repair, MusicBrainz Sync and Autoheal -> .\s.ps1 -a" -ForegroundColor Cyan

Write-Host "  [9] " -NoNewline -ForegroundColor Yellow
Write-Host "Network Users and Reciprocal Read-Write SMB Shares Setup -> .\s.ps1 -n" -ForegroundColor Yellow

Write-Host "  [0] " -NoNewline -ForegroundColor Yellow
Write-Host "Install / Replicate MediaStack Update Package (Unzip and Bootstrap) -> .\s.ps1 -Update" -ForegroundColor Green

Write-Host "  [F] " -NoNewline -ForegroundColor Yellow
Write-Host "Full Suite: Diagnose, Backup, Shutdown, Repull, Restart & AI Sentinel -> .\s.ps1 -f" -ForegroundColor Magenta

Write-Host "`n--- 4-PILLAR ENTERPRISE OPERATIONAL HUBS ---" -ForegroundColor Cyan

Write-Host "  [R] " -NoNewline -ForegroundColor Yellow
Write-Host "Master Fleet Repair (Auto-Heal All 12 Services) -> Shortcut: .\s.ps1 -rp" -ForegroundColor Cyan

Write-Host "  [B] " -NoNewline -ForegroundColor Yellow
Write-Host "Master Fleet Backup (Atomic Snapshot & Retention) -> Shortcut: .\s.ps1 -bk" -ForegroundColor Green

Write-Host "  [C] " -NoNewline -ForegroundColor Yellow
Write-Host "Master Fleet Connectivity (L4/L7 & Authenticated API Probes) -> Shortcut: .\s.ps1 -chk" -ForegroundColor Yellow

Write-Host "  [S] " -NoNewline -ForegroundColor Yellow
Write-Host "Master Fleet Replication (MetaBrainz, Syncthing & SMB Mesh) -> Shortcut: .\s.ps1 -rep" -ForegroundColor Magenta

Write-Host "  [V] " -NoNewline -ForegroundColor Yellow
Write-Host "Master Fleet Verification (Health Index Certification) -> Shortcut: .\s.ps1 -v" -ForegroundColor Green

Write-Host "  [D] " -NoNewline -ForegroundColor Yellow
Write-Host "Master Deep Analysis & Expert Handoffs Generator -> Shortcut: .\s.ps1 -da" -ForegroundColor Magenta

Write-Host "  [Q] " -NoNewline -ForegroundColor DarkGray
Write-Host "Quit" -ForegroundColor DarkGray

Write-Host "`nSelect an option [0-9, F, R, B, C, S, V, D, Q]: " -NoNewline -ForegroundColor Yellow

if ($NonInteractive) {
    Write-Host "3 (Default NonInteractive: Dual-Node LCP)" -ForegroundColor Cyan
    & "$PSScriptRoot\Optimize-DualNodeLcp.ps1"
    return
}

$key = [Console]::ReadKey($true).KeyChar
Write-Host "$key`n"

switch ($key.ToString().ToUpper()) {
    "1" { & "$PSScriptRoot\Start-VoltaireUn.ps1" }
    "U" { & "$PSScriptRoot\Start-VoltaireUn.ps1" }
    "2" { & "$PSScriptRoot\Start-VoltaireDeux.ps1" }
    "D" { & "$PSScriptRoot\Start-VoltaireDeux.ps1" }
    "3" { & "$PSScriptRoot\Optimize-DualNodeLcp.ps1" }
    "L" { & "$PSScriptRoot\Optimize-DualNodeLcp.ps1" }
    "4" { & "$PSScriptRoot\Test-LocalNetworkSwitch.ps1" }
    "R" { & "$PSScriptRoot\Repair-MediaStackFleet.ps1" -All -AutoFix }
    "5" { & "$PSScriptRoot\Repair-JellyfinServer.ps1" -AutoFix }
    "J" { & "$PSScriptRoot\Repair-JellyfinServer.ps1" -AutoFix }
    "6" { & "$PSScriptRoot\Merge-OneDriveMediaStack.ps1" }
    "M" { & "$PSScriptRoot\Merge-OneDriveMediaStack.ps1" }
    "7" { & "$PSScriptRoot\Set-MediaStackHostSafeguards.ps1" }
    "P" { & "$PSScriptRoot\Set-MediaStackHostSafeguards.ps1" }
    "8" { & "$PSScriptRoot\Invoke-MediaStackMainLifecycle.ps1" }
    "A" { & "$PSScriptRoot\Invoke-MediaStackMainLifecycle.ps1" }
    "9" { & "$PSScriptRoot\Set-MediaStackNetworkUsers.ps1" }
    "N" { & "$PSScriptRoot\Set-MediaStackNetworkUsers.ps1" }
    "0" { & "$PSScriptRoot\Install-MediaStackUpdate.ps1" }
    "F" { & "$PSScriptRoot\Invoke-MediaStackFullRebootSuite.ps1" }
    "B" { & "$PSScriptRoot\Backup-MediaStackFleet.ps1" -All }
    "C" { & "$PSScriptRoot\Test-MediaStackFleetConnectivity.ps1" -All -DeepAuth }
    "S" { & "$PSScriptRoot\Replicate-MediaStackCluster.ps1" -All -RunOnce }
    "V" { & "$PSScriptRoot\Test-MediaStackFleetVerification.ps1" -All }
    "D" { & "$PSScriptRoot\Invoke-MediaStackDeepAnalysis.ps1" }
    "Q" { Write-Host "Exited." -ForegroundColor DarkGray; return }
    default {
        Write-Host "Executing default: Dual-Node LCP and Performance Optimization..." -ForegroundColor Cyan
        & "$PSScriptRoot\Optimize-DualNodeLcp.ps1"
    }
}
