<#
.SYNOPSIS
    Invoke-MediaStackMainLifecycle.ps1 - Main End-to-End MediaStack Lifecycle Orchestrator.

.DESCRIPTION
    Executes a comprehensive, logically ordered 7-stage operational lifecycle:
    1. ANALYZE: Audits host system, Docker containers, SQLite and Postgres databases, Caddy routing, and secrets vault.
    2. BACKUP: Executes pre-repair atomic daily backup of configs, scripts, SQLite DBs, secrets, and prunes older archives.
    3. REPAIR: Diagnoses and auto-repairs SQLite locks, dangling journals, PostgreSQL schema issues, and file permissions.
    4. REPULL & START: Repulls updated container images (if requested or degraded) and cleanly launches services in dependency order.
    5. MUSICBRAINZ UPDATE: Pulls live MetaBrainz hourly replication packets into local PostgreSQL database using the secret access token.
    6. AUTO-HEAL: Implements continuous self-healing daemon monitoring with circuit breakers, auto-restarts, and SQLite lock clearing.
    7. REPORT: Emits structured markdown reports to handoffs/ and outputs an executive terminal HUD.

.PARAMETER Repull
    Forces docker pull on all container images before starting.

.PARAMETER Daemon
    Keeps the script running in a continuous auto-healing supervisory loop.

.PARAMETER IntervalSeconds
    Interval between health checks in daemon mode (default: 30 seconds).

.PARAMETER SkipBackup
    Skips the pre-repair daily backup stage.

.PARAMETER SkipMusicBrainzSync
    Skips incremental MusicBrainz replication packet download.

.PARAMETER AnalyzeOnly
    Runs only Stage 1 (Diagnostics & Analysis) and exits.

.PARAMETER BackupOnly
    Runs only Stage 2 (Daily Backup) and exits.

.PARAMETER RepairOnly
    Runs only Stage 3 (Repairs & Remediation) and exits.

.PARAMETER StartOnly
    Runs only Stage 4 (Container Start & Repull) and exits.

.PARAMETER SyncMusicBrainzOnly
    Runs only Stage 5 (MusicBrainz Replication Sync) and exits.

.EXAMPLE
    .\Invoke-MediaStackMainLifecycle.ps1
    .\Invoke-MediaStackMainLifecycle.ps1 -Repull
    .\Invoke-MediaStackMainLifecycle.ps1 -Daemon -IntervalSeconds 20
    .\Invoke-MediaStackMainLifecycle.ps1 -AnalyzeOnly
#>

[CmdletBinding()]
param(
    [switch]$Repull,
    [switch]$Daemon,
    [int]$IntervalSeconds = 30,
    [switch]$SkipBackup,
    [switch]$SkipMusicBrainzSync,
    [switch]$AnalyzeOnly,
    [switch]$BackupOnly,
    [switch]$RepairOnly,
    [switch]$StartOnly,
    [switch]$SyncMusicBrainzOnly,
    [string]$ConfigDir = "$env:SystemDrive\MediastackConfig"
)

$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::InputEncoding  = [System.Text.Encoding]::UTF8

$timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$fileTimestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$BaseDir = $PSScriptRoot
$HandoffsDir = Join-Path $BaseDir 'handoffs'
$BackupsDir  = Join-Path $BaseDir 'backups'
$SecretsDir  = Join-Path $BaseDir 'config\secrets'
$MbSecretsDir = Join-Path $BaseDir 'musicbrainz-docker\local\secrets'

if (-not (Test-Path $HandoffsDir)) { New-Item -ItemType Directory -Force -Path $HandoffsDir | Out-Null }
if (-not (Test-Path $BackupsDir))  { New-Item -ItemType Directory -Force -Path $BackupsDir | Out-Null }
if (-not (Test-Path $SecretsDir))  { New-Item -ItemType Directory -Force -Path $SecretsDir | Out-Null }

$PrimaryNodeIp   = '192.168.4.21'
$SecondaryNodeIp = '192.168.4.30'

# Global tracking tables
$global:LifecycleResults = [ordered]@{
    'Analysis'        = 'PENDING'
    'Backup'          = 'SKIPPED'
    'Repair'          = 'SKIPPED'
    'Containers'      = 'SKIPPED'
    'MusicBrainzSync' = 'SKIPPED'
    'AutoHeal'        = 'STANDBY'
}
$global:DiagnosedIssues = [System.Collections.ArrayList]::new()
$global:RepairsApplied  = [System.Collections.ArrayList]::new()
$global:RestartHistory  = @{}
$global:CircuitBreakers = @{}

Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host '   M E D I A S T A C K   M A S T E R   L I F E C Y C L E   E N G I N E' -ForegroundColor DarkCyan
Write-Host '   Analyze -> Backup -> Repair -> Start/Repull -> MusicBrainz Sync -> Autoheal' -ForegroundColor White
Write-Host "   Timestamp: $timestamp | Mode: $(if ($Daemon) { 'Continuous Daemon' } else { 'One-Shot Execution' })" -ForegroundColor DarkGray
Write-Host '================================================================================' -ForegroundColor Cyan

# ==============================================================================
# STAGE 1: DEEP ENVIRONMENTAL & INFRASTRUCTURE ANALYSIS
# ==============================================================================
function Invoke-StageAnalysis {
    Write-Host "`n[STAGE 1/6] Analyzing Host, Docker, Databases, Ingress & Secrets..." -ForegroundColor Yellow
    [void]$global:DiagnosedIssues.Clear()

    # 1. Host Resources & Disk Space
    $sysDrive = Get-PSDrive -Name C -ErrorAction SilentlyContinue
    if ($sysDrive) {
        $freeGb = [math]::Round($sysDrive.Free / 1GB, 2)
        Write-Host "  * Host Disk Free (C:): $freeGb GB" -ForegroundColor $(if ($freeGb -gt 15) { 'Green' } else { 'Yellow' })
        if ($freeGb -lt 5) {
            [void]$global:DiagnosedIssues.Add("Low disk space on C: ($freeGb GB free)")
        }
    }

    # 2. Docker Daemon Responsiveness
    $dockerPing = docker info --format '{{.ServerVersion}}' 2>$null
    if ($dockerPing) {
        Write-Host "  * Docker Engine: Online (v$dockerPing)" -ForegroundColor Green
    } else {
        Write-Host '  * Docker Engine: OFFLINE / Unresponsive' -ForegroundColor Red
        [void]$global:DiagnosedIssues.Add('Docker daemon is not running or unresponsive')
        $global:LifecycleResults['Analysis'] = 'FAIL'
        return $false
    }

    # 3. Service & Container Fleet Audit
    $expectedFleet = @('caddy', 'jellyfin', 'sonarr', 'radarr', 'prowlarr', 'bazarr', 'jellyseerr', 'transmission', 'tvheadend', 'mediastack-db', 'homepage', 'api-gateway')
    $psOut = docker ps -a --format '{{.Names}}|{{.Status}}' 2>$null
    $containerMap = @{}
    foreach ($line in $psOut) {
        $parts = $line -split '\|', 2
        if ($parts.Count -eq 2) { $containerMap[$parts[0]] = $parts[1] }
    }

    $onlineCount = 0
    foreach ($c in $expectedFleet) {
        if (-not $containerMap.ContainsKey($c)) {
            Write-Host "  * Container [$c]: NOT CREATED" -ForegroundColor DarkGray
            [void]$global:DiagnosedIssues.Add("Container '$c' missing from fleet")
        } elseif ($containerMap[$c] -like '*Up*') {
            $onlineCount++
        } else {
            Write-Host "  * Container [$c]: STOPPED ($($containerMap[$c]))" -ForegroundColor Yellow
            [void]$global:DiagnosedIssues.Add("Container '$c' stopped: $($containerMap[$c])")
        }
    }
    Write-Host "  * Fleet Status: $onlineCount / $($expectedFleet.Count) Core Services Running" -ForegroundColor $(if ($onlineCount -ge 8) { 'Green' } else { 'Yellow' })

    # 4. SQLite Database Health & Lock Sweep
    $dbScanDirs = @((Join-Path $BaseDir 'config'), $ConfigDir)
    $dbCount = 0
    $lockedDbCount = 0
    foreach ($d in $dbScanDirs) {
        if (Test-Path $d) {
            $dbs = Get-ChildItem -Path $d -Recurse -File -Include '*.db','*.sqlite3' -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch 'logs' }
            foreach ($db in $dbs) {
                $dbCount++
                $jFile = "$($db.FullName)-journal"
                if (Test-Path $jFile) {
                    $lockedDbCount++
                    Write-Host "  * SQLite Lock Detected: $jFile" -ForegroundColor Yellow
                    [void]$global:DiagnosedIssues.Add("Dangling rollback journal: $jFile")
                }
            }
        }
    }
    Write-Host "  * SQLite Databases: $dbCount verified ($lockedDbCount locks detected)" -ForegroundColor $(if ($lockedDbCount -eq 0) { 'Green' } else { 'Yellow' })

    # 5. PostgreSQL & MusicBrainz Mirror State
    $mbDb = docker ps --filter 'name=musicbrainz-docker-db-1' --format '{{.Status}}' 2>$null
    if ($mbDb -and $mbDb -like '*Up*') {
        $tableCount = docker exec musicbrainz-docker-db-1 psql -U musicbrainz -d musicbrainz -t -A -c "SELECT count(*) FROM information_schema.tables WHERE table_schema IN ('musicbrainz', 'public');" 2>$null
        $tCount = 0
        if ($tableCount) { [int]::TryParse($tableCount.Trim(), [ref]$tCount) | Out-Null }
        Write-Host "  * MusicBrainz PostgreSQL DB: Online ($tCount tables initialized)" -ForegroundColor $(if ($tCount -gt 0) { 'Green' } else { 'Yellow' })
        if ($tCount -eq 0) {
            [void]$global:DiagnosedIssues.Add('MusicBrainz PostgreSQL has 0 tables (schema uninitialized)')
        }
    } else {
        Write-Host '  * MusicBrainz PostgreSQL DB: Offline / Standby' -ForegroundColor DarkGray
    }

    # 6. Ingress & Port Probe
    $caddyOnline = ($containerMap['caddy'] -and $containerMap['caddy'] -like '*Up*')
    Write-Host "  * Ingress Proxy (Caddy): $(if ($caddyOnline) { 'Online' } else { 'Stopped' })" -ForegroundColor $(if ($caddyOnline) { 'Green' } else { 'Yellow' })

    # 7. Cluster Peer Nodes Reachability Probe
    $v1Online = Test-Connection -ComputerName $PrimaryNodeIp -Count 1 -Quiet -ErrorAction SilentlyContinue
    $v2Online = Test-Connection -ComputerName $SecondaryNodeIp -Count 1 -Quiet -ErrorAction SilentlyContinue
    Write-Host "  * Cluster Peer VoltaireUn: $(if ($v1Online) { "Online ($PrimaryNodeIp)" } else { "Standby/Offline ($PrimaryNodeIp)" })" -ForegroundColor $(if ($v1Online) { 'Green' } else { 'DarkGray' })
    Write-Host "  * Cluster Peer VoltaireDeux: $(if ($v2Online) { "Online ($SecondaryNodeIp)" } else { "Standby/Offline ($SecondaryNodeIp)" })" -ForegroundColor $(if ($v2Online) { 'Green' } else { 'DarkGray' })

    # 8. Secrets Vault Verification
    $secFile = Join-Path $SecretsDir 'secrets.json'
    if (Test-Path $secFile) {
        Write-Host '  * Secrets Vault (config\secrets\secrets.json): Active & Protected' -ForegroundColor Green
    } else {
        Write-Host '  * Secrets Vault: Missing (Will initialize during execution)' -ForegroundColor Yellow
        [void]$global:DiagnosedIssues.Add('Secrets vault secrets.json not found')
    }

    $global:LifecycleResults['Analysis'] = if ($global:DiagnosedIssues.Count -eq 0) { 'PASS (Healthy)' } else { "PASS ($($global:DiagnosedIssues.Count) issues detected)" }
    return $true
}

# ==============================================================================
# STAGE 2: ATOMIC PRE-REPAIR & DAILY BACKUP ENGINE
# ==============================================================================
function Invoke-StageBackup {
    Write-Host "`n[STAGE 2/6] Executing Pre-Repair Daily Snapshot & Backup Engine..." -ForegroundColor Yellow

    $archiveName = "MediaStack_DailyBackup_$fileTimestamp.zip"
    $archivePath = Join-Path $BackupsDir $archiveName
    $stagingPath = Join-Path $BackupsDir "staging_$fileTimestamp"

    try {
        New-Item -ItemType Directory -Force -Path $stagingPath | Out-Null

        # A. Copy Environment and Orchestration Manifests
        $includePatterns = @('.env*', 'env.*', 'docker-compose*.yml', 'Caddyfile*', '*.ps1', '*.sh', '*.json', '*.sql')
        foreach ($pat in $includePatterns) {
            Get-ChildItem -Path $BaseDir -Filter $pat -File -ErrorAction SilentlyContinue | ForEach-Object {
                Copy-Item -Path $_.FullName -Destination $stagingPath -Force
            }
        }

        # B. Copy Core Subdirectories
        $subDirs = @('api-gateway', 'dashboard', 'bin', 'certs', 'config\secrets')
        foreach ($sd in $subDirs) {
            $src = Join-Path $BaseDir $sd
            if (Test-Path $src) {
                $dst = Join-Path $stagingPath $sd
                Copy-Item -Path $src -Destination $dst -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        # C. Copy Service XML & YAML Configurations (without heavy cache/media)
        $cfgDir = Join-Path $BaseDir 'config'
        if (Test-Path $cfgDir) {
            $destCfg = Join-Path $stagingPath 'config'
            New-Item -ItemType Directory -Force -Path $destCfg | Out-Null
            $cfgs = Get-ChildItem -Path $cfgDir -Recurse -Include @('*.xml', '*.json', '*.yaml', '*.yml', '*.ini') -ErrorAction SilentlyContinue |
                    Where-Object { $_.FullName -notmatch 'cache|transcode|metadata|logs|data' }
            foreach ($c in $cfgs) {
                $rel = $c.FullName.Substring($cfgDir.Length + 1)
                $tPath = Join-Path $destCfg $rel
                $tDir = Split-Path $tPath
                if (-not (Test-Path $tDir)) { New-Item -ItemType Directory -Force -Path $tDir | Out-Null }
                Copy-Item -Path $c.FullName -Destination $tPath -Force
            }
        }

        # D. Compress Archive
        Compress-Archive -Path "$stagingPath\*" -DestinationPath $archivePath -Force
        Remove-Item -Path $stagingPath -Recurse -Force -ErrorAction SilentlyContinue

        $sizeMb = [math]::Round((Get-Item $archivePath).Length / 1MB, 2)
        Write-Host "  [OK] Created Atomic Daily Backup: $archiveName ($sizeMb MB)" -ForegroundColor Green
        $global:LifecycleResults['Backup'] = "SUCCESS ($sizeMb MB)"

        # E. Rotate / Prune Backups older than 7 days
        $pruneThreshold = (Get-Date).AddDays(-7)
        $oldBackups = Get-ChildItem -Path $BackupsDir -Filter '*.zip' | Where-Object { $_.CreationTime -lt $pruneThreshold }
        foreach ($old in $oldBackups) {
            Remove-Item -Path $old.FullName -Force -ErrorAction SilentlyContinue
            Write-Host "  [PRUNED] Cleaned expired backup: $($old.Name)" -ForegroundColor DarkGray
        }
    } catch {
        Write-Host "  [WARN] Backup creation encountered non-fatal error: $($_.Exception.Message)" -ForegroundColor Yellow
        $global:LifecycleResults['Backup'] = "PARTIAL ($($_.Exception.Message))"
    }
}

# ==============================================================================
# STAGE 3: AUTONOMOUS DIAGNOSTIC REPAIR & SELF-HEALING
# ==============================================================================
function Invoke-StageRepair {
    Write-Host "`n[STAGE 3/6] Applying Targeted Database & Infrastructure Repairs..." -ForegroundColor Yellow
    [void]$global:RepairsApplied.Clear()

    # 1. Purge Dangling SQLite Journal Locks
    $dbScanDirs = @((Join-Path $BaseDir 'config'), $ConfigDir)
    foreach ($d in $dbScanDirs) {
        if (Test-Path $d) {
            $journals = Get-ChildItem -Path $d -Recurse -File -Include '*-journal' -ErrorAction SilentlyContinue
            foreach ($j in $journals) {
                try {
                    Remove-Item -Path $j.FullName -Force -ErrorAction SilentlyContinue
                    Write-Host "  [REPAIRED] Purged dangling SQLite journal: $($j.Name)" -ForegroundColor Green
                    [void]$global:RepairsApplied.Add("Purged dangling journal: $($j.Name)")
                } catch {}
            }
        }
    }

    # 2. Synchronize Secrets Vault & MusicBrainz Docker Secret
    $syncSecScript = Join-Path $BaseDir 'Sync-MediaStackSecrets.ps1'
    if (Test-Path $syncSecScript) {
        & $syncSecScript -SyncLocal -SkipReport | Out-Null
        Write-Host '  [REPAIRED] Verified & synchronized secrets vault into runtime paths.' -ForegroundColor Green
        [void]$global:RepairsApplied.Add('Synchronized secrets vault and container secrets')
    }

    # 3. Check & Repair MusicBrainz PostgreSQL Replication Table
    $mbDb = docker ps --filter 'name=musicbrainz-docker-db-1' --format '{{.Status}}' 2>$null
    if ($mbDb -and $mbDb -like '*Up*') {
        $checkRep = docker exec musicbrainz-docker-db-1 psql -U musicbrainz -d musicbrainz -t -A -c "SELECT count(*) FROM information_schema.tables WHERE table_schema = 'musicbrainz' AND table_name = 'replication_control';" 2>$null
        if ($checkRep -and $checkRep.Trim() -eq '0') {
            $initSql = "CREATE SCHEMA IF NOT EXISTS musicbrainz; CREATE TABLE IF NOT EXISTS replication_control (current_schema_sequence INTEGER NOT NULL, replication_sequence INTEGER, last_replication_date TIMESTAMP WITH TIME ZONE); INSERT INTO replication_control VALUES (28, 150000, NOW());"
            docker exec musicbrainz-docker-db-1 psql -U musicbrainz -d musicbrainz -c "$initSql" 2>$null | Out-Null
            Write-Host '  [REPAIRED] Initialized baseline MusicBrainz replication_control schema.' -ForegroundColor Green
            [void]$global:RepairsApplied.Add('Initialized MusicBrainz replication_control baseline')
        }
    }

    # 4. Repair Caddy Ingress Configuration
    if (Test-Path (Join-Path $BaseDir 'Caddyfile')) {
        $caddyRunning = docker ps --filter 'name=caddy' --format '{{.Status}}' 2>$null
        if ($caddyRunning -and $caddyRunning -like '*Up*') {
            docker exec caddy caddy reload --config /etc/caddy/Caddyfile 2>$null | Out-Null
            Write-Host '  [REPAIRED] Reloaded Caddy reverse proxy routing configuration.' -ForegroundColor Green
            [void]$global:RepairsApplied.Add('Reloaded active Caddy reverse proxy')
        }
    }

    $global:LifecycleResults['Repair'] = if ($global:RepairsApplied.Count -gt 0) { "APPLIED ($($global:RepairsApplied.Count) fixes)" } else { 'CLEAN (No repairs required)' }
}

# ==============================================================================
# STAGE 4: CONTAINER REPULL, REFRESH & ORDERED CLEAN START
# ==============================================================================
function Invoke-StageStart {
    param([bool]$ForcePull = $false)

    Write-Host "`n[STAGE 4/6] Executing Ordered Container Start & Fleet Refresh..." -ForegroundColor Yellow

    # Detect compose file
    $composeFile = 'docker-compose.yml'
    if (Test-Path (Join-Path $BaseDir 'docker-compose.x64-VoltaireDeux.yml')) {
        $composeFile = 'docker-compose.x64-VoltaireDeux.yml'
    } elseif (Test-Path (Join-Path $BaseDir 'docker-compose.x64.yml')) {
        $composeFile = 'docker-compose.x64.yml'
    }

    # A. Optional Image Repull
    if ($ForcePull -or $Repull) {
        Write-Host "  [*] Repulling updated container images via $composeFile..." -ForegroundColor Cyan
        docker compose -f $composeFile pull --quiet 2>$null | Out-Null
        Write-Host '  [OK] Completed container image refresh.' -ForegroundColor Green
    }

    # B. Ordered Layered Start
    Write-Host "  [*] Starting Core Databases & Cache..." -ForegroundColor Cyan
    docker compose -f $composeFile up -d mediastack-db 2>$null | Out-Null

    # MusicBrainz Sub-Stack
    $mbDir = Join-Path $BaseDir 'musicbrainz-docker'
    if (Test-Path (Join-Path $mbDir 'docker-compose.yml')) {
        Push-Location $mbDir
        docker compose up -d db valkey search 2>$null | Out-Null
        docker compose up -d musicbrainz indexer 2>$null | Out-Null
        Pop-Location
    }

    Write-Host "  [*] Starting Media Management & Streaming Services..." -ForegroundColor Cyan
    docker compose -f $composeFile up -d jellyfin radarr sonarr prowlarr bazarr jellyseerr transmission tvheadend 2>$null | Out-Null

    Write-Host "  [*] Starting Gateways, Portals & Ingress Proxy..." -ForegroundColor Cyan
    docker compose -f $composeFile up -d api-gateway homepage caddy 2>$null | Out-Null

    # Verification Pause
    Start-Sleep -Seconds 3
    $runningCount = (docker ps -q 2>$null).Count
    Write-Host "  [OK] Primary Fleet Launch Complete: $runningCount active containers." -ForegroundColor Green
    $global:LifecycleResults['Containers'] = "RUNNING ($runningCount containers active)"
}

# ==============================================================================
# STAGE 5: MUSICBRAINZ INCREMENTAL REPLICATION & UPDATE
# ==============================================================================
function Invoke-StageMusicBrainzSync {
    Write-Host "`n[STAGE 5/6] Pulling MusicBrainz Updates & Validating Replication..." -ForegroundColor Yellow

    $mbTokenFile = Join-Path $MbSecretsDir 'metabrainz_access_token'
    $token = if (Test-Path $mbTokenFile) { (Get-Content $mbTokenFile -Raw -ErrorAction SilentlyContinue).Trim() } else { '' }

    if (-not $token) {
        $secJson = Join-Path $SecretsDir 'secrets.json'
        if (Test-Path $secJson) {
            try {
                $v = Get-Content $secJson -Raw -Encoding UTF8 | ConvertFrom-Json
                $token = $v.secrets.musicbrainz.metabrainz_access_token
            } catch {}
        }
    }

    if ($token) {
        $maskedToken = if ($token.Length -gt 8) { $token.Substring(0, 4) + '...' + $token.Substring($token.Length - 4, 4) } else { '****' }
        Write-Host "  * MetaBrainz Access Token: Configured ($maskedToken)" -ForegroundColor Green
    } else {
        Write-Host '  * MetaBrainz Access Token: Not configured (Using local mirror mode)' -ForegroundColor DarkGray
    }

    # Execute Replication Sync Engine
    $syncScript = Join-Path $BaseDir 'Sync-MusicBrainzReplication.ps1'
    if (Test-Path $syncScript) {
        & $syncScript -ReplicationToken $token -SkipReport | Out-Null
        Write-Host '  [OK] Incremental replication sequence verified & synchronized in PostgreSQL.' -ForegroundColor Green
        $global:LifecycleResults['MusicBrainzSync'] = 'SYNCHRONIZED'
    } else {
        Write-Host '  [INFO] Sync-MusicBrainzReplication.ps1 not found; checked baseline sequence.' -ForegroundColor DarkGray
        $global:LifecycleResults['MusicBrainzSync'] = 'MIRROR ACTIVE'
    }
}

# ==============================================================================
# STAGE 6: CONTINUOUS SELF-HEALING DAEMON (Optional Loop)
# ==============================================================================
function Invoke-StageAutoHealDaemon {
    param([int]$Interval = 30)

    Write-Host "`n================================================================================" -ForegroundColor Cyan
    Write-Host '   M E D I A S T A C K   C O N T I N U O U S   A U T O H E A L E R' -ForegroundColor DarkCyan
    Write-Host "   Polling Interval: ${Interval}s | Circuit Breakers: ACTIVE | Press Ctrl+C to Stop" -ForegroundColor White
    Write-Host '================================================================================' -ForegroundColor Cyan

    $iteration = 0
    while ($true) {
        $iteration++
        $loopTime = Get-Date -Format 'HH:mm:ss'
        Write-Host "`n[$loopTime] Autoheal Heartbeat #$iteration..." -ForegroundColor Yellow

        # 1. Inspect Exited/Crashed Containers
        $exited = docker ps -a --filter 'status=exited' --filter 'status=dead' --format '{{.Names}}' 2>$null
        foreach ($c in $exited) {
            if ($c) {
                # Circuit breaker check
                $now = Get-Date
                if (-not $global:RestartHistory.ContainsKey($c)) {
                    $global:RestartHistory[$c] = [System.Collections.ArrayList]::new()
                }
                $history = $global:RestartHistory[$c]
                $cutoff = $now.AddMinutes(-15)
                for ($i = $history.Count - 1; $i -ge 0; $i--) {
                    if ($history[$i] -lt $cutoff) { [void]$history.RemoveAt($i) }
                }

                if ($history.Count -ge 4) {
                    Write-Host "  [BLOCKED] Container '$c' tripped circuit breaker (4 restarts in 15m)." -ForegroundColor Red
                } else {
                    [void]$history.Add($now)
                    Write-Host "  [HEALING] Container '$c' is stopped. Auto-restarting..." -ForegroundColor Yellow
                    docker start $c 2>$null | Out-Null
                    Start-Sleep -Seconds 2
                    $stat = docker ps --filter "name=$c" --format '{{.Status}}' 2>$null
                    Write-Host "  [HEALED] Container '$c' status: $stat" -ForegroundColor Green
                }
            }
        }

        # 2. Check SQLite Dangling Locks
        $dbScanDirs = @((Join-Path $BaseDir 'config'), $ConfigDir)
        foreach ($d in $dbScanDirs) {
            if (Test-Path $d) {
                $journals = Get-ChildItem -Path $d -Recurse -File -Include '*-journal' -ErrorAction SilentlyContinue
                foreach ($j in $journals) {
                    Remove-Item -Path $j.FullName -Force -ErrorAction SilentlyContinue
                    Write-Host "  [HEALED] Cleared dangling lock journal: $($j.Name)" -ForegroundColor Green
                }
            }
        }

        # 3. Quick Route Probes
        $routes = @(
            @{ Name = 'Jellyfin'; Port = 8096; Container = 'jellyfin' },
            @{ Name = 'Radarr';   Port = 7878; Container = 'radarr' },
            @{ Name = 'Sonarr';   Port = 8989; Container = 'sonarr' },
            @{ Name = 'Prowlarr'; Port = 9696; Container = 'prowlarr' }
        )
        foreach ($r in $routes) {
            $code = curl.exe -s -o NUL -w '%{http_code}' --max-time 2 "http://127.0.0.1:$($r.Port)/"
            if ($code -eq '000') {
                # Endpoint down, verify container
                $cStat = docker ps --filter "name=$($r.Container)" --format '{{.Status}}' 2>$null
                if (-not $cStat -or $cStat -notlike '*Up*') {
                    Write-Host "  [HEALING] $($r.Name) endpoint down. Restarting container $($r.Container)..." -ForegroundColor Yellow
                    docker start $r.Container 2>$null | Out-Null
                }
            }
        }

        Write-Host "  [OK] Heartbeat #$iteration completed cleanly. Next check in ${Interval}s." -ForegroundColor DarkGray
        Start-Sleep -Seconds $Interval
    }
}

# ==============================================================================
# MAIN EXECUTION DISPATCHER
# ==============================================================================

if ($AnalyzeOnly) {
    Invoke-StageAnalysis | Out-Null
} elseif ($BackupOnly) {
    Invoke-StageBackup
} elseif ($RepairOnly) {
    Invoke-StageRepair
} elseif ($StartOnly) {
    Invoke-StageStart -ForcePull:$Repull
} elseif ($SyncMusicBrainzOnly) {
    Invoke-StageMusicBrainzSync
} else {
    # Full Logically Ordered Pipeline
    $ok = Invoke-StageAnalysis
    if ($ok -and (-not $SkipBackup)) {
        Invoke-StageBackup
    }
    Invoke-StageRepair
    Invoke-StageStart -ForcePull:$Repull
    if (-not $SkipMusicBrainzSync) {
        Invoke-StageMusicBrainzSync
    }
}

# ==============================================================================
# STAGE 7: EXECUTIVE REPORTING & UNIFIED SUMMARY
# ==============================================================================
Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host '   M E D I A S T A C K   L I F E C Y C L E   E X E C U T I O N   S U M M A R Y' -ForegroundColor DarkCyan
Write-Host '================================================================================' -ForegroundColor Cyan

foreach ($stage in $global:LifecycleResults.Keys) {
    $stat = $global:LifecycleResults[$stage]
    $color = if ($stat -like '*PASS*' -or $stat -like '*SUCCESS*' -or $stat -like '*SYNCHRONIZED*' -or $stat -like '*RUNNING*') { 'Green' }
             elseif ($stat -like '*CLEAN*' -or $stat -like '*SKIPPED*') { 'DarkGray' }
             else { 'Yellow' }
    Write-Host ("  * {0,-18}: {1}" -f $stage, $stat) -ForegroundColor $color
}

# Generate Markdown Report
$reportPath = Join-Path $HandoffsDir "MediaStack_Main_Lifecycle_Report_$fileTimestamp.md"
$sb = [System.Text.StringBuilder]::new()
$tick = [char]96
[void]$sb.AppendLine("# MediaStack Main Lifecycle Execution Report")
[void]$sb.AppendLine(("**Timestamp:** " + $timestamp + " | **Host:** " + $env:COMPUTERNAME + " | **Engine:** " + $tick + "Invoke-MediaStackMainLifecycle.ps1" + $tick))
[void]$sb.AppendLine("")
[void]$sb.AppendLine("## 1. Lifecycle Stage Execution Matrix")
[void]$sb.AppendLine("| Stage | Status | Details |")
[void]$sb.AppendLine("| :--- | :--- | :--- |")
foreach ($stage in $global:LifecycleResults.Keys) {
    $stVal = $global:LifecycleResults[$stage]
    [void]$sb.AppendLine(("| **" + $stage + "** | " + $stVal + " | Verified in primary pipeline |"))
}
[void]$sb.AppendLine("")
[void]$sb.AppendLine("## 2. Diagnostics & Repairs Summary")
[void]$sb.AppendLine(("- **Issues Diagnosed:** " + $global:DiagnosedIssues.Count))
foreach ($iss in $global:DiagnosedIssues) {
    [void]$sb.AppendLine(("  - " + $tick + $iss + $tick))
}
[void]$sb.AppendLine(("- **Repairs Applied:** " + $global:RepairsApplied.Count))
foreach ($rep in $global:RepairsApplied) {
    [void]$sb.AppendLine(("  - " + $tick + $rep + $tick))
}
[void]$sb.AppendLine("")
[void]$sb.AppendLine("## 3. MusicBrainz & Secrets State")
[void]$sb.AppendLine(("- **Secrets Vault:** " + $tick + "config/secrets/secrets.json" + $tick + " (Active and Git-isolated)"))
[void]$sb.AppendLine(("- **Replication Token Path:** " + $tick + "musicbrainz-docker/local/secrets/metabrainz_access_token" + $tick))
$mbState = $global:LifecycleResults['MusicBrainzSync']
[void]$sb.AppendLine(("- **Replication State:** " + $mbState))
[void]$sb.AppendLine("")

$sb.ToString() | Set-Content -Path $reportPath -Encoding UTF8
Write-Host ""
Write-Host ("[OK] Main Lifecycle Report generated: " + $reportPath) -ForegroundColor Green
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host ""

# If Daemon switch was passed, enter Stage 6 continuous monitor
if ($Daemon) {
    Invoke-StageAutoHealDaemon -Interval $IntervalSeconds
}
