# ==============================================================================
# MediaStack-Console.ps1 - Master Systems Engineering CLI Console & Operations Hub
# Unified logical management interface for Live Monitoring, Autohealing,
# Database Persistence, Read-Only Listener Access, and Disaster Recovery.
# ==============================================================================

[CmdletBinding()]
param(
    [switch]$NonInteractive
)

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::InputEncoding  = [System.Text.Encoding]::UTF8

function Show-Header {
    Clear-Host
    Write-Host "================================================================================" -ForegroundColor DarkCyan
    Write-Host "     __  ___         ___      _____ __             __                           " -ForegroundColor Cyan
    Write-Host "    /  |/  /__  ____/ (_)___ / ___// /_____ ______/ /__                         " -ForegroundColor Cyan
    Write-Host "   / /|_/ / _ \/ __  / / __ \\__ \/ __/ __ `/ ___/ //_/                         " -ForegroundColor Cyan
    Write-Host "  / /  / /  __/ /_/ / / /_/ /__/ / /_/ /_/ / /__/ ,<                            " -ForegroundColor Cyan
    Write-Host " /_/  /_/\___/\__,_/_/\__,_/____/\__/\__,_/\___/_/|_|  O P E R A T I O N S  H U B" -ForegroundColor Cyan
    Write-Host "================================================================================" -ForegroundColor DarkCyan
    Write-Host "  Node: $env:COMPUTERNAME | Stack Gateway: http://localhost (Caddy :80/:443)" -ForegroundColor DarkGray
    Write-Host "  Read-Only Listener: http://localhost/autologin | Autohealer: ACTIVE" -ForegroundColor DarkGray
    Write-Host "================================================================================" -ForegroundColor DarkCyan
}

function Show-Menu {
    Write-Host "`n  [CONTROL CENTER & LIVE MONITORING]" -ForegroundColor Yellow
    Write-Host "    [1]  Launch Multi-Display Live Operations NOC (Browser)" -ForegroundColor White
    Write-Host "    [2]  Launch Read-Only Listener Player (Instant Autologin)" -ForegroundColor White
    Write-Host "    [3]  Verify Edge Ingress & Latency Radar (test_routes)" -ForegroundColor White

    Write-Host "`n  [AUTONOMOUS SELF-HEALING & OPTIMIZATION]" -ForegroundColor Yellow
    Write-Host "    [4]  Run Autonomous Health & Auto-Repair Sweep (Invoke-StackAutoRepair)" -ForegroundColor White
    Write-Host "    [5]  Run Live Zero-Downtime Optimizer (Optimize-MediaStackLive)" -ForegroundColor White
    Write-Host "    [6]  Database Port 8080 & SQLite CRUD Optimizer (Optimize-MediaStackDatabase)" -ForegroundColor White

    Write-Host "`n  [MUSICBRAINZ DATABASE PERSISTENCE, REPLICATION & TAGGING]" -ForegroundColor Yellow
    Write-Host "    [7]  Ensure PostgreSQL Persistence & Snapshot (Ensure-MusicBrainzPersistence)" -ForegroundColor White
    Write-Host "    [8]  Sync MusicBrainz Live Replication Stream (Sync-MusicBrainzReplication)" -ForegroundColor White
    Write-Host "    [9]  Configure Picard Local Mirror & Tagging Script (Set-PicardLocalMirror)" -ForegroundColor White
    Write-Host "    [10] Test MusicBrainz Failover & Picard Target (Test-MusicBrainzMirror)" -ForegroundColor White

    Write-Host "`n  [BACKUP, PERSISTENCE & DISASTER RECOVERY]" -ForegroundColor Yellow
    Write-Host "    [11] Create Live Configuration Snapshot Archive (Backup-MediaStackConfig)" -ForegroundColor White
    Write-Host "    [12] Disaster Recovery & Golden Config Restore (Restore-MediaStackConfig)" -ForegroundColor White

    Write-Host "`n  [SYSTEM]" -ForegroundColor Yellow
    Write-Host "    [Q]  Exit Console" -ForegroundColor Red
    Write-Host "--------------------------------------------------------------------------------" -ForegroundColor DarkGray
}

if ($NonInteractive) {
    Show-Header
    Write-Host "`n[INFO] Non-interactive mode requested. Ready for pipeline execution." -ForegroundColor Green
    return
}

do {
    Show-Header
    Show-Menu
    $choice = Read-Host "  Select an operation [1-12, Q]"
    
    switch ($choice.Trim().ToUpper()) {
        "1" {
            Write-Host "`nLaunching Multi-Display Live NOC Dashboard in browser..." -ForegroundColor Cyan
            Start-Process "http://localhost/"
            Start-Sleep -Seconds 2
        }
        "2" {
            Write-Host "`nLaunching Read-Only Listener Autologin portal..." -ForegroundColor Cyan
            Start-Process "http://localhost/autologin"
            Start-Sleep -Seconds 2
        }
        "3" {
            Write-Host "`n--- Executing Edge Ingress Route Test ---" -ForegroundColor Cyan
            & "$PSScriptRoot\test_routes.ps1"
            Write-Host "`nPress Enter to return to menu..." -ForegroundColor DarkGray; Read-Host
        }
        "4" {
            Write-Host "`n--- Executing Autonomous Auto-Repair Sweep ---" -ForegroundColor Cyan
            & "$PSScriptRoot\Invoke-StackAutoRepair.ps1"
            Write-Host "`nPress Enter to return to menu..." -ForegroundColor DarkGray; Read-Host
        }
        "5" {
            Write-Host "`n--- Executing Live Zero-Downtime Optimizer ---" -ForegroundColor Cyan
            & "$PSScriptRoot\Optimize-MediaStackLive.ps1"
            Write-Host "`nPress Enter to return to menu..." -ForegroundColor DarkGray; Read-Host
        }
        "6" {
            Write-Host "`n--- Executing Database Port & CRUD Optimizer ---" -ForegroundColor Cyan
            & "$PSScriptRoot\Optimize-MediaStackDatabase.ps1"
            Write-Host "`nPress Enter to return to menu..." -ForegroundColor DarkGray; Read-Host
        }
        "7" {
            Write-Host "`n--- Verifying MusicBrainz Persistence Engine ---" -ForegroundColor Cyan
            & "$PSScriptRoot\Ensure-MusicBrainzPersistence.ps1"
            Write-Host "`nPress Enter to return to menu..." -ForegroundColor DarkGray; Read-Host
        }
        "8" {
            Write-Host "`n--- Syncing MusicBrainz Live Replication Stream ---" -ForegroundColor Cyan
            & "$PSScriptRoot\Sync-MusicBrainzReplication.ps1"
            Write-Host "`nPress Enter to return to menu..." -ForegroundColor DarkGray; Read-Host
        }
        "9" {
            Write-Host "`n--- Configuring Picard Local Mirror & Tagging Script ---" -ForegroundColor Cyan
            & "$PSScriptRoot\Set-PicardLocalMirror.ps1"
            Write-Host "`nPress Enter to return to menu..." -ForegroundColor DarkGray; Read-Host
        }
        "10" {
            Write-Host "`n--- Testing MusicBrainz Failover & Picard Target ---" -ForegroundColor Cyan
            & "$PSScriptRoot\Test-MusicBrainzMirror.ps1"
            Write-Host "`nPress Enter to return to menu..." -ForegroundColor DarkGray; Read-Host
        }
        "11" {
            Write-Host "`n--- Creating Live Configuration Snapshot Archive ---" -ForegroundColor Cyan
            & "$PSScriptRoot\Backup-MediaStackConfig.ps1"
            Write-Host "`nPress Enter to return to menu..." -ForegroundColor DarkGray; Read-Host
        }
        "12" {
            Write-Host "`n--- Initiating Disaster Recovery & Configuration Restore ---" -ForegroundColor Cyan
            & "$PSScriptRoot\Restore-MediaStackConfig.ps1"
            Write-Host "`nPress Enter to return to menu..." -ForegroundColor DarkGray; Read-Host
        }
        "Q" {
            Write-Host "`nExiting MediaStack Console. System operations continue running in background." -ForegroundColor Green
            break
        }
        Default {
            Write-Host "Invalid option. Please choose between 1 and 12, or Q." -ForegroundColor Yellow
            Start-Sleep -Seconds 1
        }
    }
} while ($true)
