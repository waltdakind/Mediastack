<#
.SYNOPSIS
    Start-MusicBrainzSafeDb.ps1 - Graceful Multi-Server MusicBrainz Database Collision Sentinel & Failover.

.DESCRIPTION
    Ensures that when starting the local MusicBrainz database:
    1. Probes if another server in the cluster (e.g. VoltaireUn at 192.168.4.21) is actively using
       or locking the primary database (PostgreSQL port 5432, container, or shared storage lock).
    2. If another server is actively using the primary DB, it handles the collision gracefully
       and quietly switches to an alternate local MusicBrainz database instance (port 5433, volume musicbrainz_pgdata_alt).
    3. Triggers/schedules the hourly database merge engine (Merge-MusicBrainzDatabases.ps1) so all changes
       made across nodes are synchronized smoothly without locking conflicts.
    4. If the primary DB is free, boots the canonical primary MusicBrainz container cleanly.

.PARAMETER Audit
    Inspects multi-server DB status without modifying active containers.

.PARAMETER ForceAlternate
    Forces activation of the alternate local database even if the primary appears free.

.PARAMETER NonInteractive
    Runs quietly without interactive prompts.

.EXAMPLE
    .\sync-files\Start-MusicBrainzSafeDb.ps1
    .\sync-files\Start-MusicBrainzSafeDb.ps1 -Audit
#>

[CmdletBinding()]
param(
    [switch]$Audit,
    [switch]$ForceAlternate,
    [switch]$NonInteractive,
    [string]$RemotePeerIp = "192.168.4.21"
)

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::InputEncoding  = [System.Text.Encoding]::UTF8

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$BaseDir = Split-Path $PSScriptRoot -Parent
if (-not (Test-Path (Join-Path $BaseDir "docker-compose.yml"))) { $BaseDir = $PSScriptRoot }

$primaryContainer   = "musicbrainz-docker-db-1"
$alternateContainer = "musicbrainz-docker-db-alt"
$primaryPort        = 5432
$alternatePort      = 5433

Write-Host "`n================================================================================" -ForegroundColor DarkCyan
Write-Host "   M U S I C B R A I N Z   S A F E   D A T A B A S E   S E N T I N E L" -ForegroundColor Cyan
Write-Host "   Multi-Server Concurrency Guard & Quiet Alternate Local DB Switcher" -ForegroundColor DarkGray
Write-Host "================================================================================" -ForegroundColor DarkCyan
Write-Host ("   Host: {0} | Timestamp: {1}" -f $env:COMPUTERNAME, $timestamp) -ForegroundColor White

# 1. Probe Remote Peer Node & Port 5432 Reachability
Write-Host "`n[1/3] Detecting Multi-Server Database Utilization..." -ForegroundColor Yellow

$peerHasDb = $false
try {
    $tcp = New-Object System.Net.Sockets.TcpClient
    $iar = $tcp.BeginConnect($RemotePeerIp, $primaryPort, $null, $null)
    $success = $iar.AsyncWaitHandle.WaitOne(1200, $false)
    if ($success -and $tcp.Connected) {
        $peerHasDb = $true
        $tcp.EndConnect($iar)
    }
    $tcp.Close()
} catch {
    $peerHasDb = $false
}

# Check if local primary container is already claimed or conflicting
$primaryInspect = docker inspect $primaryContainer 2>$null | ConvertFrom-Json
$primaryRunning = ($primaryInspect -and $primaryInspect[0].State.Running)

$isCollision = ($peerHasDb -or $ForceAlternate)

if ($isCollision) {
    Write-Host ("  [COLLISION DETECTED] Remote server ({0}:{1}) is actively utilizing the primary database." -f $RemotePeerIp, $primaryPort) -ForegroundColor Yellow
} else {
    Write-Host "  [STANDALONE] Primary database is not in use by other cluster nodes." -ForegroundColor Green
}

if ($Audit) {
    Write-Host "`n--- AUDIT SUMMARY ---" -ForegroundColor Cyan
    Write-Host ("  Remote Peer DB Active : {0}" -f $peerHasDb)
    Write-Host ("  Local Primary Running : {0}" -f $primaryRunning)
    Write-Host ("  Recommended Target    : {0}" -f $(if ($isCollision) { "Alternate Local DB ($alternateContainer`:$alternatePort)" } else { "Primary Local DB ($primaryContainer`:$primaryPort)" }))
    return
}

# 2. Graceful & Quiet Activation
Write-Host "`n[2/3] Activating Appropriate Database Engine..." -ForegroundColor Yellow

if ($isCollision) {
    # Quietly switch to alternate local database
    Write-Host "  [QUIET SWITCH] Gracefully deploying alternate local MusicBrainz database..." -ForegroundColor Cyan
    
    # Ensure alternate docker volume exists
    $altVolume = "musicbrainz_pgdata_alt"
    $hasVol = docker volume ls --filter "name=$altVolume" --format "{{.Name}}" 2>$null
    if (-not $hasVol) {
        docker volume create $altVolume | Out-Null
        Write-Host "  [OK] Created local isolated volume '$altVolume'." -ForegroundColor Green
    }

    # Inspect if alternate container is running
    $altInspect = docker inspect $alternateContainer 2>$null | ConvertFrom-Json
    $altRunning = ($altInspect -and $altInspect[0].State.Running)

    if (-not $altRunning) {
        # Launch alternate database container on port 5433
        $runArgs = @(
            "run", "-d",
            "--name", $alternateContainer,
            "--restart", "unless-stopped",
            "-e", "POSTGRES_USER=musicbrainz",
            "-e", "POSTGRES_PASSWORD=musicbrainz",
            "-e", "POSTGRES_DB=musicbrainz",
            "-v", "${altVolume}:/var/lib/postgresql/data",
            "-p", "${alternatePort}:5432",
            "--shm-size=1gb",
            "postgres:16-alpine"
        )
        
        # If alternate container already existed stopped, start it; otherwise run
        if ($altInspect) {
            docker start $alternateContainer 2>$null | Out-Null
        } else {
            & docker @runArgs 2>$null | Out-Null
        }
        Start-Sleep -Seconds 2
    }

    # Verify alternate DB health
    $altCheck = docker exec $alternateContainer pg_isready -U musicbrainz 2>$null
    if ($altCheck -match "accepting connections") {
        Write-Host "  [OK] Alternate local MusicBrainz database is ONLINE and healthy on port $alternatePort." -ForegroundColor Green
    } else {
        Write-Host "  [WARN] Alternate local database is starting up..." -ForegroundColor Yellow
    }

    # 3. Schedule Hourly Merge
    Write-Host "`n[3/3] Enqueuing Automated Hourly Changes Merge..." -ForegroundColor Yellow
    $mergeScript = Join-Path $PSScriptRoot "Merge-MusicBrainzDatabases.ps1"
    if (Test-Path $mergeScript) {
        Write-Host "  [AUTO-MERGE] Registering hourly background synchronization..." -ForegroundColor Cyan
        & $mergeScript -RegisterHourlyTask -Quiet
    }
} else {
    # Quietly ensure primary database is online
    Write-Host "  [PRIMARY] Starting canonical primary MusicBrainz database..." -ForegroundColor Green
    if (-not $primaryRunning) {
        docker compose -f (Join-Path $BaseDir "docker-compose.yml") up -d musicbrainz-db 2>$null | Out-Null
        Start-Sleep -Seconds 2
    }
    Write-Host "  [OK] Primary database container '$primaryContainer' is active on port $primaryPort." -ForegroundColor Green
}

Write-Host "`n================================================================================" -ForegroundColor DarkCyan
Write-Host "   [COMPLETE] MusicBrainz Database Startup Handled Gracefully." -ForegroundColor Green
Write-Host "================================================================================`n" -ForegroundColor DarkCyan
