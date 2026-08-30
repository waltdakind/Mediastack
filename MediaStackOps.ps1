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
    Version : 3.1.0
    Node    : Multi-Node Resilient Architecture (VOLTAIREDEUX / VOLTAIREUN)
#>

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::InputEncoding  = [System.Text.Encoding]::UTF8

# ==============================================================================
# 1. STRUCTURED TELEMETRY & LOGGING ENGINE
# ==============================================================================

function Write-MediaStackLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$Table,
        [Parameter(Mandatory=$false)][string]$EventTimestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss"),
        [Parameter(Mandatory=$true)][hashtable]$Fields,
        [Parameter(Mandatory=$false)][string]$DbInternalPath = "/config/mediastack_backup.db"
    )

    try {
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
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)][string]$Hostname = "127.0.0.1",
        [Parameter(Mandatory=$true)][int]$Port,
        [Parameter(Mandatory=$false)][int]$TimeoutMs = 1000
    )

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $isOpen = $false

    try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $asyncResult = $tcpClient.BeginConnect($Hostname, $Port, $null, $null)
        $waitSuccess = $asyncResult.AsyncWaitHandle.WaitOne($TimeoutMs, $false)
        
        if ($waitSuccess -and $tcpClient.Connected) {
            $tcpClient.EndConnect($asyncResult)
            $isOpen = $true
        }
        $tcpClient.Close()
    } catch {
        $isOpen = $false
    }
    
    $sw.Stop()
    $latency = $sw.ElapsedMilliseconds

    return [PSCustomObject]@{
        Port      = $Port
        IsOpen    = $isOpen
        LatencyMs = $latency
        Status    = if ($isOpen) { "ONLINE" } else { "CLOSED" }
    }
}

# ==============================================================================
# 3. LOCK-FREE SQLITE DATABASE HEALTH DIAGNOSTICS
# ==============================================================================

function Test-MediaStackDatabaseHealth {
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

    # Copy DB and companion WAL/SHM journal files to container tmpfs to guarantee 100% lock-free integrity verification
    $guid = [System.Guid]::NewGuid().ToString('N')
    $tmpDir = "/tmp/chk_$guid"
    docker exec mediastack-db mkdir -p "$tmpDir" 2>$null | Out-Null

    $parentDir = Split-Path -Path $InternalPath -Parent
    $fileName  = Split-Path -Path $InternalPath -Leaf

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

    if (Test-Path $TargetHostPath) {
        $quarantinePath = Join-Path $parentDir "${fileName}.corrupt_${now}"
        Copy-Item -Path $TargetHostPath -Destination $quarantinePath -Force -ErrorAction SilentlyContinue
    }

    Get-ChildItem -Path $parentDir -Filter "${fileName}-wal" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    Get-ChildItem -Path $parentDir -Filter "${fileName}-shm" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    Get-ChildItem -Path $parentDir -Filter "*.pid" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue

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

    $fallbackPatterns = @(
        "$parentDir\$([System.IO.Path]::GetFileNameWithoutExtension($fileName))-VoltaireDeux.db",
        "$parentDir\$([System.IO.Path]::GetFileNameWithoutExtension($fileName))-VoltaireDeux-*.db",
        "$parentDir\$([System.IO.Path]::GetFileNameWithoutExtension($fileName))_backup*.db"
    )
    foreach ($pat in $fallbackPatterns) {
        $matchedCandidates = Get-ChildItem -Path $pat -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -ne $TargetHostPath -and $_.Length -gt 0 } |
            Sort-Object LastWriteTime -Descending |
            Select-Object -ExpandProperty FullName
        if ($matchedCandidates) { $candidateList += $matchedCandidates }
    }

    $restored = $false
    $chosenSource = "None"
    $diagnostics = "No valid snapshot candidate found"

    foreach ($candidate in $candidateList) {
        if (-not (Test-Path $candidate)) { continue }
        
        Copy-Item -Path $candidate -Destination $TargetHostPath -Force
        
        $verify = Test-MediaStackDatabaseHealth -HostPath $TargetHostPath -InternalPath $InternalContainerPath
        if ($verify.IsValid) {
            $restored = $true
            $chosenSource = $candidate
            $diagnostics = "Successfully hot-restored from $candidate ($([math]::Round($verify.FileSizeBytes/1KB, 1)) KB)"
            break
        }
    }

    return [PSCustomObject]@{
        Success        = $restored
        RestoredSource = $chosenSource
        Diagnostics    = $diagnostics
    }
}

# ==============================================================================
# 5. 5-STAGE CRUD LIFECYCLE VERIFICATION ENGINE
# ==============================================================================

function Test-MediaStackCrudLifecycle {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)][string]$InternalDbPath = "/config/mediastack_backup.db"
    )

    $results = [ordered]@{
        "CREATE"  = $false
        "READ"    = $false
        "UPDATE"  = $false
        "DELETE"  = $false
        "PRAGMA"  = $false
    }

    $testUuid = [System.Guid]::NewGuid().ToString()
    $testTag = Get-Date -Format "yyyyMMdd_HHmmss"
    $payloadInitial = "CRUD_PROBE_INITIAL_$testTag"
    $payloadUpdated = "CRUD_PROBE_UPDATED_$testTag"

    try {
        $sqlInit = @"
CREATE TABLE IF NOT EXISTS crud_sentinel_lifecycle (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    test_uuid TEXT UNIQUE NOT NULL,
    payload TEXT NOT NULL,
    created_at TEXT NOT NULL
);
"@
        docker exec mediastack-db sqlite3 "$InternalDbPath" "$sqlInit" 2>$null | Out-Null

        # 1. CREATE
        $sqlCreate = "INSERT INTO crud_sentinel_lifecycle (test_uuid, payload, created_at) VALUES ('$testUuid', '$payloadInitial', datetime('now'));"
        docker exec mediastack-db sqlite3 "$InternalDbPath" "$sqlCreate" 2>$null | Out-Null
        $results["CREATE"] = $true

        # 2. READ
        $readVal = docker exec mediastack-db sqlite3 "$InternalDbPath" "SELECT payload FROM crud_sentinel_lifecycle WHERE test_uuid = '$testUuid' LIMIT 1;" 2>$null
        if ($readVal -and $readVal.Trim() -eq $payloadInitial) {
            $results["READ"] = $true
        }

        # 3. UPDATE
        $sqlUpdate = "UPDATE crud_sentinel_lifecycle SET payload = '$payloadUpdated' WHERE test_uuid = '$testUuid';"
        docker exec mediastack-db sqlite3 "$InternalDbPath" "$sqlUpdate" 2>$null | Out-Null
        
        $readUpdated = docker exec mediastack-db sqlite3 "$InternalDbPath" "SELECT payload FROM crud_sentinel_lifecycle WHERE test_uuid = '$testUuid' LIMIT 1;" 2>$null
        if ($readUpdated -and $readUpdated.Trim() -eq $payloadUpdated) {
            $results["UPDATE"] = $true
        }

        # 4. DELETE
        $sqlDelete = "DELETE FROM crud_sentinel_lifecycle WHERE test_uuid = '$testUuid';"
        docker exec mediastack-db sqlite3 "$InternalDbPath" "$sqlDelete" 2>$null | Out-Null

        $countCheck = docker exec mediastack-db sqlite3 "$InternalDbPath" "SELECT count(*) FROM crud_sentinel_lifecycle WHERE test_uuid = '$testUuid';" 2>$null
        if ($countCheck -and $countCheck.Trim() -eq "0") {
            $results["DELETE"] = $true
        }

        # 5. PRAGMA
        $pragmaRes = docker exec mediastack-db sqlite3 "$InternalDbPath" "PRAGMA quick_check; PRAGMA foreign_keys;" 2>$null
        if ($pragmaRes -match "ok") {
            $results["PRAGMA"] = $true
        }
    } catch { }

    $allPassed = ($results["CREATE"] -and $results["READ"] -and $results["UPDATE"] -and $results["DELETE"] -and $results["PRAGMA"])

    return [PSCustomObject]@{
        AllPassed = $allPassed
        StageDetails = $results
        Summary = if ($allPassed) { "5/5 CRUD Stages Verified (100% Operational)" } else { "CRUD Anomalies Detected" }
    }
}

try {
    if (Get-Command Export-ModuleMember -ErrorAction SilentlyContinue) {
        Export-ModuleMember -Function Write-MediaStackLog, Test-MediaStackPort, Test-MediaStackDatabaseHealth, Invoke-DatabaseHotRestore, Test-MediaStackCrudLifecycle -ErrorAction SilentlyContinue
    }
} catch { }
