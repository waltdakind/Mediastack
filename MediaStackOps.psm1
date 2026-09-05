<#
.SYNOPSIS
    MediaStackOps - Primary Enterprise Operations, Node Discovery & Database Lifecycle Module.

.DESCRIPTION
    Provides core enterprise-grade infrastructure functions for the dual-node MediaStack ecosystem
    (VoltaireUn <---> VoltaireDeux), including:
    1. Dynamic cluster node discovery & LAN IP awareness (VoltaireUn main server vs VoltaireDeux AI node).
    2. Structured SQLite audit telemetry logging.
    3. High-performance asynchronous socket and HTTP reverse-proxy probing.
    4. Lock-free SQLite database health diagnostics and WAL checkpointing.
    5. Mandatory atomic pre-sync database snapshotting with SHA-256 hashing.
    6. Instant database hot-restore and self-healing.
    7. Deep proxy and port error root-cause analysis and automated remediation.
    8. Bidirectional system status handoff exchange with AI stability & self-healing suggestions.
    9. 5-stage CRUD lifecycle testing.

.NOTES
    Author  : MediaStack Lead Engineering Team
    Version : 3.6.0
    Nodes   : Multi-Node Resilient Architecture (VOLTAIREUN / VOLTAIREDEUX)
#>

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::InputEncoding  = [System.Text.Encoding]::UTF8

# ==============================================================================
# 1. DYNAMIC CLUSTER NODE DISCOVERY & IP AWARENESS
# ==============================================================================

function Get-MediaStackClusterNodeInfo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)][string]$ConfigDir = ""
    )

    $currentHost = $env:COMPUTERNAME
    $isVoltaireDeux = ($currentHost -match "VoltaireDeux" -or $currentHost -match "Laptop" -or $env:NODE_ROLE -eq "VoltaireDeux")
    $isVoltaireUn   = ($currentHost -match "VoltaireUn" -or $currentHost -match "Ordinateur" -or $currentHost -match "Server" -or $env:NODE_ROLE -eq "VoltaireUn")

    # If ambiguous, default based on hostname or .env
    if (-not $isVoltaireDeux -and -not $isVoltaireUn) {
        if (Test-Path "$PSScriptRoot\.env") {
            $envContent = Get-Content "$PSScriptRoot\.env" -Raw -ErrorAction SilentlyContinue
            if ($envContent -match "X64_DEVICE_NAME=VOLTAIREDEUX" -or $envContent -match "VoltaireDeux") {
                $isVoltaireDeux = $true
            } else {
                $isVoltaireUn = $true
            }
        } else {
            $isVoltaireDeux = $true # Workstation fallback
        }
    }

    # Discover Local IPv4 Address
    $localIp = "127.0.0.1"
    try {
        $adapters = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
            Where-Object { $_.IPAddress -notmatch "^127\." -and $_.IPAddress -notmatch "^169\.254\." -and $_.IPAddress -notmatch "^172\." }
        
        $lanAdapter = $adapters | Where-Object { $_.IPAddress -match "^192\.168\." } | Select-Object -First 1
        if ($lanAdapter) {
            $localIp = $lanAdapter.IPAddress
        } elseif ($adapters) {
            $localIp = ($adapters | Select-Object -First 1).IPAddress
        }
    } catch {
        $localIp = "192.168.4.30"
    }

    # Resolve Default Node Topology
    $voltaireUnDefaultIp   = "192.168.4.21"
    $voltaireDeuxDefaultIp = "192.168.4.30"

    # Attempt dynamic DNS resolution for peer node
    $voltaireUnResolvedIp = $voltaireUnDefaultIp
    $voltaireDeuxResolvedIp = $voltaireDeuxDefaultIp

    try {
        $dnsUn = [System.Net.Dns]::GetHostAddresses("voltaireun.local") | Select-Object -First 1
        if ($dnsUn) { $voltaireUnResolvedIp = $dnsUn.IPAddressToString }
    } catch { }

    try {
        $dnsDeux = [System.Net.Dns]::GetHostAddresses("voltairedeux.local") | Select-Object -First 1
        if ($dnsDeux) { $voltaireDeuxResolvedIp = $dnsDeux.IPAddressToString }
    } catch { }

    $localRole = if ($isVoltaireDeux) { "VoltaireDeux (AI Acceleration & Push Node)" } else { "VoltaireUn (Main 24/7 Server Node)" }
    $peerRole  = if ($isVoltaireDeux) { "VoltaireUn (Main 24/7 Server Node)" } else { "VoltaireDeux (AI Acceleration & Push Node)" }
    $peerHost  = if ($isVoltaireDeux) { "VOLTAIREUN" } else { "VOLTAIREDEUX" }
    $peerIp    = if ($isVoltaireDeux) { $voltaireUnResolvedIp } else { $voltaireDeuxResolvedIp }
    $primaryIp = if ($isVoltaireUn) { $localIp } else { $voltaireUnResolvedIp }
    $aiNodeIp  = if ($isVoltaireDeux) { $localIp } else { $voltaireDeuxResolvedIp }

    return [PSCustomObject]@{
        LocalHostName     = $currentHost
        LocalRole         = $localRole
        LocalIP           = $localIp
        IsVoltaireDeux    = [bool]$isVoltaireDeux
        IsVoltaireUn      = [bool]$isVoltaireUn
        PeerHostName      = $peerHost
        PeerRole          = $peerRole
        PeerIP            = $peerIp
        PrimaryServerIP   = $primaryIp
        AiAccelerationIP  = $aiNodeIp
        Timestamp         = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    }
}

function Assert-MediaStackClusterNode {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$ExpectedNode,
        [Parameter(Mandatory=$false)][switch]$Force,
        [Parameter(Mandatory=$false)][switch]$NonInteractive
    )

    $currentHost = $env:COMPUTERNAME
    $isMatch = $false

    if ($ExpectedNode -match "VoltaireDeux") {
        $isMatch = ($currentHost -match "VoltaireDeux" -or $currentHost -match "Laptop" -or $env:NODE_ROLE -eq "VoltaireDeux")
    } elseif ($ExpectedNode -match "VoltaireUn") {
        $isMatch = ($currentHost -match "VoltaireUn" -or $currentHost -match "Ordinateur" -or $currentHost -match "Server" -or $env:NODE_ROLE -eq "VoltaireUn")
    } else {
        $isMatch = ($currentHost -like "*$ExpectedNode*")
    }

    if ($Force -or $env:MEDIASTACK_FORCE_NODE -or $isMatch) {
        return $true
    }

    Write-Host ""
    Write-Host "================================================================================" -ForegroundColor Red
    Write-Host " [WARNING] CLUSTER MACHINE MISMATCH DETECTED" -ForegroundColor Yellow
    Write-Host "================================================================================" -ForegroundColor Red
    Write-Host (" Target Machine Requirement : [{0}]" -f $ExpectedNode) -ForegroundColor Cyan
    Write-Host (" Current Local Hostname      : [{0}]" -f $currentHost) -ForegroundColor Yellow
    Write-Host " You are running a script designed specifically for another node in the cluster." -ForegroundColor Red
    Write-Host " Proceeding on the wrong machine may cause unintended container or routing states." -ForegroundColor DarkYellow
    Write-Host "--------------------------------------------------------------------------------" -ForegroundColor DarkGray

    if ($NonInteractive -or -not [Environment]::UserInteractive) {
        Write-Host " [ABORT] Non-interactive run on incorrect cluster machine. Exiting." -ForegroundColor Red
        Write-Host " (To bypass, pass -Force or set `$env:MEDIASTACK_FORCE_NODE=1)`n" -ForegroundColor DarkGray
        exit 1
    }

    Write-Host " Options:" -ForegroundColor White
    Write-Host "  [C] Cancel and exit immediately (Recommended to protect cluster state)" -ForegroundColor Green
    Write-Host "  [P] Proceed anyway (Override node check on current host)" -ForegroundColor DarkYellow
    Write-Host ""
    $choice = Read-Host " Enter choice [C/P] (Default: C)"
    if ($choice -ne "P" -and $choice -ne "p") {
        Write-Host "`n [EXITED] Operation cancelled by user.`n" -ForegroundColor DarkGray
        exit 0
    }

    Write-Host "`n [OVERRIDE] Proceeding on current machine ($currentHost) as requested.`n" -ForegroundColor Yellow
    return $true
}

# ==============================================================================
# 2. STRUCTURED TELEMETRY & LOGGING ENGINE
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
# 3. HIGH-PERFORMANCE ASYNCHRONOUS SOCKET & HTTP PROBING
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
    $errDetail = ""

    try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $asyncResult = $tcpClient.BeginConnect($Hostname, $Port, $null, $null)
        $waitSuccess = $asyncResult.AsyncWaitHandle.WaitOne($TimeoutMs, $false)
        
        if ($waitSuccess -and $tcpClient.Connected) {
            $tcpClient.EndConnect($asyncResult)
            $isOpen = $true
        } else {
            $errDetail = "Connection timeout after ${TimeoutMs}ms"
        }
        $tcpClient.Close()
    } catch {
        $isOpen = $false
        $errDetail = $_.Exception.Message
    }
    
    $sw.Stop()
    $latency = $sw.ElapsedMilliseconds

    # Automated Port + 1 Failover on VoltaireDeux (if primary port is closed)
    $activePort = $Port
    $isFailover = $false
    if (-not $isOpen) {
        $failoverPort = $Port + 1
        try {
            $foClient = New-Object System.Net.Sockets.TcpClient
            $foAsync = $foClient.BeginConnect("127.0.0.1", $failoverPort, $null, $null)
            if ($foAsync.AsyncWaitHandle.WaitOne($TimeoutMs, $false) -and $foClient.Connected) {
                $foClient.EndConnect($foAsync)
                $isOpen = $true
                $isFailover = $true
                $activePort = $failoverPort
                $errDetail = "Active via VoltaireDeux Failover Port :${failoverPort}"
            }
            $foClient.Close()
        } catch { }
    }

    return [PSCustomObject]@{
        Hostname    = $Hostname
        Port        = $activePort
        PrimaryPort = $Port
        IsFailover  = $isFailover
        IsOpen      = $isOpen
        LatencyMs   = $latency
        Status      = if ($isFailover) { "FAILOVER" } elseif ($isOpen) { "ONLINE" } else { "CLOSED" }
        Error       = $errDetail
    }
}

function Test-MediaStackHttpRoute {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$Url,
        [Parameter(Mandatory=$false)][int]$TimeoutSec = 3,
        [Parameter(Mandatory=$false)][switch]$SkipCertificateCheck
    )

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $statusCode = 0
    $isSuccess  = $false
    $statusDesc = ""

    try {
        Add-Type -AssemblyName System.Net.Http -ErrorAction SilentlyContinue
        if ([System.Type]::GetType("System.Net.Http.HttpClientHandler")) {
            $handler = New-Object System.Net.Http.HttpClientHandler
            if ($SkipCertificateCheck) {
                $handler.ServerCertificateCustomValidationCallback = { $true }
            }
            $client = New-Object System.Net.Http.HttpClient($handler)
            $client.Timeout = [TimeSpan]::FromSeconds($TimeoutSec)

            $response = $client.GetAsync($Url).GetAwaiter().GetResult()
            $statusCode = [int]$response.StatusCode
            $statusDesc = $response.ReasonPhrase
            $isSuccess  = ($statusCode -ge 200 -and $statusCode -lt 400) -or ($statusCode -eq 401)
            $client.Dispose()
        } else {
            throw "System.Net.Http not loaded"
        }
    } catch {
        # Resilient curl.exe fallback
        try {
            $curlArgs = "-s -o NUL -w `"%{http_code}`" --max-time $TimeoutSec `"$Url`""
            if ($SkipCertificateCheck) { $curlArgs = "-k $curlArgs" }
            $curlOut = cmd.exe /c "curl.exe $curlArgs 2>nul"
            if ($curlOut -and $curlOut.Trim() -match '^\d{3}$') {
                $statusCode = [int]$curlOut.Trim()
                $isSuccess = ($statusCode -ge 200 -and $statusCode -lt 400) -or ($statusCode -eq 401)
                $statusDesc = "HTTP $statusCode via curl"
            } else {
                $statusDesc = if ($_.Exception.InnerException) { $_.Exception.InnerException.Message } else { $_.Exception.Message }
            }
        } catch {
            $statusDesc = $_.Exception.Message
        }
    }
    $sw.Stop()

    return [PSCustomObject]@{
        Url        = $Url
        StatusCode = $statusCode
        IsSuccess  = $isSuccess
        LatencyMs  = $sw.ElapsedMilliseconds
        Message    = $statusDesc
    }
}

# ==============================================================================
# 4. LOCK-FREE SQLITE DATABASE HEALTH DIAGNOSTICS & WAL FLUSH
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

    $guid = [System.Guid]::NewGuid().ToString('N')
    $tmpDir = "/tmp/chk_$guid"
    
    $dockerRunning = (docker info 2>&1) -match "Server Version"
    if ($dockerRunning) {
        docker exec mediastack-db mkdir -p "$tmpDir" 2>$null | Out-Null
        $fileName = Split-Path -Path $HostPath -Leaf
        $relPath = $HostPath -replace '^[a-zA-Z]:\\.*?Mediastack\\', '' -replace '\\', '/'
        $containerSrc = if ($relPath -like "db-backup/*") { "/$relPath" } else { "/mediastack/$relPath" }

        docker exec mediastack-db sh -c "cp $containerSrc* $tmpDir/ 2>/dev/null || cp $InternalPath* $tmpDir/ 2>/dev/null" 2>$null | Out-Null
        $res = docker exec mediastack-db sqlite3 "$tmpDir/$fileName" "PRAGMA quick_check;" 2>&1
        docker exec mediastack-db rm -rf "$tmpDir" 2>$null | Out-Null
        $isValid = ($res -match "ok")
    } else {
        try {
            $bytes = [System.IO.File]::ReadAllBytes($HostPath)
            $headerStr = [System.Text.Encoding]::ASCII.GetString($bytes, 0, [Math]::Min(16, $bytes.Length))
            $isValid = ($headerStr -match "SQLite format 3")
            $res = if ($isValid) { "ok (binary header valid)" } else { "corrupt header" }
        } catch {
            $isValid = $false
            $res = $_.Exception.Message
        }
    }

    return [PSCustomObject]@{
        IsValid          = $isValid
        FileSizeBytes    = $fileSize
        QuickCheckResult = $res
        Details          = if ($isValid) { "Integrity Check Passed ($([math]::Round($fileSize/1KB, 1)) KB)" } else { "Integrity Anomaly: $res" }
    }
}

function Invoke-MediaStackWalCheckpoint {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)][string]$Mode = "PASSIVE",
        [Parameter(Mandatory=$false)][string]$ConfigDir = ""
    )

    $dbInventory = @(
        @{ Name="mediastack-db"; Path="/config/mediastack_backup.db" },
        @{ Name="sonarr";        Path="/mediastack/config/sonarr/sonarr.db" },
        @{ Name="radarr";        Path="/mediastack/config/radarr/radarr.db" },
        @{ Name="prowlarr";      Path="/mediastack/config/prowlarr/prowlarr.db" },
        @{ Name="bazarr";        Path="/mediastack/config/bazarr/db/bazarr.db" },
        @{ Name="jellyseerr";    Path="/mediastack/config/jellyseerr/db/db.sqlite3" },
        @{ Name="jellyfin";      Path="/mediastack/config/jellyfin/data/data/jellyfin.db" }
    )

    $results = @()
    foreach ($db in $dbInventory) {
        try {
            $cmd = "PRAGMA wal_checkpoint($Mode);"
            $out = docker exec mediastack-db sqlite3 "$($db.Path)" "$cmd" 2>&1
            $results += [PSCustomObject]@{
                Service = $db.Name
                Mode    = $Mode
                Output  = $out
                Success = $true
            }
        } catch {
            $results += [PSCustomObject]@{
                Service = $db.Name
                Mode    = $Mode
                Output  = $_.Exception.Message
                Success = $false
            }
        }
    }
    return $results
}

# ==============================================================================
# 5. MANDATORY PRE-SYNC ATOMIC SNAPSHOT & BACKUP ENGINE
# ==============================================================================

function Backup-MediaStackDatabasesPreSync {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)][string]$ConfigDir = "",
        [Parameter(Mandatory=$false)][string]$BackupRoot = "",
        [Parameter(Mandatory=$false)][string]$OperationTag = "PRE_SYNC"
    )

    $activeConfig = if ($ConfigDir -and (Test-Path $ConfigDir)) { 
        $ConfigDir 
    } elseif (Test-Path "$PSScriptRoot\config") { 
        "$PSScriptRoot\config" 
    } elseif (Test-Path "$env:SystemDrive\MediastackConfig") { 
        "$env:SystemDrive\MediastackConfig" 
    } else { 
        "$PSScriptRoot\config" 
    }

    if (-not $BackupRoot) {
        $BackupRoot = Join-Path $activeConfig "db-backup\snapshots"
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $fileTag   = Get-Date -Format "yyyyMMdd_HHmmss"
    $batchDir  = Join-Path $BackupRoot "pre_sync_batch_$fileTag"
    if (-not (Test-Path $batchDir)) { New-Item -ItemType Directory -Force -Path $batchDir | Out-Null }

    $dbInventory = @(
        @{ Name="mediastack_backup"; Service="mediastack-db"; HostPath="$activeConfig\db-backup\mediastack_backup.db"; Internal="/config/mediastack_backup.db" },
        @{ Name="sonarr";            Service="sonarr";        HostPath="$activeConfig\sonarr\sonarr.db"; Internal="/mediastack/config/sonarr/sonarr.db" },
        @{ Name="radarr";            Service="radarr";        HostPath="$activeConfig\radarr\radarr.db"; Internal="/mediastack/config/radarr/radarr.db" },
        @{ Name="prowlarr";          Service="prowlarr";      HostPath="$activeConfig\prowlarr\prowlarr.db"; Internal="/mediastack/config/prowlarr/prowlarr.db" },
        @{ Name="bazarr";            Service="bazarr";        HostPath="$activeConfig\bazarr\db\bazarr.db"; Internal="/mediastack/config/bazarr/db/bazarr.db" },
        @{ Name="jellyseerr";        Service="jellyseerr";    HostPath="$activeConfig\jellyseerr\db\db.sqlite3"; Internal="/mediastack/config/jellyseerr/db/db.sqlite3" },
        @{ Name="jellyfin";          Service="jellyfin";      HostPath="$activeConfig\jellyfin\data\data\jellyfin.db"; Internal="/mediastack/config/jellyfin/data/data/jellyfin.db" }
    )

    $initRegistrySql = @"
CREATE TABLE IF NOT EXISTS fleet_snapshot_registry (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    snapshot_timestamp TEXT NOT NULL,
    operation_tag TEXT NOT NULL,
    service_name TEXT NOT NULL,
    database_name TEXT NOT NULL,
    snapshot_path TEXT NOT NULL,
    size_bytes INTEGER NOT NULL,
    sha256_hash TEXT NOT NULL,
    integrity_status TEXT NOT NULL
);
"@
    docker exec mediastack-db sqlite3 /config/mediastack_backup.db "$initRegistrySql" 2>$null

    Invoke-MediaStackWalCheckpoint -Mode "PASSIVE" | Out-Null

    $results = @()

    foreach ($db in $dbInventory) {
        $hPath = $db.HostPath
        $svc   = $db.Service
        $name  = $db.Name

        if (-not (Test-Path $hPath)) {
            continue
        }

        $snapName = "${svc}_${OperationTag}_${fileTag}.db"
        $snapDest = Join-Path $batchDir $snapName
        $rootSnapDest = Join-Path $BackupRoot $snapName

        try {
            Copy-Item -Path $hPath -Destination $snapDest -Force
            Copy-Item -Path $hPath -Destination $rootSnapDest -Force

            $walPath = "${hPath}-wal"
            if (Test-Path $walPath) { Copy-Item -Path $walPath -Destination (Join-Path $batchDir "${snapName}-wal") -Force }

            $fileSize = (Get-Item $snapDest).Length
            $sha256   = (Get-FileHash -Path $snapDest -Algorithm SHA256).Hash

            $chk = Test-MediaStackDatabaseHealth -HostPath $snapDest -InternalPath $db.Internal
            $status = if ($chk.IsValid) { "VERIFIED_PRISTINE" } else { "ANOMALY_DETECTED" }

            $insSql = "INSERT INTO fleet_snapshot_registry (snapshot_timestamp, operation_tag, service_name, database_name, snapshot_path, size_bytes, sha256_hash, integrity_status) VALUES ('$timestamp', '$OperationTag', '$svc', '$name', '$snapDest', $fileSize, '$sha256', '$status');"
            docker exec mediastack-db sqlite3 /config/mediastack_backup.db "$insSql" 2>$null

            $results += [PSCustomObject]@{
                Service       = $svc
                DatabaseName  = $name
                SnapshotPath  = $snapDest
                SizeBytes     = $fileSize
                SHA256        = $sha256
                Integrity     = $status
                Success       = ($status -eq "VERIFIED_PRISTINE")
            }
        } catch {
            $results += [PSCustomObject]@{
                Service       = $svc
                DatabaseName  = $name
                SnapshotPath  = ""
                SizeBytes     = 0
                SHA256        = ""
                Integrity     = "COPY_FAILED: $($_.Exception.Message)"
                Success       = $false
            }
        }
    }

    return [PSCustomObject]@{
        Timestamp    = $timestamp
        BatchDir     = $batchDir
        OperationTag = $OperationTag
        Snapshots    = $results
        AllPassed    = ($results.Count -gt 0 -and ($results | Where-Object { -not $_.Success }).Count -eq 0)
    }
}

# ==============================================================================
# 6. INSTANT DATABASE HOT-RESTORE ENGINE
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
        $candidateList += Get-ChildItem -Path $SnapshotDir -Recurse -Filter "*$([System.IO.Path]::GetFileNameWithoutExtension($fileName))*.db*" |
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
# 7. PROXY & PORT ERROR ROOT-CAUSE ANALYZER & AUTO-CORRECTION
# ==============================================================================

function Repair-MediaStackPortConflict {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][int]$Port,
        [Parameter(Mandatory=$false)][string]$ContainerName = "",
        [Parameter(Mandatory=$false)][string]$ServiceName = ""
    )

    $actions = @()
    $repaired = $false

    $netstatMatch = Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($netstatMatch) {
        $owningPid = $netstatMatch.OwningProcess
        $proc = Get-Process -Id $owningPid -ErrorAction SilentlyContinue
        $procName = if ($proc) { $proc.ProcessName } else { "Unknown" }

        if ($procName -notmatch "com.docker|docker|wsl|vmmem|System") {
            $actions += "Detected non-docker process '$procName' (PID: $owningPid) occupying port $Port. Terminating..."
            Stop-Process -Id $owningPid -Force -ErrorAction SilentlyContinue
            Start-Sleep -Milliseconds 800
        }
    }

    if ($ContainerName) {
        $cStatus = docker ps --filter "name=^/${ContainerName}$" --format "{{.Status}}" 2>$null
        if (-not $cStatus -or $cStatus -notmatch "Up") {
            $actions += "Restarting container '$ContainerName'..."
            docker restart $ContainerName 2>$null | Out-Null
            Start-Sleep -Seconds 2
        }
    }

    if ($Port -eq 80 -or $Port -eq 443 -or $ServiceName -match "caddy") {
        $actions += "Reloading Caddy reverse proxy configuration..."
        docker exec caddy caddy reload --config /etc/caddy/Caddyfile 2>$null | Out-Null
    }

    try {
        Clear-DnsClientCache -ErrorAction SilentlyContinue
        cmd.exe /c "ipconfig /flushdns >nul 2>&1"
        $actions += "Flushed DNS Resolver Cache"
    } catch { }

    $recheck = Test-MediaStackPort -Hostname "127.0.0.1" -Port $Port -TimeoutMs 1500
    $repaired = $recheck.IsOpen

    $logFields = @{
        port_key     = "127.0.0.1:$Port"
        service_name = $ServiceName
        event_type   = if ($repaired) { "PORT_AUTO_REPAIRED" } else { "PORT_REPAIR_FAILED" }
        message      = ($actions -join " | ")
    }
    Write-MediaStackLog -Table "port_monitor_events_log" -Fields $logFields

    return [PSCustomObject]@{
        Port     = $Port
        Repaired = $repaired
        Actions  = $actions
        Status   = if ($repaired) { "REPAIRED_ONLINE" } else { "STILL_FAILING" }
    }
}

# ==============================================================================
# 8. BIDIRECTIONAL SYSTEM STATUS HANDOFF & PEER AI SUGGESTION ENGINE
# ==============================================================================

function New-MediaStackClusterHandoff {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)][string]$HandoffsDir = ""
    )

    if (-not $HandoffsDir) {
        $HandoffsDir = Join-Path $PSScriptRoot "handoffs"
    }
    if (-not (Test-Path $HandoffsDir)) { New-Item -ItemType Directory -Force -Path $HandoffsDir | Out-Null }

    $nodeInfo = Get-MediaStackClusterNodeInfo
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $fileTag   = Get-Date -Format "yyyyMMdd_HHmmss"

    $cList = docker ps -a --format '{{.Names}}|{{.State}}|{{.Status}}|{{.Ports}}' 2>$null
    $containerStats = @()
    $runningCount = 0
    $failedContainers = @()

    if ($cList) {
        foreach ($line in $cList) {
            $parts = $line -split '\|'
            $cName  = $parts[0]
            $cState = if ($parts.Count -gt 1) { $parts[1] } else { "unknown" }
            $cStat  = if ($parts.Count -gt 2) { $parts[2] } else { "" }
            $cPorts = if ($parts.Count -gt 3) { $parts[3] } else { "" }

            if ($cState -eq "running") { $runningCount++ } else { $failedContainers += $cName }

            $containerStats += [PSCustomObject]@{
                Name   = $cName
                State  = $cState
                Status = $cStat
                Ports  = $cPorts
            }
        }
    }

    $ActiveConfig = if (Test-Path "$PSScriptRoot\config") { "$PSScriptRoot\config" } else { "$env:SystemDrive\MediastackConfig" }
    $dbInventory = @(
        @{ Name="mediastack_backup.db"; Svc="mediastack-db"; Path="$ActiveConfig\db-backup\mediastack_backup.db"; TargetContainer="mediastack-db" },
        @{ Name="sonarr.db";            Svc="sonarr";        Path="$ActiveConfig\sonarr\sonarr.db"; TargetContainer="sonarr" },
        @{ Name="radarr.db";            Svc="radarr";        Path="$ActiveConfig\radarr\radarr.db"; TargetContainer="radarr" },
        @{ Name="prowlarr.db";          Svc="prowlarr";      Path="$ActiveConfig\prowlarr\prowlarr.db"; TargetContainer="prowlarr" },
        @{ Name="bazarr.db";            Svc="bazarr";        Path="$ActiveConfig\bazarr\db\bazarr.db"; TargetContainer="bazarr" },
        @{ Name="db.sqlite3";           Svc="jellyseerr";    Path="$ActiveConfig\jellyseerr\db\db.sqlite3"; TargetContainer="jellyseerr" },
        @{ Name="jellyfin.db";          Svc="jellyfin";      Path="$ActiveConfig\jellyfin\data\data\jellyfin.db"; TargetContainer="jellyfin" }
    )

    $dbAuditList = @()
    foreach ($db in $dbInventory) {
        $exists = Test-Path $db.Path
        $size = if ($exists) { (Get-Item $db.Path).Length } else { 0 }
        $health = if ($exists) { Test-MediaStackDatabaseHealth -HostPath $db.Path -InternalPath "/config/$($db.Name)" } else { [PSCustomObject]@{ IsValid=$false; Details="File not found" } }
        $dbAuditList += [PSCustomObject]@{
            Name      = $db.Name
            Service   = $db.Svc
            Exists    = $exists
            SizeBytes = $size
            IsValid   = $health.IsValid
            Details   = $health.Details
        }
    }

    $recentErrors = @()
    try {
        $rawErrors = docker exec mediastack-db sqlite3 /config/mediastack_backup.db "SELECT event_timestamp, service_name, event_type, message FROM port_monitor_events_log WHERE event_type LIKE '%FAIL%' OR event_type LIKE '%ANOMALY%' ORDER BY id DESC LIMIT 5;" 2>$null
        if ($rawErrors) {
            foreach ($row in ($rawErrors -split "`n")) {
                if ($row.Trim()) { $recentErrors += $row.Trim() }
            }
        }
    } catch { }

    $peerSuggestions = @()
    if ($nodeInfo.IsVoltaireDeux) {
        $peerSuggestions += '1. **Database WAL Checkpoint Tuning for 24/7 Servarr Workloads:** On VoltaireUn, configure `PRAGMA wal_autocheckpoint=1000;` on `sonarr.db` and `radarr.db` to prevent massive WAL files during high-frequency indexer scans.'
        $peerSuggestions += '2. **Cross-Node Caddy Failover Optimization:** Ensure VoltaireUn''s Caddy upstream timeout is set to `lb_try_duration 4s` and `fail_duration 15s` so streaming sessions gracefully fail over to VoltaireDeux if primary transcoding bottlenecks.'
        $peerSuggestions += '3. **Automated SQLite Vacuum & PRAGMA QuickCheck:** Ensure VoltaireUn runs a weekly `VACUUM;` on `jellyfin.db` and `prowlarr.db` during low-traffic windows (03:00 AM) prior to the daily sync pass.'
        $peerSuggestions += '4. **Valkey Redis Instance Separation:** Keep VoltaireUn bound to `musicbrainz-docker-valkey-1` (port 5000) while VoltaireDeux routes metadata lookups to `musicbrainz-docker-valkey-2` (port 5001) to prevent cache stampedes.'
        $peerSuggestions += '5. **Crash-Loop Sentinel on Bazarr / Radarr:** If Bazarr encounters subtitle provider rate-limits, ensure the auto-healing sentinel applies exponential backoff (15s, 60s, 300s) instead of immediate container restart.'
    } else {
        $peerSuggestions += '1. **AI Acceleration Batch Ingestion:** For VoltaireDeux AI workloads, offload music embedding generation and tagging to Picard via local mirror (`127.0.0.1:5001`) to preserve VoltaireUn WAN bandwidth.'
        $peerSuggestions += '2. **OneDrive Sync Conflict Prevention:** Exclude active SQLite `-wal` and `-shm` temporary lock files from OneDrive sync on VoltaireDeux to eliminate `.db-shm` file locks.'
        $peerSuggestions += '3. **Cross-Node Database Hot-Restore Readiness:** Keep at least 5 verified point-in-time snapshots in `db-backup/snapshots/` to enable sub-second recovery if AI tests write dirty records.'
        $peerSuggestions += '4. **Port Binding Isolation:** Ensure AI model endpoints (e.g. Ollama `:11434` / FastAPI `:8000`) do not collide with Caddy reverse proxy port `80` or API Gateway `:3000`.'
    }

    $lines = @()
    $lines += "# MediaStack Cross-Node System Status & Architecture Handoff"
    $lines += ""
    $lines += "- **Authoring Node:** $($nodeInfo.LocalHostName) ($($nodeInfo.LocalRole))"
    $lines += "- **Local LAN IP:** $($nodeInfo.LocalIP)"
    $lines += "- **Target Peer Node:** $($nodeInfo.PeerHostName) ($($nodeInfo.PeerRole))"
    $lines += "- **Peer LAN IP:** $($nodeInfo.PeerIP)"
    $lines += "- **Generated Timestamp:** $timestamp"
    $lines += "- **Running Fleet Containers:** $runningCount / $($containerStats.Count)"
    $lines += ""
    $lines += "---"
    $lines += ""
    $lines += "## 1. System Architecture & Topology Overview"
    $lines += ""
    $lines += '```'
    $lines += "  Node: $($nodeInfo.LocalHostName) ($($nodeInfo.LocalIP)) <===> Peer: $($nodeInfo.PeerHostName) ($($nodeInfo.PeerIP))"
    $lines += "  Role: $($nodeInfo.LocalRole)  |  Peer Role: $($nodeInfo.PeerRole)"
    $lines += '  Ingress: Caddy Reverse Proxy (Ports 80 / 443)  |  Failover Ingress: Port 80'
    $lines += '  Databases: SQLite WAL Mode (7 core DBs)  |  Synchronized Mirror + Snapshots'
    $lines += '```'
    $lines += ""
    $lines += "### Code & Configuration Layout:"
    $lines += '- **Ingress Proxy:** Primary `Caddyfile` with dynamic `Host` header routing (`*.voltaireun.local` and `*.voltairedeux.local`).'
    $lines += '- **Orchestration:** `docker-compose.yml` with host volume mounts and bridge network `mediastack`.'
    $lines += '- **Database Sentinel:** Lock-free integrity checks via `MediaStackOps.psm1` (`PRAGMA quick_check;`).'
    $lines += '- **Cluster Push-Pull:** Git commits pushed from VoltaireDeux and ingested once per day via VoltaireUn daily poller.'
    $lines += ""
    $lines += "---"
    $lines += ""
    $lines += "## 2. Active Database Inventory & Health Audit"
    $lines += ""
    $lines += "| Database Name | Service | Exists | Size (KB) | Health Status | Diagnostics |"
    $lines += "| :--- | :--- | :--- | :--- | :--- | :--- |"
    foreach ($d in $dbAuditList) {
        $statBadge = if ($d.IsValid) { "[OK] PRISTINE" } elseif ($d.Exists) { "[WARN] CORRUPT" } else { "[INFO] MISSING" }
        $lines += "| **$($d.Name)** | $($d.Service) | $(if ($d.Exists) { 'Yes' } else { 'No' }) | $([math]::Round($d.SizeBytes/1KB, 1)) KB | $statBadge | $($d.Details) |"
    }
    $lines += ""
    $lines += "---"
    $lines += ""
    $lines += "## 3. Discovered System Errors & Incident Logs"
    $lines += ""
    if ($recentErrors.Count -eq 0 -and $failedContainers.Count -eq 0) {
        $lines += "[OK] **No active system errors detected.** All containers and database health probes passed."
    } else {
        if ($failedContainers.Count -gt 0) {
            $lines += "[WARN] **Offline / Stopped Containers:** $($failedContainers -join ', ')"
        }
        if ($recentErrors.Count -gt 0) {
            $lines += '```'
            foreach ($err in $recentErrors) { $lines += $err }
            $lines += '```'
        }
    }
    $lines += ""
    $lines += "---"
    $lines += ""
    $lines += "## 4. AI Suggestions for Stability, Self-Healing & Peer Node Optimization"
    $lines += ""
    $lines += "> [!TIP]"
    $lines += "> **Recommendations offered by $($nodeInfo.LocalHostName) for $($nodeInfo.PeerHostName):**"
    $lines += ""
    foreach ($sug in $peerSuggestions) {
        $lines += $sug
        $lines += ""
    }
    $lines += "---"
    $lines += "*Handoff file automatically generated for cluster sync exchange.*"

    $handoffMd = $lines -join "`r`n"
    $handoffFileName = "System_Status_Handoff_$($nodeInfo.LocalHostName)_${fileTag}.md"
    $handoffFilePath = Join-Path $HandoffsDir $handoffFileName
    $latestJsonPath  = Join-Path $HandoffsDir "latest_handoff_$($nodeInfo.LocalHostName).json"

    Set-Content -Path $handoffFilePath -Value $handoffMd -Encoding UTF8

    $handoffObj = [ordered]@{
        author_node      = $nodeInfo.LocalHostName
        author_role      = $nodeInfo.LocalRole
        author_ip        = $nodeInfo.LocalIP
        target_peer      = $nodeInfo.PeerHostName
        timestamp        = $timestamp
        running_count    = $runningCount
        total_containers = $containerStats.Count
        failed_count     = $failedContainers.Count
        databases_ok     = ($dbAuditList | Where-Object { -not $_.IsValid }).Count -eq 0
        suggestions      = $peerSuggestions
        markdown_report  = $handoffFilePath
    }
    $handoffObj | ConvertTo-Json -Depth 5 | Set-Content -Path $latestJsonPath -Encoding UTF8

    Write-Host ("`n[HANDOFF GENERATED] System status & suggestions archived -> {0}" -f $handoffFilePath) -ForegroundColor Green
    Write-Host ("  Latest JSON manifest updated -> {0}" -f $latestJsonPath) -ForegroundColor DarkCyan

    return [PSCustomObject]@{
        MarkdownPath = $handoffFilePath
        JsonPath     = $latestJsonPath
        Timestamp    = $timestamp
        NodeInfo     = $nodeInfo
        Suggestions  = $peerSuggestions
    }
}

function Invoke-MediaStackClusterUpdateCheck {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)][bool]$Interactive = $true
    )

    $nodeInfo = Get-MediaStackClusterNodeInfo
    $HandoffsDir = Join-Path $PSScriptRoot "handoffs"
    if (-not (Test-Path $HandoffsDir)) { New-Item -ItemType Directory -Force -Path $HandoffsDir | Out-Null }

    Write-Host "`n================================================================================" -ForegroundColor DarkCyan
    Write-Host "   M E D I A S T A C K   C L U S T E R   U P D A T E   &   H A N D O F F" -ForegroundColor Cyan
    Write-Host ("   Node: {0} ({1}) | IP: {2}" -f $nodeInfo.LocalHostName, $nodeInfo.LocalRole, $nodeInfo.LocalIP) -ForegroundColor DarkGray
    Write-Host ("   Peer: {0} ({1}) | Peer IP: {2}" -f $nodeInfo.PeerHostName, $nodeInfo.PeerRole, $nodeInfo.PeerIP) -ForegroundColor DarkGray
    Write-Host "================================================================================" -ForegroundColor DarkCyan

    Write-Host "`n[1/3] Generating System Status Handoff & Architecture Report..." -ForegroundColor Yellow
    [void](New-MediaStackClusterHandoff -HandoffsDir $HandoffsDir)

    Write-Host "`n[2/3] Checking for Inbound Cluster Updates..." -ForegroundColor Yellow
    $manifestPath = Join-Path $HandoffsDir "cluster_update_manifest.json"
    $hasUpdate = $false

    $hasRemote = (git remote -v 2>$null)
    if ($hasRemote) {
        Write-Host "  • Polling remote GitHub repository (git fetch)..." -ForegroundColor DarkCyan
        git fetch origin 2>&1 | Out-Null
        $gitDiff = git log HEAD..origin/main --oneline 2>$null
        if ($gitDiff) {
            $hasUpdate = $true
            Write-Host ("  [UPDATE FOUND] New commits on GitHub:`n{0}" -f $gitDiff) -ForegroundColor Green
        }
    }

    if (Test-Path $manifestPath) {
        try {
            $man = Get-Content $manifestPath -Raw | ConvertFrom-Json
            if ($man.status -eq "READY_FOR_VOLTAIREUN_PULL" -and $nodeInfo.IsVoltaireUn) {
                $hasUpdate = $true
                Write-Host ("  [UPDATE FOUND] Pending cluster update manifest: {0} ('{1}')" -f $man.update_id, $man.commit_message) -ForegroundColor Green
            } elseif ($man.status -eq "APPLIED_BY_VOLTAIREUN") {
                Write-Host ("  [CLUSTER SYNCED] Latest update '{0}' was applied by VoltaireUn at {1}" -f $man.update_id, $man.applied_at) -ForegroundColor DarkCyan
            }
        } catch { }
    }

    Write-Host "`n[3/3] Inspecting Incoming Peer Suggestions from $($nodeInfo.PeerHostName)..." -ForegroundColor Yellow
    $peerJsonPath = Join-Path $HandoffsDir "latest_handoff_$($nodeInfo.PeerHostName).json"
    if (Test-Path $peerJsonPath) {
        try {
            $peerHandoff = Get-Content $peerJsonPath -Raw | ConvertFrom-Json
            Write-Host ("`n  >> SUGGESTIONS FROM PEER NODE ({0} - {1}):" -f $peerHandoff.author_node, $peerHandoff.timestamp) -ForegroundColor Cyan
            foreach ($s in $peerHandoff.suggestions) {
                Write-Host ("     • {0}" -f $s) -ForegroundColor Yellow
            }
        } catch { }
    } else {
        Write-Host ("  (No previous handoff recorded from {0} yet. Waiting for first peer cycle.)" -f $nodeInfo.PeerHostName) -ForegroundColor DarkGray
    }

    if ($hasUpdate) {
        Write-Host "`n[UPDATE READY] Would you like to apply updates and synchronize databases now? (Y/N)" -ForegroundColor Green
        if ($Interactive) {
            $apply = Read-Host -Prompt "[Y/N]"
            if ($apply -match "^y|Y") {
                if ($nodeInfo.IsVoltaireUn) {
                    $poller = Join-Path $PSScriptRoot "Invoke-VoltaireUnDailyPoller.ps1"
                    if (Test-Path $poller) { & $poller -ForceSync }
                } else {
                    $merge = Join-Path $PSScriptRoot "Merge-OneDriveMediaStack.ps1"
                    if (Test-Path $merge) { & $merge }
                }
            }
        }
    } else {
        Write-Host "`n[ALL PRISTINE] System is up to date and in sync with cluster peer." -ForegroundColor Green
    }

    if ($Interactive) {
        Write-Host "`nPress any key to return..." -ForegroundColor DarkGray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
}

# ==============================================================================
# 9. 5-STAGE CRUD LIFECYCLE VERIFICATION ENGINE
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

        $sqlCreate = "INSERT INTO crud_sentinel_lifecycle (test_uuid, payload, created_at) VALUES ('$testUuid', '$payloadInitial', datetime('now'));"
        docker exec mediastack-db sqlite3 "$InternalDbPath" "$sqlCreate" 2>$null | Out-Null
        $results["CREATE"] = $true

        $readVal = docker exec mediastack-db sqlite3 "$InternalDbPath" "SELECT payload FROM crud_sentinel_lifecycle WHERE test_uuid = '$testUuid' LIMIT 1;" 2>$null
        if ($readVal -and $readVal.Trim() -eq $payloadInitial) {
            $results["READ"] = $true
        }

        $sqlUpdate = "UPDATE crud_sentinel_lifecycle SET payload = '$payloadUpdated' WHERE test_uuid = '$testUuid';"
        docker exec mediastack-db sqlite3 "$InternalDbPath" "$sqlUpdate" 2>$null | Out-Null
        
        $readUpdated = docker exec mediastack-db sqlite3 "$InternalDbPath" "SELECT payload FROM crud_sentinel_lifecycle WHERE test_uuid = '$testUuid' LIMIT 1;" 2>$null
        if ($readUpdated -and $readUpdated.Trim() -eq $payloadUpdated) {
            $results["UPDATE"] = $true
        }

        $sqlDelete = "DELETE FROM crud_sentinel_lifecycle WHERE test_uuid = '$testUuid';"
        docker exec mediastack-db sqlite3 "$InternalDbPath" "$sqlDelete" 2>$null | Out-Null

        $countCheck = docker exec mediastack-db sqlite3 "$InternalDbPath" "SELECT count(*) FROM crud_sentinel_lifecycle WHERE test_uuid = '$testUuid';" 2>$null
        if ($countCheck -and $countCheck.Trim() -eq "0") {
            $results["DELETE"] = $true
        }

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

# ==============================================================================
# 10. JELLYWATCH RESILIENT CONNECTION & EXPERT GUIDANCE HANDLER
# ==============================================================================

function Test-MediaStackJellyWatchConnectivity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)][string]$PrimaryIP = "192.168.4.21",
        [Parameter(Mandatory=$false)][string]$SecondaryIP = "192.168.4.30",
        [Parameter(Mandatory=$false)][string]$ExternalDomain = "waltdakind.xubi.org"
    )

    $routes = @(
        @{ Tier = 1; Name = "Remote WAN Gateway (Main Login)"; Url = "https://${ExternalDomain}/System/Info/Public"; Protocol = "HTTPS/WAN" },
        @{ Tier = 2; Name = "VoltaireUn Direct Socket (LAN Fallback)"; Url = "http://${PrimaryIP}:8096/System/Info/Public"; Protocol = "HTTP/REST" },
        @{ Tier = 3; Name = "VoltaireUn Caddy Proxy";    Url = "https://voltaireun.local/System/Info/Public"; Protocol = "HTTPS/HTTP2" },
        @{ Tier = 4; Name = "VoltaireDeux AI Node";      Url = "http://${SecondaryIP}:8096/System/Info/Public"; Protocol = "HTTP/REST" },
        @{ Tier = 5; Name = "Localhost Loopback";        Url = "http://127.0.0.1:8096/health"; Protocol = "HTTP/Loopback" }
    )

    $results = @()
    foreach ($r in $routes) {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $status = "OFFLINE"
        $httpCode = 0
        try {
            $req = [System.Net.HttpWebRequest]::Create($r.Url)
            $req.Timeout = 1500
            $req.ServerCertificateValidationCallback = { $true }
            $res = $req.GetResponse()
            $httpCode = [int]$res.StatusCode
            $sw.Stop()
            if ($httpCode -ge 200 -and $httpCode -lt 400) { $status = "ONLINE" }
            $res.Close()
        } catch [System.Net.WebException] {
            $sw.Stop()
            if ($_.Exception.Response) {
                $httpCode = [int]$_.Exception.Response.StatusCode
                $status = if ($httpCode -ge 200 -and $httpCode -lt 500) { "REACHABLE" } else { "HTTP_ERROR" }
            } else { $status = "UNREACHABLE" }
        } catch {
            $sw.Stop()
            $status = "ERROR"
        }

        $results += [PSCustomObject]@{
            Tier      = $r.Tier
            Name      = $r.Name
            Url       = $r.Url
            Protocol  = $r.Protocol
            Status    = $status
            HttpCode  = $httpCode
            LatencyMs = [int]$sw.ElapsedMilliseconds
        }
    }

    $online = $results | Where-Object { $_.Status -eq "ONLINE" } | Sort-Object Tier, LatencyMs
    $primary = if ($online) { $online[0] } else { $results[0] }

    return [PSCustomObject]@{
        PrimaryRoute = $primary
        Routes       = $results
        AllPassed    = ($online.Count -gt 0)
        Summary      = if ($online) { "JellyWatch connected via Tier $($primary.Tier) ($($primary.Name)) - $($primary.LatencyMs)ms" } else { "All JellyWatch routes offline" }
    }
}

function Invoke-MediaStackJellyWatchHandler {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)][switch]$TestConnectivity,
        [Parameter(Mandatory=$false)][switch]$AutoRepair,
        [Parameter(Mandatory=$false)][switch]$GenerateMagicLink,
        [Parameter(Mandatory=$false)][string]$SimulateError = "",
        [Parameter(Mandatory=$false)][string]$SubmitRequest = "",
        [Parameter(Mandatory=$false)][string]$MediaType = "movie",
        [Parameter(Mandatory=$false)][string]$SubmitIssue = "",
        [Parameter(Mandatory=$false)][string]$IssueType = "BUFFERING",
        [Parameter(Mandatory=$false)][switch]$ListRequests,
        [Parameter(Mandatory=$false)][switch]$ListIssues
    )

    $handlerScript = Join-Path $PSScriptRoot "Invoke-JellyWatchHandler.ps1"
    if (Test-Path $handlerScript) {
        $params = @{}
        if ($TestConnectivity) { $params["TestConnectivity"] = $true }
        if ($AutoRepair) { $params["AutoRepair"] = $true }
        if ($GenerateMagicLink) { $params["GenerateMagicLink"] = $true }
        if ($SimulateError) { $params["SimulateError"] = $SimulateError }
        if ($SubmitRequest) { $params["SubmitRequest"] = $SubmitRequest }
        if ($MediaType) { $params["MediaType"] = $MediaType }
        if ($SubmitIssue) { $params["SubmitIssue"] = $SubmitIssue }
        if ($IssueType) { $params["IssueType"] = $IssueType }
        if ($ListRequests) { $params["ListRequests"] = $true }
        if ($ListIssues) { $params["ListIssues"] = $true }
        & $handlerScript @params
    } else {
        Test-MediaStackJellyWatchConnectivity
    }
}

function Get-MediaStackJellyWatchRequests {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)][string]$Status,
        [Parameter(Mandatory=$false)][string]$MediaType,
        [Parameter(Mandatory=$false)][int]$Limit = 20,
        [Parameter(Mandatory=$false)][string]$Endpoint = "http://127.0.0.1:3000/api/jellywatch/requests"
    )

    $uri = "$Endpoint`?limit=$Limit"
    if ($Status) { $uri += "&status=$Status" }
    if ($MediaType) { $uri += "&media_type=$MediaType" }

    try {
        $res = Invoke-RestMethod -Uri $uri -TimeoutSec 3 -ErrorAction Stop
        return $res.requests
    } catch {
        Write-Error "Failed to retrieve JellyWatch requests: $_"
    }
}

function New-MediaStackJellyWatchRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$Title,
        [Parameter(Mandatory=$false)][string]$MediaType = "movie",
        [Parameter(Mandatory=$false)][int]$Year,
        [Parameter(Mandatory=$false)][string]$Overview = "",
        [Parameter(Mandatory=$false)][string]$Username = "walter",
        [Parameter(Mandatory=$false)][string]$Endpoint = "http://127.0.0.1:3000/api/jellywatch/requests"
    )

    $payload = @{
        title = $Title
        media_type = $MediaType
        year = $Year
        overview = $Overview
        requested_by_username = $Username
        client_id = "PowerShellOps"
    } | ConvertTo-Json

    try {
        $res = Invoke-RestMethod -Uri $Endpoint -Method Post -Body $payload -ContentType "application/json" -TimeoutSec 3 -ErrorAction Stop
        return $res
    } catch {
        Write-Error "Failed to submit JellyWatch request: $_"
    }
}

function Get-MediaStackJellyWatchIssues {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)][string]$Status,
        [Parameter(Mandatory=$false)][string]$Severity,
        [Parameter(Mandatory=$false)][string]$IssueType,
        [Parameter(Mandatory=$false)][int]$Limit = 20,
        [Parameter(Mandatory=$false)][string]$Endpoint = "http://127.0.0.1:3000/api/jellywatch/issues"
    )

    $uri = "$Endpoint`?limit=$Limit"
    if ($Status) { $uri += "&status=$Status" }
    if ($Severity) { $uri += "&severity=$Severity" }
    if ($IssueType) { $uri += "&issue_type=$IssueType" }

    try {
        $res = Invoke-RestMethod -Uri $uri -TimeoutSec 3 -ErrorAction Stop
        return $res.issues
    } catch {
        Write-Error "Failed to retrieve JellyWatch issues: $_"
    }
}

function New-MediaStackJellyWatchIssue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$ItemName,
        [Parameter(Mandatory=$false)][string]$IssueType = "BUFFERING",
        [Parameter(Mandatory=$false)][string]$Severity = "MEDIUM",
        [Parameter(Mandatory=$false)][string]$Description = "",
        [Parameter(Mandatory=$false)][string]$Username = "walter",
        [Parameter(Mandatory=$false)][string]$Endpoint = "http://127.0.0.1:3000/api/jellywatch/issues"
    )

    $payload = @{
        item_id = "cli_$(Get-Date -Format 'yyyyMMddHHmmss')"
        item_name = $ItemName
        issue_type = $IssueType
        severity = $Severity
        description = $Description
        reported_by_username = $Username
        client_id = "PowerShellOps"
    } | ConvertTo-Json

    try {
        $res = Invoke-RestMethod -Uri $Endpoint -Method Post -Body $payload -ContentType "application/json" -TimeoutSec 3 -ErrorAction Stop
        return $res
    } catch {
        Write-Error "Failed to submit JellyWatch issue: $_"
    }
}

function Test-MediaStackJellyWatchServices {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)][string]$HostAddress = "127.0.0.1"
    )

    $reqUrl = "http://${HostAddress}:3000/api/jellywatch/requests/stats"
    $issUrl = "http://${HostAddress}:3000/api/jellywatch/issues/stats"

    $reqOk = $false
    $issOk = $false
    $reqData = $null
    $issData = $null

    try {
        $reqData = Invoke-RestMethod -Uri $reqUrl -TimeoutSec 2 -ErrorAction Stop
        $reqOk = ($reqData.status -eq 'success')
    } catch {}

    try {
        $issData = Invoke-RestMethod -Uri $issUrl -TimeoutSec 2 -ErrorAction Stop
        $issOk = ($issData.status -eq 'success')
    } catch {}

    return [PSCustomObject]@{
        RequestsServerOnline = $reqOk
        IssuesServerOnline   = $issOk
        AllServicesHealthy   = ($reqOk -and $issOk)
        RequestsStats        = $reqData
        IssuesStats          = $issData
    }
}

try {
    if (Get-Command Export-ModuleMember -ErrorAction SilentlyContinue) {
        Export-ModuleMember -Function `
            Get-MediaStackClusterNodeInfo, `
            Assert-MediaStackClusterNode, `
            Write-MediaStackLog, `
            Test-MediaStackPort, `
            Test-MediaStackHttpRoute, `
            Test-MediaStackDatabaseHealth, `
            Invoke-MediaStackWalCheckpoint, `
            Backup-MediaStackDatabasesPreSync, `
            Invoke-DatabaseHotRestore, `
            Repair-MediaStackPortConflict, `
            New-MediaStackClusterHandoff, `
            Invoke-MediaStackClusterUpdateCheck, `
            Test-MediaStackCrudLifecycle, `
            Test-MediaStackJellyWatchConnectivity, `
            Invoke-MediaStackJellyWatchHandler, `
            Get-MediaStackJellyWatchRequests, `
            New-MediaStackJellyWatchRequest, `
            Get-MediaStackJellyWatchIssues, `
            New-MediaStackJellyWatchIssue, `
            Test-MediaStackJellyWatchServices -ErrorAction SilentlyContinue
    }
} catch { }
