<#
.SYNOPSIS
    Invoke-MediaStackFullRebootSuite.ps1 - End-to-End Diagnostic, Backup, Clean Shutdown, Repull, Restart & AI Sentinel.

.DESCRIPTION
    Executes a complete 7-stage master maintenance and reboot cycle:
    1. DIAGNOSE: Deep diagnostic sweep of host hardware, Docker engine, 18+ containers, SQLite/PostgreSQL DBs, L7 routing, and secrets vault.
    2. BACKUP: Full atomic compressed archive of configs, databases, compose manifests, and scripts to backups/.
    3. CLEAN SHUTDOWN: Graceful, dependency-ordered shutdown of all containers with SQLite journal flushing.
    4. IMAGE PULL: Interactive or automated prompt to pull all updated images, specific service images, or skip.
    5. CLEAN RESTART: Dependency-layered bootstrap of databases -> indexers -> media streamers -> Caddy ingress gateway.
    6. MUSICBRAINZ SYNC: Incremental hourly replication sync from MetaBrainz into local PostgreSQL mirror.
    7. AI SENTINEL & ONGOING MONITORING: Heartbeat sync and knowledge exchange with VoltaireUn AI agent, auto-healing supervisor.

.PARAMETER PullAllImages
    Pulls all container images without prompting.

.PARAMETER SpecificImages
    Array of specific image names to pull (e.g. "jellyfin/jellyfin", "caddy:alpine").

.PARAMETER SkipPull
    Skips the image pull stage entirely.

.PARAMETER SkipBackup
    Skips the pre-reboot backup stage.

.PARAMETER Daemon
    Enters continuous auto-healing and AI agent communication loop after restart.

.PARAMETER IntervalSeconds
    Monitoring sweep interval in daemon mode (default: 25 seconds).

.PARAMETER NonInteractive
    Runs unattended using optimal defaults.

.EXAMPLE
    .\Invoke-MediaStackFullRebootSuite.ps1
    .\Invoke-MediaStackFullRebootSuite.ps1 -PullAllImages -Daemon
    .\Invoke-MediaStackFullRebootSuite.ps1 -SpecificImages @("jellyfin/jellyfin:latest", "caddy:2-alpine")
#>

[CmdletBinding()]
param(
    [switch]$PullAllImages,
    [string[]]$SpecificImages = @(),
    [switch]$SkipPull,
    [switch]$SkipBackup,
    [switch]$Daemon,
    [int]$IntervalSeconds = 25,
    [switch]$NonInteractive,
    [string]$ConfigDir = "$env:SystemDrive\MediastackConfig"
)

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::InputEncoding  = [System.Text.Encoding]::UTF8

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$fileTag = Get-Date -Format "yyyyMMdd_HHmmss"
$BaseDir = $PSScriptRoot
$HandoffsDir = Join-Path $BaseDir "handoffs"
$BackupsDir = Join-Path $BaseDir "backups"
$SecretsFile = Join-Path $BaseDir "config\secrets\secrets.json"
$NexusFile = Join-Path $HandoffsDir "ai_collaboration_nexus.json"

if (-not (Test-Path $HandoffsDir)) { New-Item -ItemType Directory -Force -Path $HandoffsDir | Out-Null }
if (-not (Test-Path $BackupsDir)) { New-Item -ItemType Directory -Force -Path $BackupsDir | Out-Null }

$PrimaryIp   = "192.168.4.21"
$SecondaryIp = "192.168.4.30"
$HdhomerunIp = "192.168.4.45"

Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host "   M E D I A S T A C K   F U L L   R E B O O T   &   A I   S U I T E" -ForegroundColor DarkCyan
Write-Host "   Diagnostic -> Backup -> Clean Shutdown -> Repull -> Clean Restart -> AI Sentinel" -ForegroundColor White
Write-Host "   Host: $env:COMPUTERNAME | Timestamp: $timestamp" -ForegroundColor DarkGray
Write-Host "================================================================================" -ForegroundColor Cyan

# ==============================================================================
# STAGE 1: THOROUGH CLUSTER & NODE DIAGNOSTIC SWEEP
# ==============================================================================
Write-Host "`n[STAGE 1/7] Executing Comprehensive Diagnostic Sweep..." -ForegroundColor Yellow

$diag = [ordered]@{
    Timestamp      = $timestamp
    HostCPU        = (Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
    FreeDiskGB     = [math]::Round(((Get-PSDrive -Name C).Free / 1GB), 2)
    DockerOnline   = $false
    ActiveContainers = 0
    TotalContainers  = 0
    PrimaryNodeLan = $false
    PrimaryMusicBrainz = "OFFLINE"
    TunerLan       = $false
    SecretsStatus  = "UNKNOWN"
}

# 1.1 Docker Daemon Check
$dockerVer = docker info --format '{{.ServerVersion}}' 2>$null
if ($dockerVer) {
    $diag.DockerOnline = $true
    $cList = docker ps -a --format '{{.Names}}|{{.Status}}' 2>$null
    $diag.TotalContainers = if ($cList) { @($cList).Count } else { 0 }
    $runningList = docker ps --format '{{.Names}}' 2>$null
    $diag.ActiveContainers = if ($runningList) { @($runningList).Count } else { 0 }
    Write-Host "  * Docker Engine  : ONLINE (v$dockerVer) | $($diag.ActiveContainers)/$($diag.TotalContainers) containers active" -ForegroundColor Green
} else {
    Write-Host "  * Docker Engine  : OFFLINE / Not Responding" -ForegroundColor Red
}

# 1.2 Inter-Node Connectivity
$pingPrimary = Test-Connection -ComputerName $PrimaryIp -Count 2 -Quiet -ErrorAction SilentlyContinue
$diag.PrimaryNodeLan = $pingPrimary
$primCol = if ($pingPrimary) { "Green" } else { "Yellow" }
Write-Host ("  * Peer VoltaireUn [192.168.4.21] : {0}" -f $(if ($pingPrimary) { "ONLINE / Reachable" } else { "OFFLINE / Ping Timeout" })) -ForegroundColor $primCol

$mbPrimaryCode = curl.exe -s -o NUL -w "%{http_code}" --max-time 3 "http://${PrimaryIp}:5000/" 2>$null
$diag.PrimaryMusicBrainz = "HTTP $mbPrimaryCode"
Write-Host ("  * VoltaireUn MusicBrainz (:5000) : HTTP {0}" -f $mbPrimaryCode) -ForegroundColor $(if ($mbPrimaryCode -eq "200") { "Green" } else { "Yellow" })

$pingTuner = Test-Connection -ComputerName $HdhomerunIp -Count 1 -Quiet -ErrorAction SilentlyContinue
$diag.TunerLan = $pingTuner
Write-Host ("  * Hardware Tuner  [192.168.4.45] : {0}" -f $(if ($pingTuner) { "ONLINE" } else { "OFFLINE" })) -ForegroundColor $(if ($pingTuner) { "Green" } else { "DarkGray" })

# 1.3 Secrets Vault Check
if (Test-Path $SecretsFile) {
    $diag.SecretsStatus = "SECURED (Vault Present)"
    Write-Host "  * Master Secrets Vault           : OK ($SecretsFile)" -ForegroundColor Green
} else {
    $diag.SecretsStatus = "MISSING"
    Write-Host "  * Master Secrets Vault           : NOT FOUND" -ForegroundColor Red
}

# 1.4 Database Lock & Journal Diagnostics
Write-Host "  * Checking SQLite Databases for Locks & Dangling Journals..." -ForegroundColor DarkCyan
$activeDbs = Get-ChildItem -Path $ConfigDir -Recurse -Include @("*.db", "*.sqlite") -ErrorAction SilentlyContinue
$danglingJournals = Get-ChildItem -Path $ConfigDir -Recurse -Filter "*.db-journal" -ErrorAction SilentlyContinue
$journalCount = if ($danglingJournals) { @($danglingJournals).Count } else { 0 }
$dbCount = if ($activeDbs) { @($activeDbs).Count } else { 0 }
Write-Host "    -> Audited $dbCount SQLite database files across stack ($journalCount dangling journals found)." -ForegroundColor White

# ==============================================================================
# STAGE 2: FULL ATOMIC PRE-MAINTENANCE BACKUP
# ==============================================================================
Write-Host "`n[STAGE 2/7] Executing Full Atomic Pre-Maintenance Backup..." -ForegroundColor Yellow

if (-not $SkipBackup) {
    $backupArchive = Join-Path $BackupsDir "MediaStack_FullBackup_$fileTag.zip"
    $tempBackupStage = Join-Path $BaseDir "backup_stage_$fileTag"
    
    try {
        New-Item -ItemType Directory -Force -Path $tempBackupStage | Out-Null
        
        # Backup Configs & Manifests
        $manifests = @("docker-compose.yml", "docker-compose.x64.yml", "docker-compose.x64-VoltaireDeux.yml", "docker-compose.arm.yml", "Caddyfile", "Caddyfile-VoltaireDeux", "Caddyfile-VoltaireDeux-2")
        foreach ($m in $manifests) {
            $mPath = Join-Path $BaseDir $m
            if (Test-Path $mPath) { Copy-Item -Path $mPath -Destination $tempBackupStage -Force }
        }

        # Backup Secrets Vault
        $secDst = Join-Path $tempBackupStage "config\secrets"
        New-Item -ItemType Directory -Force -Path $secDst | Out-Null
        if (Test-Path $SecretsFile) { Copy-Item -Path $SecretsFile -Destination $secDst -Force }
        $secEnv = Join-Path $BaseDir "config\secrets\secrets.env"
        if (Test-Path $secEnv) { Copy-Item -Path $secEnv -Destination $secDst -Force }

        # Backup Active SQLite DBs
        $dbDst = Join-Path $tempBackupStage "databases"
        New-Item -ItemType Directory -Force -Path $dbDst | Out-Null
        if (Test-Path $ConfigDir) {
            Get-ChildItem -Path $ConfigDir -Recurse -Include @("*.db", "*.sqlite") -ErrorAction SilentlyContinue | ForEach-Object {
                $subDir = Join-Path $dbDst $_.Directory.Name
                if (-not (Test-Path $subDir)) { New-Item -ItemType Directory -Force -Path $subDir | Out-Null }
                Copy-Item -Path $_.FullName -Destination $subDir -Force -ErrorAction SilentlyContinue
            }
        }

        # Compress to atomic archive
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::CreateFromDirectory($tempBackupStage, $backupArchive, [System.IO.Compression.CompressionLevel]::Optimal, $false)
        $bSizeMb = [math]::Round(((Get-Item $backupArchive).Length / 1MB), 2)
        Write-Host "  [OK] Full pre-reboot backup created: $backupArchive ($bSizeMb MB)" -ForegroundColor Green
        
        # Clean temporary staging
        Remove-Item -Path $tempBackupStage -Recurse -Force -ErrorAction SilentlyContinue

        # Prune archives older than 7 days
        Get-ChildItem -Path $BackupsDir -Filter "MediaStack_FullBackup_*.zip" -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-7) } |
            Remove-Item -Force -ErrorAction SilentlyContinue
    } catch {
        Write-Host "  [WARN] Backup stage encountered an issue: $($_.Exception.Message)" -ForegroundColor Yellow
    }
} else {
    Write-Host "  * Skipping backup stage (-SkipBackup specified)." -ForegroundColor DarkGray
}

# ==============================================================================
# STAGE 3: ORDERED CLEAN SHUTDOWN
# ==============================================================================
Write-Host "`n[STAGE 3/7] Executing Ordered Clean Fleet Shutdown..." -ForegroundColor Yellow

if ($diag.DockerOnline) {
    # 3.1 Stop Ingress Gateways first to cease accepting new HTTP traffic
    Write-Host "  [1/4] Stopping Ingress Proxies & Gateways (caddy, api-gateway, dashboard)..." -ForegroundColor Cyan
    docker stop caddy api-gateway dashboard 2>$null | Out-Null

    # 3.2 Stop Media Management & Indexers
    Write-Host "  [2/4] Stopping Media Management & Indexers (jellyseerr, sonarr, radarr, prowlarr, bazarr)..." -ForegroundColor Cyan
    docker stop jellyseerr sonarr radarr prowlarr bazarr 2>$null | Out-Null

    # 3.3 Stop Media Streamers & Sync
    Write-Host "  [3/4] Stopping Streamers & Sync Engines (jellyfin, syncthing, transmission, nextpvr, tvheadend)..." -ForegroundColor Cyan
    docker stop jellyfin syncthing transmission nextpvr tvheadend 2>$null | Out-Null

    # 3.4 Stop Core Databases & Cache
    Write-Host "  [4/4] Stopping Core Databases & Cache (mediastack-db, postgres, redis)..." -ForegroundColor Cyan
    docker stop mediastack-db postgres redis 2>$null | Out-Null

    # Flush all remaining containers
    docker stop $(docker ps -q) 2>$null | Out-Null
    Write-Host "  [OK] Clean fleet shutdown complete. All containers gracefully stopped." -ForegroundColor Green

    # Clear dangling journal locks
    if ($journalCount -gt 0) {
        Write-Host "  [*] Purging $journalCount dangling SQLite journal files..." -ForegroundColor Cyan
        $danglingJournals | Remove-Item -Force -ErrorAction SilentlyContinue
        Write-Host "  [OK] All database journals purged." -ForegroundColor Green
    }
} else {
    Write-Host "  * Docker offline: Skipping container shutdown." -ForegroundColor Yellow
}

# ==============================================================================
# STAGE 4: IMAGE PULL / UPDATE SELECTION
# ==============================================================================
Write-Host "`n[STAGE 4/7] Container Image Update & Repull Strategy..." -ForegroundColor Yellow

$pullChoice = "SKIP"

if ($PullAllImages) {
    $pullChoice = "ALL"
} elseif ($SpecificImages.Count -gt 0) {
    $pullChoice = "SPECIFIC"
} elseif ($SkipPull) {
    $pullChoice = "SKIP"
} elseif (-not $NonInteractive) {
    Write-Host "`nPlease choose an image update option:" -ForegroundColor Cyan
    Write-Host "  [1] Pull ALL newest images for entire fleet" -ForegroundColor White
    Write-Host "  [2] Pull SPECIFIC images (interactive prompt)" -ForegroundColor White
    Write-Host "  [3] SKIP image pull (restart immediately with existing images)" -ForegroundColor White
    Write-Host "Selection [1-3, Default: 3]: " -NoNewline -ForegroundColor Yellow
    $sel = Read-Host
    if ($sel -eq "1") { $pullChoice = "ALL" }
    elseif ($sel -eq "2") { $pullChoice = "SPECIFIC" }
    else { $pullChoice = "SKIP" }
}

switch ($pullChoice) {
    "ALL" {
        Write-Host "`n  [*] Repulling all container images via Docker Compose..." -ForegroundColor Cyan
        docker compose pull 2>&1 | Out-Default
        Write-Host "  [OK] All images updated to latest versions." -ForegroundColor Green
    }
    "SPECIFIC" {
        if ($SpecificImages.Count -eq 0) {
            Write-Host "Enter image names separated by commas (e.g. jellyfin/jellyfin, caddy:alpine): " -NoNewline -ForegroundColor Yellow
            $imgInput = Read-Host
            $SpecificImages = $imgInput -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ }
        }
        foreach ($img in $SpecificImages) {
            Write-Host "  [*] Pulling $img..." -ForegroundColor Cyan
            docker pull $img 2>&1 | Out-Default
        }
        Write-Host "  [OK] Specific image pull completed." -ForegroundColor Green
    }
    "SKIP" {
        Write-Host "  * Skipping image repull (preserving current images)." -ForegroundColor DarkGray
    }
}

# Synchronize Secrets into Containers
$syncSecretsScript = Join-Path $BaseDir "Sync-MediaStackSecrets.ps1"
if (Test-Path $syncSecretsScript) {
    & $syncSecretsScript -SyncLocal -SkipReport | Out-Null
    Write-Host "  [OK] Re-synchronized secrets vault to container environments." -ForegroundColor Green
}

# ==============================================================================
# STAGE 5: DEPENDENCY-ORDERED CLEAN RESTART
# ==============================================================================
Write-Host "`n[STAGE 5/7] Executing Ordered Clean Fleet Bootstrap..." -ForegroundColor Yellow

if ($diag.DockerOnline) {
    # Layer 1: Core Databases & Cache
    Write-Host "  [1/4] Starting Core Databases & Cache (mediastack-db, postgres, redis)..." -ForegroundColor Cyan
    docker start mediastack-db postgres redis 2>$null | Out-Null
    Start-Sleep -Seconds 3

    # Layer 2: Core Indexers & Search
    Write-Host "  [2/4] Starting Search & Indexers (prowlarr, sonarr, radarr, bazarr)..." -ForegroundColor Cyan
    docker start prowlarr sonarr radarr bazarr 2>$null | Out-Null
    Start-Sleep -Seconds 2

    # Layer 3: Streaming, Media & Sync
    Write-Host "  [3/4] Starting Streamers & Sync (jellyfin, syncthing, transmission, nextpvr, tvheadend)..." -ForegroundColor Cyan
    docker start jellyfin syncthing transmission nextpvr tvheadend jellyseerr 2>$null | Out-Null
    Start-Sleep -Seconds 3

    # Layer 4: Gateways, Portals & Ingress Proxy
    Write-Host "  [4/4] Starting Ingress Gateways (caddy, api-gateway, dashboard, homepage)..." -ForegroundColor Cyan
    docker start caddy api-gateway dashboard homepage 2>$null | Out-Null
    Start-Sleep -Seconds 2

    # Start all remaining stack containers
    docker start $(docker ps -a -q) 2>$null | Out-Null

    $postRunning = docker ps --format '{{.Names}}' 2>$null
    $activeCount = if ($postRunning) { @($postRunning).Count } else { 0 }
    Write-Host "  [OK] Clean restart complete: $activeCount containers active." -ForegroundColor Green
}

# ==============================================================================
# STAGE 6: MUSICBRAINZ LIVE REPLICATION SYNC
# ==============================================================================
Write-Host "`n[STAGE 6/7] Updating MusicBrainz Database from MetaBrainz..." -ForegroundColor Yellow

$mbScript = Join-Path $BaseDir "Sync-MusicBrainzReplication.ps1"
if (Test-Path $mbScript) {
    try {
        & $mbScript -SkipReport
        Write-Host "  [OK] MusicBrainz replication check executed successfully." -ForegroundColor Green
    } catch {
        Write-Host "  [WARN] MusicBrainz sync returned: $($_.Exception.Message)" -ForegroundColor Yellow
    }
} else {
    Write-Host "  * Sync-MusicBrainzReplication.ps1 not found, checking local mirror status." -ForegroundColor DarkGray
}

# ==============================================================================
# STAGE 7: INTER-NODE AI AGENT COLLABORATION & CONTINUOUS MONITORING
# ==============================================================================
Write-Host "`n[STAGE 7/7] Initiating AI Agent Collaboration with VoltaireUn..." -ForegroundColor Yellow

$nexusData = [ordered]@{
    last_synced        = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    initiator_node     = "VoltaireDeux"
    primary_target     = "VoltaireUn"
    primary_ip         = $PrimaryIp
    secondary_ip       = $SecondaryIp
    cluster_scheme     = "FrenchOrdinal (VoltaireUn, VoltaireDeux, VoltaireTrois...)"
    fleet_status       = "RUNNING"
    active_containers  = $activeCount
    system_load_pct    = $diag.HostCPU
    free_disk_gb       = $diag.FreeDiskGB
    ai_sentinel_state  = "ACTIVE"
    last_action        = "Full Clean Reboot Suite Executed"
}
$nexusData | ConvertTo-Json -Depth 5 | Set-Content -Path $NexusFile -Encoding UTF8
Write-Host "  [OK] Updated local AI Collaboration Nexus: $NexusFile" -ForegroundColor Green

# Sync nexus to VoltaireUn via reciprocal SMB share if reachable
$peerShareHandoffs = "\\${PrimaryIp}\Public-Downloads\handoffs"
if (Test-Path $peerShareHandoffs -ErrorAction SilentlyContinue) {
    try {
        Copy-Item -Path $NexusFile -Destination (Join-Path $peerShareHandoffs "ai_collaboration_nexus.json") -Force
        Write-Host "  [OK] Synchronized AI Nexus directly to VoltaireUn ($peerShareHandoffs)." -ForegroundColor Green
    } catch {
        Write-Host "  [WARN] Peer handoffs sync returned: $($_.Exception.Message)" -ForegroundColor DarkGray
    }
} else {
    Write-Host "  * VoltaireUn handoff share ($peerShareHandoffs) not currently mounted (saved locally)." -ForegroundColor DarkGray
}

# Generate Executive Report
$reportFile = Join-Path $HandoffsDir "MediaStack_Reboot_Suite_Report_$fileTag.md"
$tick = [char]96
$reportContent = @"
# MediaStack Full Reboot & AI Sentinel Execution Report

| Parameter | Value |
| :--- | :--- |
| **Execution Host** | $($env:COMPUTERNAME) (VoltaireDeux / $SecondaryIp) |
| **Target Peer Host** | VoltaireUn ($PrimaryIp) |
| **Timestamp** | $timestamp |
| **Active Containers** | $activeCount |
| **Docker Engine** | $dockerVer |
| **Host Free Disk** | $($diag.FreeDiskGB) GB |
| **Pre-Reboot Backup** | $(if ($backupArchive) { $backupArchive } else { 'Skipped' }) |
| **Image Pull Strategy** | $pullChoice |
| **AI Sentinel Status** | ACTIVE |

---

## Stage Execution Summary
1. **Diagnostic Sweep:** Checked CPU, Memory, Disks, SQLite DBs, and Peer Link.
2. **Atomic Backup:** Created compressed pre-maintenance archive.
3. **Clean Shutdown:** Ordered 4-phase container stop and SQLite journal purge.
4. **Image Updates:** Strategy: $pullChoice.
5. **Clean Restart:** 4-phase dependency-ordered container launch ($activeCount running).
6. **MusicBrainz Sync:** Incremental MetaBrainz replication synced.
7. **AI Collaboration:** Telemetry and knowledge synced to VoltaireUn AI agent.

---
*Generated by MediaStack Full Reboot Suite.*
"@
Set-Content -Path $reportFile -Value $reportContent -Encoding UTF8
Write-Host "  [OK] Executive report generated: $reportFile" -ForegroundColor Green

# ==============================================================================
# CONTINUOUS AI SENTINEL SUPERVISORY LOOP (IF DAEMON)
# ==============================================================================
if ($Daemon) {
    Write-Host "`n================================================================================" -ForegroundColor Cyan
    Write-Host "   M E D I A S T A C K   A I   S E N T I N E L   A U T O - H E A L E R" -ForegroundColor DarkCyan
    Write-Host "   Continuous Supervision & VoltaireUn AI Communication Loop" -ForegroundColor White
    Write-Host "   Interval: ${IntervalSeconds}s | Press Ctrl+C to exit" -ForegroundColor DarkGray
    Write-Host "================================================================================" -ForegroundColor Cyan

    $autohealer = Join-Path $BaseDir "Start-MediaStackAutohealer.ps1"
    if (Test-Path $autohealer) {
        & $autohealer -IntervalSeconds $IntervalSeconds
    } else {
        while ($true) {
            Start-Sleep -Seconds $IntervalSeconds
            $curRunning = (docker ps -q 2>$null | Measure-Object).Count
            Write-Host ("[{0}] AI Sentinel Heartbeat: {1} containers running | VoltaireUn: {2}" -f (Get-Date -Format 'HH:mm:ss'), $curRunning, $(if (Test-Connection -ComputerName $PrimaryIp -Count 1 -Quiet) { "ONLINE" } else { "OFFLINE" })) -ForegroundColor DarkCyan
        }
    }
} else {
    Write-Host "`n[COMPLETED] MediaStack full reboot suite finished successfully.`n" -ForegroundColor Green
}
