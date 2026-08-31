<#
.SYNOPSIS
    s.ps1  -  MediaStack Dual-Node Master Quick Command Shortcut.

.DESCRIPTION
    Ultra-fast single-command / single-key shortcut for managing, starting, and optimizing
    both VoltaireUn (192.168.4.21) and VoltaireDeux (192.168.4.30).

.PARAMETER VoltaireUn
    Directly executes VoltaireUn Master Execution Suite (-u or -1).

.PARAMETER VoltaireDeux
    Directly executes VoltaireDeux Master Execution Suite (-d or -2).

.PARAMETER Lcp
    Directly executes Dual-Node LCP & Performance Optimization (-l or -3).

.PARAMETER Radar
    Directly runs Network Switch Radar & Service Reachability Probe (-r or -4).

.PARAMETER Repair
    Directly runs Jellyfin Self-Healing & Diagnostic Engine (-j or -5).

.PARAMETER Sync
    Directly runs Cluster Sync & OneDrive Merge (-m or -6).

.EXAMPLE
    .\s.ps1            # Opens interactive single-key menu
    .\s.ps1 -u         # Launches VoltaireUn Main Server
    .\s.ps1 -d         # Launches VoltaireDeux AI Workstation
    .\s.ps1 -l         # Optimizes LCP & Performance on Both Servers
#>

[CmdletBinding()]
param(
    [Alias("u", "1")][switch]$VoltaireUn,
    [Alias("d", "2")][switch]$VoltaireDeux,
    [Alias("l", "3")][switch]$Lcp,
    [Alias("r", "4")][switch]$Radar,
    [Alias("j", "5")][switch]$Repair,
    [Alias("m", "6")][switch]$Sync,
    [Parameter(Mandatory = $false)][switch]$NonInteractive
)

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

# Interactive Single-Key HUD Menu
Clear-Host
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "   M E D I A S T A C K   D U A L - N O D E   M A S T E R   S H O R T C U T" -ForegroundColor DarkCyan
Write-Host "   VoltaireUn (192.168.4.21) <===================> VoltaireDeux (192.168.4.30)" -ForegroundColor White
Write-Host "================================================================================" -ForegroundColor Cyan

Write-Host "`n  [1] " -NoNewline -ForegroundColor Yellow
Write-Host "Start VoltaireUn (Main 24/7 Server)           -> Shortcut: .\s-v1.ps1 or s-v1" -ForegroundColor White

Write-Host "  [2] " -NoNewline -ForegroundColor Yellow
Write-Host "Start VoltaireDeux (AI Node & Workstation)    -> Shortcut: .\s-v2.ps1 or s-v2" -ForegroundColor White

Write-Host "  [3] " -NoNewline -ForegroundColor Yellow
Write-Host "Optimize LCP & Latency Across BOTH Servers    -> Shortcut: .\s.ps1 -l" -ForegroundColor Cyan

Write-Host "  [4] " -NoNewline -ForegroundColor Yellow
Write-Host "Run Network Switch Radar & Reachability Check -> Shortcut: .\s.ps1 -r" -ForegroundColor White

Write-Host "  [5] " -NoNewline -ForegroundColor Yellow
Write-Host "Run Jellyfin Self-Healing & Diagnostic Engine -> Shortcut: .\s.ps1 -j" -ForegroundColor White

Write-Host "  [6] " -NoNewline -ForegroundColor Yellow
Write-Host "Synchronize & Reconcile Cluster (OneDrive)    -> Shortcut: .\s.ps1 -m" -ForegroundColor White

Write-Host "  [Q] " -NoNewline -ForegroundColor DarkGray
Write-Host "Quit" -ForegroundColor DarkGray

Write-Host "`nSelect an option [1-6, Q]: " -NoNewline -ForegroundColor Yellow

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
    "R" { & "$PSScriptRoot\Test-LocalNetworkSwitch.ps1" }
    "5" { & "$PSScriptRoot\Repair-JellyfinServer.ps1" -AutoFix }
    "J" { & "$PSScriptRoot\Repair-JellyfinServer.ps1" -AutoFix }
    "6" { & "$PSScriptRoot\Merge-OneDriveMediaStack.ps1" }
    "M" { & "$PSScriptRoot\Merge-OneDriveMediaStack.ps1" }
    "Q" { Write-Host "Exited." -ForegroundColor DarkGray; return }
    default {
        Write-Host "Executing default: Dual-Node LCP & Performance Optimization..." -ForegroundColor Cyan
        & "$PSScriptRoot\Optimize-DualNodeLcp.ps1"
    }
}
