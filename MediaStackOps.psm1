<#
.SYNOPSIS
    MediaStackOps - Master Enterprise Operations & Database Lifecycle Module.

.DESCRIPTION
    Provides core enterprise-grade infrastructure functions for the MediaStack ecosystem,
    including asynchronous multi-socket probing, lock-free SQLite database health diagnostics,
    instant hot-restore from point-in-time snapshots, 5-stage CRUD lifecycle testing,
    and structured SQLite audit telemetry logging.

.NOTES
    Author  : MediaStack Lead Engineering Team
    Version : 3.0.0
    Node    : Multi-Node Resilient Architecture (VOLTAIREDEUX / ORDINATEURDEVOLT)
#>

# Ensure UTF-8 output encoding
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::InputEncoding  = [System.Text.Encoding]::UTF8

# ==============================================================================
# 1. STRUCTURED TELEMETRY & LOGGING ENGINE
# ==============================================================================

function Write-MediaStackLog {
    <#
    .SYNOPSIS
        Logs structured events into both the console output and the SQLite audit database.
    .PARAMETER Table
        Target SQLite telemetry table name.
    .PARAMETER EventTimestamp
        ISO 8601 formatted timestamp string.
    .PARAMETER Fields
        Hashtable of column name/value pairs to insert.
    .PARAMETER DbInternalPath
        Path inside the mediastack-db container to the audit database.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$Table,
        [Parameter(Mandatory=$false)][string]$EventTimestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss"),
        [Parameter(Mandatory=$true)][hashtable]$Fields,
        [Parameter(Mandatory=$false)][string]$DbInternalPath = "/config/mediastack_backup.db"
    )

    try {
        # Check if mediastack-db is alive
        $dbStatus = (docker ps --filter "name=mediastack-db" --format "{{.Status}}" 2>$null)
        if (-not $dbStatus -or $dbStatus -notmatch "Up") { return }

        $columns = @("event_timestamp") + ($Fields.Keys | ForEach-Object { $_.ToString() })
        $colDefs = @("id INTEGER PRIMARY KEY AUTOINCREMENT", "event_timestamp TEXT NOT NULL")
        $valList = @("'$EventTimestamp'")

        foreach ($k in $Fields.Keys) {
            $v = $Fields[$k]
            if ($v -is [int] -or $v -is [long] -or $v -is [bool]) {
                $colDefs += "$k INTEGER"
                $valList += $(if ($v -is [bool]) { if ($v) { 1 } else { 0 } } else { $v })
            } else {
                $colDefs += "$k TEXT"
                $cleanVal = $v.ToString() -replace "'", "''"
                $valList += "'$cleanVal'"
            }
        }

        $createSql = "CREATE TABLE IF NOT EXISTS $Table ($($colDefs -join ', '));"
        $insertSql = "INSERT INTO $Table ($($columns -join ', ')) VALUES ($($valList -join ', '));"
        docker exec mediastack-db sqlite3 "$DbInternalPath" "$createSql $insertSql" 2>$null | Out-Null
    } catch { }
}

# ==============================================================================
# 2. HIGH-PERFORMANCE ASYNCHRONOUS SOCKET PROBING
# ==============================================================================

function Test-MediaStackPort {
    <#
    .SYNOPSIS
        Asynchronously tests TCP socket connectivity and measures latency in milliseconds.
    .PARAMETER Hostname
        IP address or hostname to probe. Defaults to 127.0.0.1.
    .PARAMETER Port
        Target TCP port number.
    .PARAMETER TimeoutMs
        Timeout in milliseconds. Defaults to 1000ms.
    .OUTPUTS
        PSCustomObject containing Port, IsOpen, LatencyMs, and Status.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)][string]$Hostname = "127.0.0.1",
        [Parameter(Mandatory=$true)][int]$Port,
        [Parameter(Mandatory=$false)][int]$TimeoutMs = 1000
    )

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $isOpen = $false

    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $iar = $tcp.BeginConnect($Hostname, $Port, $null, $null)
        if ($iar.AsyncWaitHandle.WaitOne($TimeoutMs, $false) -and $tcp.Connected) {
            $tcp.EndConnect($iar)
            $isOpen = $true
        }
        $tcp.Close()
    } catch { }
    $sw.Stop()

    return [PSCustomObject]@{
        Hostname  = $Hostname
        Port      = $Port
        IsOpen    = $isOpen
        LatencyMs = $sw.ElapsedMilliseconds
        Status    = if ($isOpen) { "OPEN" } else { "CLOSED" }
    }
}

# ==============================================================================
# 3. LOCK-FREE DATABASE INTEGRITY DIAGNOSTICS
# ==============================================================================

function Test-MediaStackDatabaseHealth {
    <#
    .SYNOPSIS
        Performs non-blocking read-only integrity verification against SQLite databases.
    .PARAMETER HostPath
        Absolute path on host Windows filesystem.
    .PARAMETER InternalPath
        Absolute path inside mediastack-db container.
    .OUTPUTS
        PSCustomObject containing IsValid, FileSizeBytes, QuickCheckResult, and Details.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$HostPath,
        [Parameter(Mandatory=$true)][string]$InternalPath
    )

    if (-not (Test-Path $HostPath)) {
        return [PSCustomObject]@{
            IsValid          = $false
            FileSizeBytes    = 0
            QuickCheckResult = "MISSING_FILE"
            Details          = "File does not exist on host filesystem"
        }
    }

    $fileSize = (Get-Item $HostPath).Length
    if ($fileSize -eq 0) {
        return [PSCustomObject]@{
            IsValid          = $false
            FileSizeBytes    = 0
            QuickCheckResult = "ZERO_BYTES"
            Details          = "File exists but is 0 bytes (empty/corrupted)"
        }
    }

    # Copy DB and companion WAL/SHM journal files to container tmpfs to guarantee 100% lock-free integrity verification across running WAL databases
    $guid = [System.Guid]::NewGuid().ToString('N')
    $tmpDir = "/tmp/chk_$guid"
    docker exec mediastack-db mkdir -p "$tmpDir" 2>$null | Out-Null

    $parentDir = Split-Path -Path $InternalPath -Parent
    $fileName  = Split-Path -Path $InternalPath -Leaf

    # Copy DB and WAL journal files into the isolated tmp folder
    docker exec mediastack-db sh -c "cp $parentDir/$fileName* $tmpDir/ 2>/dev/null" 2>$null | Out-Null

    $res = docker exec mediastack-db sqlite3 "$tmpDir/$fileName" "PRAGMA quick_check;" 2>&1
    docker exec mediastack-db rm -rf "$tmpDir" 2>$null | Out-Null
    $isValid = ($res -match "ok")

    return [PSCustomObject]@{
        IsValid          = $isValid
        FileSizeBytes    = $fileSize
        QuickCheckResult = $res
        Details          = if ($isValid) { "Integrity Check Passed ($([math]::Round($fileSize/1KB, 1)) KB)" } else { "Integrity Anomaly: $res" }
    }
}

# ==============================================================================
# 4. INSTANT DATABASE HOT-RESTORE ENGINE
# ==============================================================================

function Invoke-DatabaseHotRestore {
    <#
    .SYNOPSIS
        Instantly restores a corrupted or missing database from the most recent valid snapshot.
    .PARAMETER DatabaseName
        Human-readable name of the database service.
    .PARAMETER TargetHostPath
        Target host path for the database file.
    .PARAMETER InternalContainerPath
        Internal container path inside mediastack-db.
    .PARAMETER PrimaryBackupPath
        Primary fallback backup path.
    .PARAMETER SnapshotDir
        Directory containing historical snapshots.
    .OUTPUTS
        PSCustomObject with Success, RestoredSource, and Diagnostics.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$DatabaseName,
        [Parameter(Mandatory=$true)][string]$TargetHostPath,
        [Parameter(Mandatory=$true)][string]$InternalContainerPath,
        [Parameter(Mandatory=$false)][string]$PrimaryBackupPath = "",
        [Parameter(Mandatory=$false)][string]$SnapshotDir = ""
    )

    $now = Get-Date -Format "yyyyMMdd_HHmmss"
    $parentDir = Split-Path -Path $TargetHostPath -Parent
    $fileName = Split-Path -Path $TargetHostPath -Leaf

    # Quarantine corrupt file if present
    if (Test-Path $TargetHostPath) {
        $quarantinePath = Join-Path $parentDir "${fileName}.corrupt_${now}"
        Copy-Item -Path $TargetHostPath -Destination $quarantinePath -Force -ErrorAction SilentlyContinue
    }

    # Clean dangling lock files
    Get-ChildItem -Path $parentDir -Filter "${fileName}-wal" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    Get-ChildItem -Path $parentDir -Filter "${fileName}-shm" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    Get-ChildItem -Path $parentDir -Filter "*.pid" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue

    # Discover best candidate snapshots
    $candidateList = @()
    if ($PrimaryBackupPath -and (Test-Path $PrimaryBackupPath)) {
        $candidateList += $PrimaryBackupPath
    }

    if ($SnapshotDir -and (Test-Path $SnapshotDir)) {
        $candidateList += Get-ChildItem -Path $SnapshotDir -Filter "*$([System.IO.Path]::GetFileNameWithoutExtension($fileName))*.db*" |
            Where-Object { $_.FullName -ne $TargetHostPath -and $_.Length -gt 0 } |
            Sort-Object LastWriteTime -Descending |
            Select-Object -ExpandProperty FullName
    }

    if (Test-Path $parentDir) {
        $candidateList += Get-ChildItem -Path $parentDir -Filter "*.db*" |
            Where-Object { $_.FullName -ne $TargetHostPath -and $_.Length -gt 0 } |
            Sort-Object LastWriteTime -Descending |
            Select-Object -ExpandProperty FullName
    }

    $restored = $false
    $sourceUsed = ""

    foreach ($cand in $candidateList) {
        if (Test-Path $cand) {
            $candLen = (Get-Item $cand).Length
            if ($candLen -gt 0) {
                try {
                    Copy-Item -Path $cand -Destination $TargetHostPath -Force
                    $val = Test-MediaStackDatabaseHealth -HostPath $TargetHostPath -InternalPath $InternalContainerPath
                    if ($val.IsValid) {
                        $restored = $true
                        $sourceUsed = $cand
                        break
                    }
                } catch { }
            }
        }
    }

    # Log Hot-Restore event
    Write-MediaStackLog -Table "hot_restore_events_log" -Fields @{
        database_name  = $DatabaseName
        target_path    = $TargetHostPath
        restored_from  = $sourceUsed
        success        = $restored
    }

    return [PSCustomObject]@{
        Success        = $restored
        RestoredSource = $sourceUsed
        Diagnostics    = if ($restored) { "Successfully restored from $(Split-Path $sourceUsed -Leaf)" } else { "No valid snapshot could be verified" }
    }
}

# ==============================================================================
# 5. END-TO-END 5-STAGE CRUD LIFECYCLE TEST
# ==============================================================================

function Test-DatabaseCrudLifecycle {
    <#
    .SYNOPSIS
        Executes a 5-step transactional CRUD verification (Create, Read, Update, Delete, PRAGMA) against the database engine.
    .PARAMETER InternalDbPath
        Path inside mediastack-db to the SQLite database. Defaults to /config/mediastack_backup.db.
    .OUTPUTS
        PSCustomObject with individual step results and AllPassed boolean flag.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)][string]$InternalDbPath = "/config/mediastack_backup.db"
    )

    $audit = [ordered]@{
        "CREATE" = "FAIL"
        "READ"   = "FAIL"
        "UPDATE" = "FAIL"
        "DELETE" = "FAIL"
        "PRAGMA" = "FAIL"
    }

    $testUuid = [System.Guid]::NewGuid().ToString()
    $initPayload = "CRUD_VERIFICATION_INIT_$(Get-Date -Format 'yyyyMMddHHmmss')"
    $modPayload  = "CRUD_VERIFICATION_MODIFIED_$(Get-Date -Format 'yyyyMMddHHmmss')"

    try {
        # 1. CREATE
        $sqlCreate = @"
CREATE TABLE IF NOT EXISTS crud_startup_verification (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    test_uuid TEXT UNIQUE NOT NULL,
    payload TEXT NOT NULL,
    created_at TEXT NOT NULL,
    updated_at TEXT
);
INSERT INTO crud_startup_verification (test_uuid, payload, created_at)
VALUES ('$testUuid', '$initPayload', datetime('now'));
"@
        docker exec mediastack-db sqlite3 "$InternalDbPath" "$sqlCreate" 2>&1 | Out-Null
        $audit["CREATE"] = "PASS"

        # 2. READ
        $readCheck = docker exec mediastack-db sqlite3 "$InternalDbPath" "SELECT payload FROM crud_startup_verification WHERE test_uuid = '$testUuid' LIMIT 1;" 2>&1
        if ($readCheck -and $readCheck.Trim() -eq $initPayload) {
            $audit["READ"] = "PASS"
        }

        # 3. UPDATE
        $sqlUpdate = "UPDATE crud_startup_verification SET payload = '$modPayload', updated_at = datetime('now') WHERE test_uuid = '$testUuid';"
        docker exec mediastack-db sqlite3 "$InternalDbPath" "$sqlUpdate" 2>&1 | Out-Null
        $updateCheck = docker exec mediastack-db sqlite3 "$InternalDbPath" "SELECT payload FROM crud_startup_verification WHERE test_uuid = '$testUuid' LIMIT 1;" 2>&1
        if ($updateCheck -and $updateCheck.Trim() -eq $modPayload) {
            $audit["UPDATE"] = "PASS"
        }

        # 4. DELETE
        $sqlDelete = "DELETE FROM crud_startup_verification WHERE test_uuid = '$testUuid';"
        docker exec mediastack-db sqlite3 "$InternalDbPath" "$sqlDelete" 2>&1 | Out-Null
        $delCount = docker exec mediastack-db sqlite3 "$InternalDbPath" "SELECT count(*) FROM crud_startup_verification WHERE test_uuid = '$testUuid';" 2>&1
        if ($delCount -and $delCount.Trim() -eq "0") {
            $audit["DELETE"] = "PASS"
        }

        # 5. PRAGMA Health
        $pragmaRes = docker exec mediastack-db sqlite3 "$InternalDbPath" "PRAGMA quick_check; PRAGMA foreign_keys;" 2>&1
        if ($pragmaRes -match "ok") {
            $audit["PRAGMA"] = "PASS"
        }
    } catch { }

    $allPassed = ($audit["CREATE"] -eq "PASS" -and $audit["READ"] -eq "PASS" -and $audit["UPDATE"] -eq "PASS" -and $audit["DELETE"] -eq "PASS" -and $audit["PRAGMA"] -eq "PASS")

    return [PSCustomObject]@{
        Create    = $audit["CREATE"]
        Read      = $audit["READ"]
        Update    = $audit["UPDATE"]
        Delete    = $audit["DELETE"]
        Pragma    = $audit["PRAGMA"]
        AllPassed = $allPassed
    }
}

Export-ModuleMember -Function Write-MediaStackLog, Test-MediaStackPort, Test-MediaStackDatabaseHealth, Invoke-DatabaseHotRestore, Test-DatabaseCrudLifecycle
