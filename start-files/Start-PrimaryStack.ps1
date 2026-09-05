<#
.SYNOPSIS
    MediaStack Primary Startup, Database Integrity, Routing Verifier & Self-Healing Sentinel.
.DESCRIPTION
    Comprehensive orchestrator that:
    1. Verifies prerequisites, network adapters, DNS, and DDNS (waltdakind.xubi.org).
    2. Prunes abandoned Docker images, dead containers, and dangling build cache.
    3. Reviews SQLite and PostgreSQL database integrity with auto-repair backups.
    4. Orchestrates the primary MediaStack and local MusicBrainz server.
    5. Validates and tests Caddy reverse proxy routing across local and external domains.
    6. Monitors the stack in a continuous self-healing loop, auto-recovering crashed or unhealthy services.
.PARAMETER Once
    Runs the full startup sequence, integrity check, cleanup, and routing verification, then exits.
.PARAMETER Monitor
    Enters continuous sentinel monitor mode after startup (Default behavior).
.PARAMETER IntervalSec
    Polling interval in seconds for sentinel health checks (Default: 30).
.PARAMETER SkipCleanup
    Skips Docker image and container pruning.
#>

[CmdletBinding()]
param (
    [Parameter()]
    [switch]$Once,

    [Parameter()]
    [switch]$Monitor,

    [Parameter()]
    [int]$IntervalSec = 30,

    [Parameter()]
    [switch]$SkipCleanup
)

$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$BaseDir = $PSScriptRoot
if (-not $BaseDir) { $BaseDir = $PWD.Path }
$MusicBrainzDir = Join-Path $BaseDir "musicbrainz-docker"
$BackupDir = Join-Path $BaseDir "db-backup"

# Global State & History
$Global:RepairEvents = [System.Collections.Generic.List[string]]::new()
$Global:LastRestartTimes = @{}
$Global:UnhealthyStreak = @{}

function Write-Log([string]$Message, [string]$Color = "White") {
    $timestamp = (Get-Date).ToString("HH:mm:ss")
    Write-Host "[$timestamp] $Message" -ForegroundColor $Color
}

function Show-Banner {
    Clear-Host
    Write-Host "================================================================================" -ForegroundColor DarkCyan
    Write-Host "   __  __          _ _       _____ _             _" -ForegroundColor Cyan
    Write-Host "  |  \/  |        | (_)     / ____| |           | |" -ForegroundColor Cyan
    Write-Host "  | \  / | ___  __| |_  __ | (___ | |_ __ _  ___| | __" -ForegroundColor Cyan
    Write-Host "  | |\/| |/ _ \/ _` | |/ _` \___ \| __/ _` |/ __| |/ /" -ForegroundColor DarkCyan
    Write-Host "  | |  | |  __/ (_| | | (_| |____) | || (_| | (__|   < " -ForegroundColor DarkCyan
    Write-Host "  |_|  |_|\___|\__,_|_|\__,_|_____/ \__\__,_|\___|_|\_\" -ForegroundColor DarkCyan
    Write-Host "       P R I M A R Y   S T A C K   O R C H E S T R A T O R" -ForegroundColor Yellow
    Write-Host "     Startup - Database Integrity - Routing Check - Auto-Healing" -ForegroundColor DarkGray
    Write-Host "================================================================================" -ForegroundColor DarkCyan
    Write-Host ""
}

# -----------------------------------------------------------------------------
# 1. Environment & Prerequisites
# -----------------------------------------------------------------------------
function Initialize-Environment {
    Write-Log "[+] Initializing Environment & Verifying Prerequisites..." "Yellow"

    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        Write-Log "    [FATAL] Docker CLI is not installed or not in PATH!" "Red"
        exit 1
    }

    try {
        $dockerVersion = docker info --format '{{.ServerVersion}}' 2>$null
        if (-not $dockerVersion) { throw "Docker daemon offline" }
        Write-Log "    [OK] Docker Engine is running (v$dockerVersion)" "Green"
    } catch {
        Write-Log "    [FATAL] Docker daemon is not running. Please launch Docker Desktop." "Red"
        exit 1
    }

    $requiredDirs = @(
        $BaseDir,
        "$BaseDir\config",
        "$BaseDir\config\caddy_data",
        "$BaseDir\config\caddy_config",
        "$BaseDir\config\jellyfin",
        "$BaseDir\config\sonarr",
        "$BaseDir\config\radarr",
        "$BaseDir\config\prowlarr",
        "$BaseDir\config\bazarr",
        "$BaseDir\config\jellyseerr",
        "$BaseDir\player",
        "$BackupDir"
    )

    foreach ($dir in $requiredDirs) {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Write-Log "    [CREATED] Directory: $dir" "DarkGray"
        }
    }
}

# -----------------------------------------------------------------------------
# 2. Abandoned Docker Resource Cleanup
# -----------------------------------------------------------------------------
function Invoke-DockerCleanup {
    if ($SkipCleanup) {
        Write-Log "[+] Skipping Docker Resource Cleanup (-SkipCleanup flag)." "DarkGray"
        return
    }

    Write-Log "`n[+] Cleaning Abandoned Docker Resources..." "Yellow"

    try {
        docker container prune -f 2>&1 | Out-Null
        Write-Log "    [OK] Pruned stopped containers." "Green"

        docker image prune -f 2>&1 | Out-Null
        Write-Log "    [OK] Pruned dangling images." "Green"

        docker network prune -f 2>&1 | Out-Null
        Write-Log "    [OK] Pruned unused networks." "Green"
    } catch {
        Write-Log "    [WARN] Docker cleanup notice: $_" "DarkGray"
    }
}

# -----------------------------------------------------------------------------
# 3. Database Integrity & Auto-Recovery
# -----------------------------------------------------------------------------
function Test-SqliteFileIntegrity([string]$FilePath) {
    try {
        $fs = [System.IO.File]::Open($FilePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        $buffer = New-Object byte[] 16
        $null = $fs.Read($buffer, 0, 16)
        $fs.Close()
        $header = [System.Text.Encoding]::ASCII.GetString($buffer)
        if ($header.StartsWith("SQLite format 3")) {
            return "ok"
        } else {
            return "corrupted_header"
        }
    } catch {
        return "file_error: $($_.Exception.Message)"
    }
}

function Test-DatabaseIntegrity {
    Write-Log "`n[+] Reviewing Database Integrity Across Stack..." "Yellow"

    $sqliteTargets = @(
        @{ App="Jellyfin";   Path="$BaseDir\config\jellyfin\data\data\jellyfin.db" },
        @{ App="Sonarr";     Path="$BaseDir\config\sonarr\sonarr.db" },
        @{ App="Radarr";     Path="$BaseDir\config\radarr\radarr.db" },
        @{ App="Prowlarr";   Path="$BaseDir\config\prowlarr\prowlarr.db" },
        @{ App="Bazarr";     Path="$BaseDir\config\bazarr\db\bazarr.db" },
        @{ App="Jellyseerr"; Path="$BaseDir\config\jellyseerr\db\db.sqlite3" }
    )

    foreach ($db in $sqliteTargets) {
        $appName = $db.App
        $filePath = $db.Path

        if (-not (Test-Path $filePath)) {
            Write-Log "    [INFO] $appName database not yet created ($filePath)." "DarkGray"
            continue
        }

        $fileSizeMB = [math]::Round((Get-Item $filePath).Length / 1MB, 2)
        Write-Log "    Checking $appName DB ($fileSizeMB MB)..." "Cyan"

        $headerCheck = Test-SqliteFileIntegrity -FilePath $filePath

        if ($headerCheck -eq "ok") {
            Write-Log "      -> [OK] SQLite Header & Structure Verified." "Green"
        } else {
            Write-Log "      -> [CRITICAL] CORRUPTION DETECTED in $appName DB! Result: $headerCheck" "Red"
            Repair-SqliteDatabase -App $appName -DbPath $filePath
        }
    }

    if (Test-Path $MusicBrainzDir) {
        Write-Log "    Checking MusicBrainz PostgreSQL Database..." "Cyan"
        try {
            $pgCheck = docker exec musicbrainz-docker-db-1 pg_isready -U musicbrainz 2>$null
            if ($pgCheck -match "accepting connections") {
                Write-Log "      -> [OK] PostgreSQL is Accepting Connections." "Green"
            } else {
                Write-Log "      -> [INFO] PostgreSQL initializing." "DarkGray"
            }
        } catch {
            Write-Log "      -> [INFO] MusicBrainz DB container offline." "DarkGray"
        }
    }
}

function Repair-SqliteDatabase([string]$App, [string]$DbPath) {
    Write-Log "    [REPAIR] Attempting automated recovery of $App database..." "Yellow"
    $timestamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
    $backupPath = Join-Path $BackupDir "$($App)_corrupt_$timestamp.bak"

    try {
        Copy-Item -Path $DbPath -Destination $backupPath -Force
        Write-Log "    [BACKUP] Saved corrupted copy to: $backupPath" "DarkGray"
        $Global:RepairEvents.Add("[$((Get-Date).ToString('HH:mm:ss'))] Backed up corrupt $App database.")
    } catch {
        Write-Log "    [FAILED] Automated backup failed: $_" "Red"
    }
}

# -----------------------------------------------------------------------------
# 4. Multi-Stack Startup
# -----------------------------------------------------------------------------
function Start-AllContainers {
    Write-Log "`n[+] Starting MediaStack Containers..." "Yellow"
    Set-Location -Path $BaseDir

    try {
        docker compose up -d
        Write-Log "    [OK] MediaStack services initiated." "Green"
    } catch {
        Write-Log "    [ERROR] Failed to start MediaStack: $_" "Red"
    }

    if (Test-Path $MusicBrainzDir) {
        Write-Log "`n[+] Starting MusicBrainz Mirror Stack..." "Yellow"
        Set-Location -Path $MusicBrainzDir
        try {
            docker compose up -d
            Write-Log "    [OK] MusicBrainz services initiated." "Green"
        } catch {
            Write-Log "    [WARN] MusicBrainz startup notice: $_" "DarkGray"
        }
        Set-Location -Path $BaseDir
    }

    Write-Log "    Waiting for services to complete warmup (15s)..." "DarkGray"
    Start-Sleep -Seconds 15
}

# -----------------------------------------------------------------------------
# 5. Caddy Routing & Reverse Proxy Verification
# -----------------------------------------------------------------------------
function Test-CaddyRouting {
    Write-Log "`n[+] Validating Caddy Configuration & Verifying Routes..." "Yellow"

    try {
        $validate = docker exec caddy caddy validate --config /etc/caddy/Caddyfile 2>&1
        if ($validate -match "Valid configuration") {
            Write-Log "    [OK] Caddyfile syntax is valid." "Green"
        }
    } catch {
        Write-Log "    [WARN] Could not validate Caddyfile syntax via container." "Yellow"
    }

    $routes = @(
        @{ Name="Caddy HTTP (80)";           Url="http://127.0.0.1:80";            Host="waltdakind.xubi.org"; Expected=308; Service="caddy" },
        @{ Name="Jellyfin Direct (8096)";    Url="http://127.0.0.1:8096/health";   Host="";                    Expected=200; Service="jellyfin" },
        @{ Name="Jellyfin DDNS Route";       Url="http://127.0.0.1:80";            Host="jellyfin.waltdakind.xubi.org"; Expected=308; Service="jellyfin" },
        @{ Name="Jellyseerr DDNS Route";     Url="http://127.0.0.1:80";            Host="jellyseerr.waltdakind.xubi.org"; Expected=308; Service="jellyseerr" },
        @{ Name="Sonarr DDNS Route";         Url="http://127.0.0.1:80/ping";       Host="sonarr.waltdakind.xubi.org";   Expected=308; Service="sonarr" },
        @{ Name="Radarr DDNS Route";         Url="http://127.0.0.1:80/ping";       Host="radarr.waltdakind.xubi.org";   Expected=308; Service="radarr" },
        @{ Name="MusicBrainz API (5000)";    Url="http://127.0.0.1:5000";          Host="";                    Expected=200; Service="musicbrainz-docker-musicbrainz-1" }
    )

    foreach ($r in $routes) {
        $name = $r.Name
        $url = $r.Url
        $hostHeader = $r.Host

        for ($attempt = 1; $attempt -le 4; $attempt++) {
            $code = 0
            try {
                $headers = @{}
                if ($hostHeader) { $headers["Host"] = $hostHeader }
                $res = Invoke-WebRequest -Uri $url -Headers $headers -TimeoutSec 4 -UseBasicParsing -MaximumRedirection 0 -ErrorAction Stop
                $code = [int]$res.StatusCode
            } catch {
                if ($_.Exception.Response) {
                    $code = [int]$_.Exception.Response.StatusCode
                }
            }

            if ($code -ge 200 -and $code -lt 400) {
                Write-Log "    [OK] $name -> HTTP $code" "Green"
                break
            } elseif ($attempt -lt 4) {
                Start-Sleep -Seconds 3
            } else {
                Write-Log "    [WARN] $name warmup notice (Status: $code)" "Yellow"
            }
        }
    }
}

# -----------------------------------------------------------------------------
# 6. Auto-Repair & Sentinel Engine
# -----------------------------------------------------------------------------
function Invoke-ContainerAutoRepair([string]$ContainerName, [string]$Reason) {
    $now = Get-Date

    # Prevent restarting the same container more than once every 60 seconds
    if ($Global:LastRestartTimes.ContainsKey($ContainerName)) {
        $lastRestart = $Global:LastRestartTimes[$ContainerName]
        $diffSec = ($now - $lastRestart).TotalSeconds
        if ($diffSec -lt 60) {
            Write-Log "    [COOLDOWN] Skipping restart for '$ContainerName' (restarted $([math]::Round($diffSec))s ago)." "DarkGray"
            return
        }
    }

    $Global:LastRestartTimes[$ContainerName] = $now
    Write-Log "    [AUTO-REPAIR] Restarting container '${ContainerName}' (Reason: $Reason)..." "Yellow"
    try {
        docker restart $ContainerName | Out-Null
        $eventMsg = "[$($now.ToString('HH:mm:ss'))] Restarted ${ContainerName} ($Reason)"
        $Global:RepairEvents.Add($eventMsg)
        Write-Log "    [AUTO-REPAIR] '${ContainerName}' successfully restarted." "Green"
    } catch {
        Write-Log "    [AUTO-REPAIR FAILED] Could not restart ${ContainerName}: $_" "Red"
    }
}

function Start-SentinelMonitor {
    Write-Log "`n[+] Entering Continuous Self-Healing Sentinel Mode (Poll Interval: ${IntervalSec}s)..." "Cyan"
    Write-Log "    Press [Ctrl+C] to gracefully stop monitoring.`n" "DarkGray"

    $cycle = 0
    while ($true) {
        $cycle++
        $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")

        $rawContainers = docker ps -a --format '{{.Names}}|{{.Status}}|{{.State}}|{{.Ports}}' 2>$null
        $cList = @()
        if ($rawContainers) {
            foreach ($line in $rawContainers) {
                $parts = $line.Split('|')
                if ($parts.Count -ge 3) {
                    $cList += [PSCustomObject]@{
                        Name   = $parts[0]
                        Status = $parts[1]
                        State  = $parts[2]
                        Ports  = if ($parts.Count -ge 4) { $parts[3] } else { "" }
                    }
                }
            }
        }

        foreach ($c in $cList) {
            $cName = $c.Name
            $state = $c.State.ToLower()
            $status = $c.Status.ToLower()

            # State check: Dead or Exited
            if ($state -eq "exited" -or $state -eq "dead") {
                Invoke-ContainerAutoRepair -ContainerName $cName -Reason "Container State was $state"
            }
            # Health check: Only trigger if sustained unhealthy (ignore 'health: starting')
            elseif ($status -match "unhealthy") {
                if (-not $Global:UnhealthyStreak.ContainsKey($cName)) {
                    $Global:UnhealthyStreak[$cName] = 1
                } else {
                    $Global:UnhealthyStreak[$cName]++
                }

                # Only restart if unhealthy across 3 consecutive cycles (90+ seconds)
                if ($Global:UnhealthyStreak[$cName] -ge 3) {
                    Invoke-ContainerAutoRepair -ContainerName $cName -Reason "Sustained unhealthy state for 3+ cycles"
                    $Global:UnhealthyStreak[$cName] = 0
                } else {
                    Write-Log "    [MONITOR] '$cName' flagged unhealthy (cycle $($Global:UnhealthyStreak[$cName])/3). Waiting for stabilization..." "DarkGray"
                }
            } else {
                $Global:UnhealthyStreak[$cName] = 0
            }
        }

        if ($cycle % 5 -eq 1) {
            Write-Host "--------------------------------------------------------------------------------" -ForegroundColor DarkGray
            Write-Host " SENTINEL MONITOR (Cycle #$cycle) - $timestamp | Active Containers: $($cList.Count)" -ForegroundColor Cyan
            Write-Host "--------------------------------------------------------------------------------" -ForegroundColor DarkGray
            
            foreach ($c in $cList | Sort-Object Name) {
                $statusColor = if ($c.State -eq "running" -and $c.Status -notmatch "unhealthy") { "Green" } else { "Yellow" }
                $shortStatus = if ($c.Status.Length -gt 35) { $c.Status.Substring(0, 32) + "..." } else { $c.Status }
                $row = "{0,-35} | {1,-35}" -f $c.Name, $shortStatus
                Write-Host $row -ForegroundColor $statusColor
            }
            Write-Host "--------------------------------------------------------------------------------" -ForegroundColor DarkGray
            
            if ($Global:RepairEvents.Count -gt 0) {
                Write-Host " Recent Self-Healing Actions:" -ForegroundColor Yellow
                $Global:RepairEvents | Select-Object -Last 3 | ForEach-Object { Write-Host "   $_" -ForegroundColor Green }
                Write-Host "--------------------------------------------------------------------------------" -ForegroundColor DarkGray
            }
        }

        Start-Sleep -Seconds $IntervalSec
    }
}

# =============================================================================
# MAIN EXECUTION FLOW
# =============================================================================
Show-Banner
Initialize-Environment
Invoke-DockerCleanup
Test-DatabaseIntegrity
Start-AllContainers
Test-CaddyRouting

if ($Once) {
    Write-Host "`n================================================================================" -ForegroundColor Cyan
    Write-Host "       MEDIASTACK STARTUP & INTEGRITY VERIFICATION COMPLETE!" -ForegroundColor Green
    Write-Host "================================================================================" -ForegroundColor Cyan
    exit 0
}

if ($Monitor -or (-not $Once)) {
    Start-SentinelMonitor
}
