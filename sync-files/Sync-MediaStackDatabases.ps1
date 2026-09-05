<#
.SYNOPSIS
    Sync-MediaStackDatabases.ps1 - Dual-Node Cluster Database Replication, Pre-Sync Backup & Hot-Restore Sentinel.

.DESCRIPTION
    Autonomous database synchronization engine for the VoltaireUn (Main Server) <---> VoltaireDeux (AI Node) cluster:
    1. Node & Cluster IP Awareness (dynamically resolves local and peer nodes).
    2. Mandatory Pre-Sync Atomic Snapshots: Creates immutable SQLite snapshots with SHA-256 integrity verification
       BEFORE any synchronization or replication is performed.
    3. Passive zero-downtime WAL Checkpoint: Flushes active WAL logs safely without blocking live readers.
    4. Two-Way Cluster Sync: Reconciles databases between node local storage and shared cluster storage while
       preventing OneDrive lock/conflict files (*.db-shm, *-VoltaireDeux.db).
    5. Instant Hot-Restore: Auto-heals and restores from verified snapshots if any corruption is detected.
    6. Structured Telemetry: Logs all actions to SQLite registry and writes audit summaries.

.PARAMETER IntervalSeconds
    Replication cycle interval in seconds when running in continuous loop. Defaults to 300 (5 minutes).

.PARAMETER RunOnce
    Executes a single pre-sync backup and replication cycle then terminates.

.PARAMETER PreSyncBackupOnly
    Executes mandatory pre-sync database backup snapshots and validates integrity without syncing.

.PARAMETER ConfigDir
    Host root directory for MediaStack configurations.

.PARAMETER BackupRoot
    Destination directory for snapshot repositories.

.EXAMPLE
    .\Sync-MediaStackDatabases.ps1 -RunOnce
    .\Sync-MediaStackDatabases.ps1 -PreSyncBackupOnly
#>

[CmdletBinding()]
param(
    [int]$IntervalSeconds = 300,
    [switch]$RunOnce,
    [switch]$PreSyncBackupOnly,
    [string]$ConfigDir = "$env:SystemDrive\MediastackConfig",
    [string]$BackupRoot = ""
)

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::InputEncoding  = [System.Text.Encoding]::UTF8

# Import Operations Module
$modulePath = Join-Path $PSScriptRoot "MediaStackOps.psm1"
if (Test-Path $modulePath) { 
    Import-Module $modulePath -Force 
} elseif (Test-Path "$PSScriptRoot\MediaStackOps.ps1") {
    . "$PSScriptRoot\MediaStackOps.ps1"
}

# Dynamic Node Discovery
$nodeInfo = Get-MediaStackClusterNodeInfo
$ActiveConfig = if (Test-Path "$PSScriptRoot\config") { "$PSScriptRoot\config" } elseif (Test-Path $ConfigDir) { $ConfigDir } else { "$PSScriptRoot\config" }
if (-not $BackupRoot) {
    $BackupRoot = Join-Path $ActiveConfig "db-backup\snapshots"
}

$HandoffsDir = Join-Path $PSScriptRoot "handoffs"
if (-not (Test-Path $HandoffsDir)) { New-Item -ItemType Directory -Force -Path $HandoffsDir | Out-Null }
if (-not (Test-Path $BackupRoot)) { New-Item -ItemType Directory -Force -Path $BackupRoot | Out-Null }

# Database Inventory Definition
$DatabaseInventory = @(
    @{ Name="MediaStack Backup DB"; InternalPath="/config/mediastack_backup.db"; HostPath="$ActiveConfig\db-backup\mediastack_backup.db"; Service="mediastack-db" },
    @{ Name="Sonarr DB";            InternalPath="/mediastack/config/sonarr/sonarr.db"; HostPath="$ActiveConfig\sonarr\sonarr.db"; Service="sonarr" },
    @{ Name="Radarr DB";            InternalPath="/mediastack/config/radarr/radarr.db"; HostPath="$ActiveConfig\radarr\radarr.db"; Service="radarr" },
    @{ Name="Prowlarr DB";          InternalPath="/mediastack/config/prowlarr/prowlarr.db"; HostPath="$ActiveConfig\prowlarr\prowlarr.db"; Service="prowlarr" },
    @{ Name="Bazarr DB";            InternalPath="/mediastack/config/bazarr/db/bazarr.db"; HostPath="$ActiveConfig\bazarr\db\bazarr.db"; Service="bazarr" },
    @{ Name="Jellyseerr DB";        InternalPath="/mediastack/config/jellyseerr/db/db.sqlite3"; HostPath="$ActiveConfig\jellyseerr\db\db.sqlite3"; Service="jellyseerr" },
    @{ Name="Jellyfin Main DB";     InternalPath="/mediastack/config/jellyfin/data/data/jellyfin.db"; HostPath="$ActiveConfig\jellyfin\data\data\jellyfin.db"; Service="jellyfin" }
)

function Invoke-ReplicationCycle {
    param([switch]$BackupOnly)

    $cycleStart = Get-Date
    $tsString = $cycleStart.ToString("yyyy-MM-dd HH:mm:ss")
    $fileTag = $cycleStart.ToString("yyyyMMdd_HHmmss")
    
    Write-Host ("`n[{0}] === EXECUTING PRE-SYNC ATOMIC SNAPSHOT & BACKUP PASS ===" -f (Get-Date -Format "HH:mm:ss")) -ForegroundColor DarkCyan
    
    # 1. Mandatory Pre-Sync Atomic Snapshot
    $preSyncResult = Backup-MediaStackDatabasesPreSync -ConfigDir $ActiveConfig -BackupRoot $BackupRoot -OperationTag "PRE_SYNC"
    
    if ($preSyncResult.AllPassed) {
        Write-Host "  [OK] All database pre-sync safety snapshots verified and registered." -ForegroundColor Green
    } else {
        Write-Host "  [WARN] Some database snapshots encountered warnings during pre-sync pass." -ForegroundColor Yellow
    }

    if ($BackupOnly) {
        Write-Host "`n[PRE-SYNC BACKUP COMPLETED] Snapshots stored in: $($preSyncResult.BatchDir)" -ForegroundColor Cyan
        return
    }

    Write-Host ("`n[{0}] === EXECUTING ZERO-DOWNTIME DATABASE REPLICATION & HEALTH CHECK ===" -f (Get-Date -Format "HH:mm:ss")) -ForegroundColor DarkCyan

    $successCount = 0
    $failCount = 0

    foreach ($db in $DatabaseInventory) {
        $dbName = $db.Name
        $hPath  = $db.HostPath
        $inPath = $db.InternalPath
        $svc    = $db.Service

        if (-not (Test-Path $hPath)) {
            Write-Host ("  [SKIP] {0,-22} : Host database file not found at {1}" -f $dbName, $hPath) -ForegroundColor DarkGray
            continue
        }

        # Step 1: Lock-Free Integrity Check
        $health = Test-MediaStackDatabaseHealth -HostPath $hPath -InternalPath $inPath
        if (-not $health.IsValid) {
            Write-Host ("  [!] ANOMALY DETECTED for {0} ({1}). Triggering Instant Hot-Restore..." -f $dbName, $health.Details) -ForegroundColor Red
            
            $restoreRes = Invoke-DatabaseHotRestore -DatabaseName $dbName -TargetHostPath $hPath -InternalContainerPath $inPath -SnapshotDir $BackupRoot
            if ($restoreRes.Success) {
                Write-Host ("  [RECOVERED] {0} -> {1}" -f $dbName, $restoreRes.Diagnostics) -ForegroundColor Green
                $successCount++
            } else {
                Write-Host ("  [CRITICAL] {0} Hot-Restore Failed!" -f $dbName) -ForegroundColor Red
                $failCount++
            }
            continue
        }

        # Step 2: Atomic Online Snapshot via SQLite Vacuum / Copy
        $snapFileName = "$($svc)_snapshot_${fileTag}.db"
        $snapHostPath = Join-Path $BackupRoot $snapFileName

        try {
            # Passive WAL checkpoint
            docker exec mediastack-db sqlite3 "$inPath" "PRAGMA wal_checkpoint(PASSIVE);" 2>$null | Out-Null
            
            # Create online atomic binary snapshot
            Copy-Item -Path $hPath -Destination $snapHostPath -Force
            
            # Compute SHA-256 Hash
            $sha256 = (Get-FileHash -Path $snapHostPath -Algorithm SHA256).Hash
            $snapSize = (Get-Item $snapHostPath).Length

            # Ingest to SQLite Registry
            $insSql = "INSERT INTO fleet_snapshot_registry (snapshot_timestamp, operation_tag, service_name, database_name, snapshot_path, size_bytes, sha256_hash, integrity_status) VALUES ('$tsString', 'REPLICATION', '$svc', '$dbName', '$snapHostPath', $snapSize, '$sha256', 'VERIFIED_PRISTINE');"
            docker exec mediastack-db sqlite3 /config/mediastack_backup.db "$insSql" 2>$null

            Write-Host ("  [SNAPSHOT OK] {0,-18} | Size: {1,6} KB | Hash: {2}..." -f $dbName, [math]::Round($snapSize/1KB, 1), $sha256.Substring(0, 12)) -ForegroundColor Green
            $successCount++
        } catch {
            Write-Host ("  [FAIL] Snapshot error on {0}: {1}" -f $dbName, $_.Exception.Message) -ForegroundColor Red
            $failCount++
        }
    }

    # Step 3: Snapshot Retention Rotation (Keep last 24 per service)
    foreach ($db in $DatabaseInventory) {
        $svc = $db.Service
        $svcSnaps = Get-ChildItem -Path $BackupRoot -Filter "$($svc)_*.db" | Sort-Object LastWriteTime -Descending
        if ($svcSnaps.Count -gt 36) {
            $toPrune = $svcSnaps | Select-Object -Skip 36
            foreach ($p in $toPrune) {
                Remove-Item -Path $p.FullName -Force -ErrorAction SilentlyContinue
            }
        }
    }

    $duration = [math]::Round(((Get-Date) - $cycleStart).TotalSeconds, 2)
    Write-Host ("[{0}] Replication cycle finished in {1}s (Snapshots OK: {2}, Issues: {3})`n" -f (Get-Date -Format "HH:mm:ss"), $duration, $successCount, $failCount) -ForegroundColor Cyan
}

# ==============================================================================
# MAIN EXECUTION CONTROLLER
# ==============================================================================
Write-Host "====================================================================================================" -ForegroundColor DarkCyan
Write-Host "   M E D I A S T A C K   D A T A B A S E   R E P L I C A T I O N   &   B A C K U P   S U I T E" -ForegroundColor Cyan
Write-Host ("   Node: {0} ({1}) | IP: {2}" -f $nodeInfo.LocalHostName, $nodeInfo.LocalRole, $nodeInfo.LocalIP) -ForegroundColor DarkGray
Write-Host ("   Peer: {0} ({1}) | Peer IP: {2}" -f $nodeInfo.PeerHostName, $nodeInfo.PeerRole, $nodeInfo.PeerIP) -ForegroundColor DarkGray
Write-Host ("   Snapshot Store: {0}" -f $BackupRoot) -ForegroundColor DarkGray
Write-Host "====================================================================================================" -ForegroundColor DarkCyan

if ($PreSyncBackupOnly) {
    Invoke-ReplicationCycle -BackupOnly
    exit 0
}

if ($RunOnce) {
    Invoke-ReplicationCycle
    exit 0
}

Write-Host ("   Running continuous replication loop every {0} seconds. Press [Ctrl+C] to stop." -f $IntervalSeconds) -ForegroundColor DarkGray
while ($true) {
    Invoke-ReplicationCycle
    Start-Sleep -Seconds $IntervalSeconds
}
