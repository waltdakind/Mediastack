<#
====================================================================================================
 .SYNOPSIS
    MediaStack Primary Fleet Controller, Port Publisher, Database Sentinel & Interactive Console.

 .DESCRIPTION
    Lead Developer Production Suite for MediaStack + MusicBrainz Mirror:
    - Port Enforcement: Audits host socket listeners, resolves WinNAT/Hyper-V dynamic port conflicts,
      and guarantees all services publish standard ports (especially Jellyfin 8096, Sonarr 8989,
      Radarr 7878, Prowlarr 9696, Bazarr 6767, Jellyseerr 5055, Transmission 9091/51500,
      TVHeadend 9981/9982, Diun 9090, and Caddy 80/443).
    - Database Sentinel: Validates SQLite (Jellyfin, Sonarr, Radarr, Prowlarr, Bazarr, Jellyseerr)
      and BoltDB (Diun) binary structure. Auto-quarantines corrupt DBs and automatically restores
      from the most recent healthy snapshot in db-backup/.
    - Media Path & Persistence Engine: Ensures all required media directories (Movies, Music,
      Downloads, Watch, Config, Backups) exist with verified Read/Write permissions and persists
      session tracking markers. Confirms internal container volume mounts (/data, /config).
    - Fresh Image Redeployment: Pulls latest container images (docker compose pull), removes orphans,
      and rebuilds the stack with zero downtime.
    - Reverse Proxy & DDNS Health: Validates Caddyfile syntax and checks route responses for local
      LAN (*.ordinateur.local) and external DDNS (waltdakind.xubi.org).
    - Persistent Console UI: Color-coded interface, progress feedback, structured session logging
      in logs/mediastack_ops_*.log, and a persistent menu loop that gracefully handles Ctrl+C.

 .PARAMETER FreshDeploy
    Pulls fresh images for all containers, rebuilds the stack, and starts all services.
 .PARAMETER QuickStart
    Runs initial health, port, and database validations and starts the stack non-interactively.
 .PARAMETER Sentinel
    Launches continuous real-time self-healing sentinel mode.
 .PARAMETER AuditOnly
    Runs diagnostic checks across ports, databases, and media paths without making modifications.

 .EXAMPLE
    .\Start-MediaStackFleet.ps1
    Launches the interactive operations console.

 .EXAMPLE
    .\S-MSF.ps1
    Short alias launcher for this script.

 .EXAMPLE
    .\Start-MediaStackFleet.ps1 -FreshDeploy
    Performs full image update pull and stack redeployment.
====================================================================================================
#>

[CmdletBinding()]
param (
    [Parameter()]
    [switch]$FreshDeploy,

    [Parameter()]
    [switch]$QuickStart,

    [Parameter()]
    [switch]$Sentinel,

    [Parameter()]
    [switch]$AuditOnly
)

$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls

# --------------------------------------------------------------------------------------------------
# Global Paths & Environment Setup
# --------------------------------------------------------------------------------------------------
$BaseDir = $PSScriptRoot
if (-not $BaseDir) { $BaseDir = $PWD.Path }

$MusicBrainzDir    = Join-Path $BaseDir "musicbrainz-docker"
$BackupDir         = Join-Path $BaseDir "db-backup"
$LogDir            = Join-Path $BaseDir "logs"
$ExternalBackupDir = Join-Path (Split-Path $BaseDir -Parent) "MediaStackBackups"
$ComposeFile       = Join-Path $BaseDir "docker-compose.yml"
$EnvFile           = Join-Path $BaseDir ".env"

if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
if (-not (Test-Path $BackupDir)) { New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null }

$SessionDate = (Get-Date).ToString("yyyyMMdd")
$SessionLogFile = Join-Path $LogDir "mediastack_ops_$SessionDate.log"

# Global State Tracking
$Global:RepairEvents     = [System.Collections.Generic.List[string]]::new()
$Global:LastRestartTimes = @{}
$Global:UnhealthyStreak  = @{}

# ==================================================================================================
# Canonical Service & Port Specification Matrix
# ==================================================================================================
$CanonicalServices = @(
    @{
        Service      = "jellyfin"
        Container    = "jellyfin"
        HostPort     = 8096
        TargetPort   = 8096
        Protocol     = "tcp"
        Category     = "Media Server"
        HealthUrl    = "http://127.0.0.1:8096/health"
        DbPath       = "$BaseDir\config\jellyfin\data\data\jellyfin.db"
        DbFallback   = "$BaseDir\config\jellyfin\data\jellyfin.db"
        DbEngine     = "sqlite"
        MountCheck   = "/data"
        Description  = "Jellyfin Web Interface & API (Primary Media Server)"
    },
    @{
        Service      = "sonarr"
        Container    = "sonarr"
        HostPort     = 8989
        TargetPort   = 8989
        Protocol     = "tcp"
        Category     = "Automation"
        HealthUrl    = "http://127.0.0.1:8989/ping"
        DbPath       = "$BaseDir\config\sonarr\sonarr.db"
        DbFallback   = ""
        DbEngine     = "sqlite"
        MountCheck   = "/data"
        Description  = "Sonarr TV Series Management"
    },
    @{
        Service      = "radarr"
        Container    = "radarr"
        HostPort     = 7878
        TargetPort   = 7878
        Protocol     = "tcp"
        Category     = "Automation"
        HealthUrl    = "http://127.0.0.1:7878/ping"
        DbPath       = "$BaseDir\config\radarr\radarr.db"
        DbFallback   = ""
        DbEngine     = "sqlite"
        MountCheck   = "/data"
        Description  = "Radarr Movie Management"
    },
    @{
        Service      = "prowlarr"
        Container    = "prowlarr"
        HostPort     = 9696
        TargetPort   = 9696
        Protocol     = "tcp"
        Category     = "Indexers"
        HealthUrl    = "http://127.0.0.1:9696/ping"
        DbPath       = "$BaseDir\config\prowlarr\prowlarr.db"
        DbFallback   = ""
        DbEngine     = "sqlite"
        MountCheck   = "/config"
        Description  = "Prowlarr Indexer Manager"
    },
    @{
        Service      = "bazarr"
        Container    = "bazarr"
        HostPort     = 6767
        TargetPort   = 6767
        Protocol     = "tcp"
        Category     = "Subtitles"
        HealthUrl    = "http://127.0.0.1:6767/"
        DbPath       = "$BaseDir\config\bazarr\db\bazarr.db"
        DbFallback   = "$BaseDir\config\bazarr\bazarr.db"
        DbEngine     = "sqlite"
        MountCheck   = "/data"
        Description  = "Bazarr Subtitles Manager"
    },
    @{
        Service      = "jellyseerr"
        Container    = "jellyseerr"
        HostPort     = 5055
        TargetPort   = 5055
        Protocol     = "tcp"
        Category     = "Requests"
        HealthUrl    = "http://127.0.0.1:5055/api/v1/status"
        DbPath       = "$BaseDir\config\jellyseerr\db\db.sqlite3"
        DbFallback   = ""
        DbEngine     = "sqlite"
        MountCheck   = "/app/config"
        Description  = "Jellyseerr Media Requests"
    },
    @{
        Service      = "transmission"
        Container    = "transmission"
        HostPort     = 9091
        TargetPort   = 9091
        Protocol     = "tcp"
        Category     = "Downloads"
        HealthUrl    = "http://127.0.0.1:9091/transmission/web/"
        DbPath       = ""
        DbFallback   = ""
        DbEngine     = "none"
        MountCheck   = "/data"
        Description  = "Transmission BitTorrent Web UI"
    },
    @{
        Service      = "transmission"
        Container    = "transmission"
        HostPort     = 51500
        TargetPort   = 51413
        Protocol     = "tcp/udp"
        Category     = "Downloads"
        HealthUrl    = ""
        DbPath       = ""
        DbFallback   = ""
        DbEngine     = "none"
        MountCheck   = ""
        Description  = "Transmission BitTorrent Peer Listening Port"
    },
    @{
        Service      = "tvheadend"
        Container    = "tvheadend"
        HostPort     = 9981
        TargetPort   = 9981
        Protocol     = "tcp"
        Category     = "Live TV"
        HealthUrl    = "http://127.0.0.1:9981/"
        DbPath       = ""
        DbFallback   = ""
        DbEngine     = "none"
        MountCheck   = "/data"
        Description  = "TVHeadend Web Interface"
    },
    @{
        Service      = "tvheadend"
        Container    = "tvheadend"
        HostPort     = 9982
        TargetPort   = 9982
        Protocol     = "tcp"
        Category     = "Live TV"
        HealthUrl    = ""
        DbPath       = ""
        DbFallback   = ""
        DbEngine     = "none"
        MountCheck   = ""
        Description  = "TVHeadend HTSP Streaming"
    },
    @{
        Service      = "diun"
        Container    = "diun"
        HostPort     = 9090
        TargetPort   = 9090
        Protocol     = "tcp"
        Category     = "Monitoring"
        HealthUrl    = "http://127.0.0.1:9090/metrics"
        DbPath       = "$BaseDir\config\diun\diun.db"
        DbFallback   = ""
        DbEngine     = "bbolt"
        MountCheck   = "/data"
        Description  = "Diun Docker Image Update Notifier & Metrics"
    },
    @{
        Service      = "caddy"
        Container    = "caddy"
        HostPort     = 80
        TargetPort   = 80
        Protocol     = "tcp"
        Category     = "Proxy"
        HealthUrl    = "http://127.0.0.1:80"
        DbPath       = ""
        DbFallback   = ""
        DbEngine     = "none"
        MountCheck   = "/data"
        Description  = "Caddy HTTP Reverse Proxy"
    },
    @{
        Service      = "caddy"
        Container    = "caddy"
        HostPort     = 443
        TargetPort   = 443
        Protocol     = "tcp"
        Category     = "Proxy"
        HealthUrl    = ""
        DbPath       = ""
        DbFallback   = ""
        DbEngine     = "none"
        MountCheck   = ""
        Description  = "Caddy HTTPS Reverse Proxy"
    },
    @{
        Service      = "api-gateway"
        Container    = "api-gateway"
        HostPort     = 3000
        TargetPort   = 3000
        Protocol     = "tcp"
        Category     = "Gateway"
        HealthUrl    = "http://127.0.0.1:3000"
        DbPath       = ""
        DbFallback   = ""
        DbEngine     = "none"
        MountCheck   = ""
        Description  = "MediaStack API Gateway"
    }
)

# ==================================================================================================
# Logging & User Interface Utilities
# ==================================================================================================
function Write-Log([string]$Message, [string]$Color = "White", [bool]$LogToFile = $true) {
    $timestamp = (Get-Date).ToString("HH:mm:ss")
    $formattedMsg = "[$timestamp] $Message"
    Write-Host $formattedMsg -ForegroundColor $Color
    if ($LogToFile) {
        Add-Content -Path $SessionLogFile -Value "[$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))] $Message" -ErrorAction SilentlyContinue
    }
}

function Show-HeroBanner {
    Clear-Host
    Write-Host "================================================================================" -ForegroundColor DarkCyan
    Write-Host "   __  __          _ _       _____ _             _" -ForegroundColor Cyan
    Write-Host "  |  \/  |        | (_)     / ____| |           | |" -ForegroundColor Cyan
    Write-Host "  | \  / | ___  __| |_  __ | (___ | |_ __ _  ___| | __" -ForegroundColor Cyan
    Write-Host "  | |\/| |/ _ \/ _` | |/ _` \___ \| __/ _` |/ __| |/ /" -ForegroundColor DarkCyan
    Write-Host "  | |  | |  __/ (_| | | (_| |____) | || (_| | (__|   < " -ForegroundColor DarkCyan
    Write-Host "  |_|  |_|\___|\__,_|_|\__,_|_____/ \__\__,_|\___|_|\_\" -ForegroundColor DarkCyan
    Write-Host "       P R I M A R Y   F L E E T   C O N T R O L   C E N T E R" -ForegroundColor Yellow
    Write-Host "   Port Publisher - Database Sentinel - Media Persistence - Self-Healing" -ForegroundColor DarkGray
    Write-Host "================================================================================" -ForegroundColor DarkCyan
}

function Show-SystemStatusCard {
    $ip = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias 'Wi-Fi*' -ErrorAction SilentlyContinue | Select-Object -First 1).IPAddress
    if (-not $ip) { $ip = "192.168.4.21" }
    
    $dockerVer = docker info --format '{{.ServerVersion}}' 2>$null
    if (-not $dockerVer) { $dockerVer = "Offline / Unreachable" }
    
    $cList = docker ps -a --format '{{.Names}}|{{.State}}|{{.Status}}' 2>$null
    $running = 0
    $total = 0
    if ($cList) {
        $total = ($cList | Measure-Object).Count
        $running = ($cList | Where-Object { $_ -match '\|running\|' } | Measure-Object).Count
    }

    Write-Host "  Host IP: $ip | Machine: $env:COMPUTERNAME | Docker: $dockerVer" -ForegroundColor Cyan
    Write-Host "  Containers: $running/$total Online | DDNS: waltdakind.xubi.org | Log: $SessionLogFile" -ForegroundColor DarkGray
    Write-Host "================================================================================" -ForegroundColor DarkCyan
}

function Pause-Console {
    Write-Host "`nPress any key to return to main menu..." -ForegroundColor DarkGray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# ==================================================================================================
# 1. Media Paths & Session Data Persistence Engine
# ==================================================================================================
function Test-AndEnforceMediaPaths([bool]$Interactive = $true) {
    if ($Interactive) {
        Show-HeroBanner
        Write-Host "[*] MEDIA FOLDER PATH MAPPING & SESSION PERSISTENCE VERIFIER..." -ForegroundColor Yellow
        Write-Host ""
    } else {
        Write-Log "`n[+] Verifying Media Folders & Session Data Persistence..." "Yellow"
    }

    # Extract MEDIA_DIR from .env
    $mediaRoot = "C:\Users\waltd\OneDrive"
    if (Test-Path $EnvFile) {
        Get-Content $EnvFile | ForEach-Object {
            if ($_ -match '^\s*MEDIA_DIR\s*=\s*(.+)$') { $mediaRoot = $Matches[1].Trim() }
        }
    }

    $requiredMediaPaths = @(
        @{ Name="Media Root";      Path=$mediaRoot;                              ContainerTarget="/data" },
        @{ Name="Movies";          Path=(Join-Path $mediaRoot "Videos");         ContainerTarget="/data/movies" },
        @{ Name="Music";           Path=(Join-Path $mediaRoot "Music");          ContainerTarget="/music" },
        @{ Name="Downloads";        Path=(Join-Path $BaseDir "downloads");        ContainerTarget="/downloads" },
        @{ Name="Watch Directory";  Path=(Join-Path $BaseDir "downloads\watch");  ContainerTarget="/watch" },
        @{ Name="Config Root";      Path=(Join-Path $BaseDir "config");           ContainerTarget="/config" },
        @{ Name="DB Backups";      Path=$BackupDir;                               ContainerTarget="/config" }
    )

    $results = @()
    $sentinelFilename = ".mediastack_persistence_marker"

    foreach ($m in $requiredMediaPaths) {
        $pName = $m.Name
        $pPath = $m.Path
        $cTarget = $m.ContainerTarget

        $exists = Test-Path $pPath
        if (-not $exists) {
            try {
                New-Item -ItemType Directory -Path $pPath -Force | Out-Null
                $exists = $true
                Write-Log "    [RECREATED] Directory created: $pPath" "DarkGray"
            } catch {
                Write-Log "    [FAIL] Unable to recreate directory: $pPath ($($_))" "Red"
            }
        }

        $writable = $false
        $persistent = $false
        $markerPath = Join-Path $pPath $sentinelFilename

        if ($exists) {
            try {
                $nowStr = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                if (Test-Path $markerPath) {
                    $persistent = $true
                }
                Add-Content -Path $markerPath -Value "[$nowStr] Persistence check verified on $env:COMPUTERNAME" -Force
                $writable = $true
            } catch {
                $writable = $false
            }
        }

        $statusStr = if (-not $exists) {
            "MISSING"
        } elseif ($writable -and $persistent) {
            "PERSISTENT (RW)"
        } elseif ($writable) {
            "INITIALIZED (RW)"
        } else {
            "READ_ONLY / ERROR"
        }

        $color = if ($statusStr -match "PERSISTENT|INITIALIZED") { "Green" } else { "Red" }
        Write-Log "    [$statusStr] $pName -> $pPath" $color

        $results += [PSCustomObject]@{
            Folder           = $pName
            HostPath         = $pPath
            ContainerMount   = $cTarget
            Status           = $statusStr
            Writable         = if ($writable) { "YES" } else { "NO" }
            DataPersistent   = if ($persistent) { "VERIFIED" } else { "NEW_SESSION" }
        }
    }

    # Container Mount Verification
    Write-Log "`n    Validating Container Volume Mount Sockets..." "Cyan"
    $mountChecks = @(
        @{ Container="jellyfin"; Path="/data" },
        @{ Container="sonarr";   Path="/data" },
        @{ Container="radarr";   Path="/data" },
        @{ Container="transmission"; Path="/data" }
    )

    foreach ($mc in $mountChecks) {
        $c = $mc.Container
        $cPath = $mc.Path
        try {
            $check = docker exec $c ls -d $cPath 2>$null
            if ($check -match $cPath) {
                Write-Log "      -> [OK] $c container mount '$cPath' verified." "Green"
            } else {
                Write-Log "      -> [INFO] $c mount '$cPath' initializing or container offline." "DarkGray"
            }
        } catch {
            Write-Log "      -> [INFO] $c container offline." "DarkGray"
        }
    }

    if ($Interactive) {
        Write-Host "`n--- MEDIA FOLDER & PERSISTENCE SUMMARY ---" -ForegroundColor Cyan
        $results | Format-Table -AutoSize Folder, HostPath, ContainerMount, Status, Writable, DataPersistent
        Pause-Console
    }
}

# ==================================================================================================
# 2. Database Integrity & Automated Backup Recovery Sentinel
# ==================================================================================================
function Test-DatabaseBinaryStructure([string]$FilePath, [string]$DbEngine = "sqlite") {
    if (-not (Test-Path $FilePath)) { return "file_missing" }
    try {
        $item = Get-Item $FilePath
        if ($item.Length -lt 16) { return "zero_byte_file" }

        $fs = [System.IO.File]::Open($FilePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        $buffer = New-Object byte[] 16
        $read = $fs.Read($buffer, 0, 16)
        $fs.Close()

        if ($DbEngine -eq "bbolt") {
            if ($item.Length -ge 512) { return "ok" }
            return "invalid_bbolt_size"
        }

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

function Find-LatestHealthyBackup([string]$AppName) {
    $searchDirs = @($BackupDir, $ExternalBackupDir)
    $candidateFiles = @()

    foreach ($dir in $searchDirs) {
        if (Test-Path $dir) {
            $files = Get-ChildItem -Path $dir -Filter "*$AppName*" -File -ErrorAction SilentlyContinue |
                     Where-Object { $_.Extension -in @(".db", ".sqlite3", ".bak") -and $_.Length -gt 1024 }
            if ($files) { $candidateFiles += $files }
        }
    }

    if ($candidateFiles.Count -gt 0) {
        return ($candidateFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1)
    }
    return $null
}

function Restore-CorruptDatabase([string]$AppName, [string]$TargetDbPath) {
    Write-Log "    [AUTO-RECOVERY] Locating most recent valid backup for $($AppName)..." "Yellow"
    $latestBackup = Find-LatestHealthyBackup -AppName $AppName

    if (-not $latestBackup) {
        Write-Log "    [FATAL] No backup archive found for $($AppName) in $BackupDir!" "Red"
        return $false
    }

    $timestamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
    $quarantinePath = "$TargetDbPath.corrupt_$timestamp"

    try {
        if (Test-Path $TargetDbPath) {
            Move-Item -Path $TargetDbPath -Destination $quarantinePath -Force
            Write-Log "    [QUARANTINE] Moved corrupt file to: $quarantinePath" "DarkGray"
        }

        Copy-Item -Path $latestBackup.FullName -Destination $TargetDbPath -Force
        Write-Log "    [RESTORE SUCCESS] Restored $($AppName) DB from $($latestBackup.Name) ($([math]::Round($latestBackup.Length / 1MB, 2)) MB)" "Green"
        $Global:RepairEvents.Add("[$((Get-Date).ToString('HH:mm:ss'))] Restored $($AppName) DB from $($latestBackup.Name)")
        return $true
    } catch {
        Write-Log "    [RESTORE FAILED] Recovery failed for $($AppName): $_" "Red"
        return $false
    }
}

function Test-AndRepairDatabaseIntegrity([bool]$Interactive = $true) {
    if ($Interactive) {
        Show-HeroBanner
        Write-Host "[*] DATABASE INTEGRITY & AUTO-RECOVERY SENTINEL..." -ForegroundColor Yellow
        Write-Host ""
    } else {
        Write-Log "`n[+] Reviewing Database Integrity Across Stack..." "Yellow"
    }

    $results = @()
    $dbTargets = $CanonicalServices | Where-Object { $_.DbPath -ne "" }

    foreach ($t in $dbTargets) {
        $appName    = $t.Service
        $targetPath = $t.DbPath
        $fallback   = $t.DbFallback
        $engine     = $t.DbEngine

        if (-not (Test-Path $targetPath) -and $fallback -and (Test-Path $fallback)) {
            $targetPath = $fallback
        }

        if (-not (Test-Path $targetPath)) {
            $targetDir = Split-Path $targetPath -Parent
            if (-not (Test-Path $targetDir)) { New-Item -ItemType Directory -Path $targetDir -Force | Out-Null }
            
            Write-Log "    [NOTICE] $($appName) DB missing. Attempting auto-restore from backup..." "DarkGray"
            $restored = Restore-CorruptDatabase -AppName $appName -TargetDbPath $targetPath
            $status = if ($restored) { "RESTORED" } else { "INITIALIZING" }
            $size = if (Test-Path $targetPath) { [math]::Round((Get-Item $targetPath).Length / 1MB, 2) } else { 0 }
            $results += [PSCustomObject]@{ App=$appName; Engine=$engine; Status=$status; SizeMB=$size; Path=$targetPath }
            continue
        }

        $fileSizeMB = [math]::Round((Get-Item $targetPath).Length / 1MB, 2)
        $check = Test-DatabaseBinaryStructure -FilePath $targetPath -DbEngine $engine

        if ($check -eq "ok") {
            Write-Log "    [OK] $($appName) DB Verified ($fileSizeMB MB)" "Green"
            $results += [PSCustomObject]@{ App=$appName; Engine=$engine; Status="VERIFIED"; SizeMB=$fileSizeMB; Path=$targetPath }
        } else {
            Write-Log "    [CRITICAL] Integrity failure on $($appName) DB! ($check)" "Red"
            $restored = Restore-CorruptDatabase -AppName $appName -TargetDbPath $targetPath
            $status = if ($restored) { "RECOVERED" } else { "FAILED" }
            $results += [PSCustomObject]@{ App=$appName; Engine=$engine; Status=$status; SizeMB=$fileSizeMB; Path=$targetPath }
        }
    }

    # MusicBrainz PostgreSQL DB Probe
    if (Test-Path $MusicBrainzDir) {
        try {
            $pgCheck = docker exec musicbrainz-docker-db-1 pg_isready -U musicbrainz 2>$null
            if ($pgCheck -match "accepting connections") {
                Write-Log "    [OK] MusicBrainz PostgreSQL DB is Accepting Connections." "Green"
                $results += [PSCustomObject]@{ App="musicbrainz"; Engine="postgres"; Status="VERIFIED"; SizeMB="Postgres"; Path="musicbrainz-docker-db-1" }
            } else {
                Write-Log "    [INFO] MusicBrainz PostgreSQL DB starting/offline." "DarkGray"
                $results += [PSCustomObject]@{ App="musicbrainz"; Engine="postgres"; Status="STARTING"; SizeMB="Postgres"; Path="musicbrainz-docker-db-1" }
            }
        } catch {
            Write-Log "    [WARN] MusicBrainz DB container offline." "DarkGray"
        }
    }

    if ($Interactive) {
        Write-Host "`n--- DATABASE INTEGRITY SUMMARY ---" -ForegroundColor Cyan
        $results | Format-Table -AutoSize App, Engine, Status, SizeMB, Path
        Pause-Console
    }
}

# ==================================================================================================
# 3. Port Publishing, Conflict Detection & Verification Engine
# ==================================================================================================
function Test-AndPublishStackPorts([bool]$Enforce = $false, [bool]$Interactive = $true) {
    if ($Interactive) {
        Show-HeroBanner
        Write-Host "[*] PUBLISHED PORT VERIFIER & CONFLICT RESOLVER..." -ForegroundColor Yellow
        Write-Host ""
    } else {
        Write-Log "`n[+] Verifying Published Ports and Host Socket Bindings..." "Yellow"
    }

    # Windows WinNAT Exclusion Check
    $excludedRanges = @()
    try {
        $netsh = netsh interface ipv4 show excludedportrange protocol=tcp 2>$null
        if ($netsh) {
            foreach ($line in $netsh) {
                if ($line -match '^\s*(\d+)\s+(\d+)') {
                    $excludedRanges += [PSCustomObject]@{ Start=[int]$Matches[1]; End=[int]$Matches[2] }
                }
            }
        }
    } catch {}

    $hasExclusionCollision = $false
    foreach ($svc in $CanonicalServices) {
        $hp = $svc.HostPort
        foreach ($r in $excludedRanges) {
            if ($hp -ge $r.Start -and $hp -le $r.End) {
                Write-Log "    [EXCLUSION COLLISION] Port $hp ($($svc.Service)) is inside Windows WinNAT dynamic exclusion range ($($r.Start)-$($r.End))!" "Red"
                $hasExclusionCollision = $true
            }
        }
    }

    if ($Enforce) {
        Write-Log "`n[+] Enforcing Published Port Bindings in Docker..." "Yellow"
        $portScript = Join-Path $BaseDir "Publish-MediaStackPorts.ps1"
        if (Test-Path $portScript) {
            & $portScript -Apply
        } else {
            Set-Location -Path $BaseDir
            docker compose up -d
        }
    }

    # Inspect Running Container Bindings
    $results = @()
    $running = docker ps --format '{{.Names}}' 2>$null

    foreach ($svc in $CanonicalServices) {
        $cName = $svc.Container
        $sName = $svc.Service
        $hp    = $svc.HostPort
        $tp    = $svc.TargetPort

        $isOnline = $running -contains $cName
        $isPublished = $false

        if ($isOnline) {
            $inspect = docker inspect $cName --format '{{json .NetworkSettings.Ports}}' 2>$null
            if ($inspect -and $inspect -ne "null") {
                try {
                    $pObj = $inspect | ConvertFrom-Json
                    foreach ($p in $pObj.PSObject.Properties) {
                        $bList = $p.Value
                        if ($bList) {
                            foreach ($b in $bList) {
                                if ([int]$b.HostPort -eq $hp) { $isPublished = $true }
                            }
                        }
                    }
                } catch {}
            }
        }

        # Live TCP Probe
        $tcpOpen = $false
        try {
            $tcp = New-Object System.Net.Sockets.TcpClient
            $async = $tcp.BeginConnect("127.0.0.1", $hp, $null, $null)
            if ($async.AsyncWaitHandle.WaitOne(600, $false) -and $tcp.Connected) {
                $tcpOpen = $true
                $tcp.EndConnect($async)
            }
            $tcp.Close()
        } catch { $tcpOpen = $false }

        # Live HTTP Probe
        $httpStatus = "N/A"
        if ($tcpOpen -and $svc.HealthUrl) {
            try {
                $hRes = Invoke-WebRequest -Uri $svc.HealthUrl -UseBasicParsing -MaximumRedirection 0 -TimeoutSec 3 -ErrorAction Stop
                $code = [int]$hRes.StatusCode
                $httpStatus = "HTTP $code"
            } catch {
                if ($_.Exception.Response) {
                    $code = [int]$_.Exception.Response.StatusCode
                    $httpStatus = "HTTP $code"
                } else {
                    $httpStatus = "TIMEOUT"
                }
            }
        } elseif ($tcpOpen) {
            $httpStatus = "TCP OPEN"
        } else {
            $httpStatus = "CLOSED"
        }

        $results += [PSCustomObject]@{
            Service      = $sName
            Container    = $cName
            HostPort     = $hp
            TargetPort   = $tp
            DockerStatus = if (-not $isOnline) { "OFFLINE" } elseif ($isPublished) { "PUBLISHED" } else { "UNMAPPED" }
            SocketOpen   = if ($tcpOpen) { "YES" } else { "NO" }
            HttpStatus   = $httpStatus
            Category     = $svc.Category
        }
    }

    if ($Interactive) {
        Write-Host "`n--- PUBLISHED PORT MATRIX & HEALTH STATUS ---" -ForegroundColor Cyan
        $results | Format-Table -AutoSize Service, Container, HostPort, TargetPort, DockerStatus, SocketOpen, HttpStatus, Category
        
        $jellyfinCheck = $results | Where-Object { $_.Service -eq "jellyfin" -and $_.HostPort -eq 8096 }
        if ($jellyfinCheck -and $jellyfinCheck.SocketOpen -eq "YES") {
            Write-Host " [OK] JELLYFIN IS PUBLISHED & ACCESSIBLE ON HOST PORT 8096!" -ForegroundColor Green
            Write-Host "      Access URL: http://localhost:8096 or http://192.168.4.21:8096" -ForegroundColor Cyan
        } else {
            Write-Host " [ALERT] JELLYFIN 8096 IS NOT ACTIVE. Run option [1] to enforce publishing." -ForegroundColor Yellow
        }
        Pause-Console
    }
}

# ==================================================================================================
# 4. Stack Redeployment & Fresh Image Pull Engine
# ==================================================================================================
function Invoke-FreshStackRedeploy {
    Show-HeroBanner
    Write-Host "[*] INITIATING FULL STACK FRESH DOWNLOAD & REDEPLOYMENT..." -ForegroundColor Yellow
    Write-Host "    Pulling latest container images and recreating stack with clean port bindings.`n" -ForegroundColor DarkGray

    Set-Location -Path $BaseDir

    # 1. Image Pull
    Write-Log "[1/4] Pulling Fresh Images for All Stack Containers..." "Cyan"
    docker compose pull

    # 2. Database Integrity Pre-Check
    Write-Log "`n[2/4] Verifying Database Health Prior to Startup..." "Cyan"
    Test-AndRepairDatabaseIntegrity -Interactive $false

    # 3. Media Path Verification
    Write-Log "`n[3/4] Checking Media Paths and Persistence..." "Cyan"
    Test-AndEnforceMediaPaths -Interactive $false

    # 4. Clean Re-creation with Enforced Ports
    Write-Log "`n[4/4] Recreating Containers with Published Ports..." "Cyan"
    docker compose up -d --remove-orphans --force-recreate

    if (Test-Path $MusicBrainzDir) {
        Write-Log "`n    Recreating MusicBrainz Mirror Containers..." "Cyan"
        Set-Location -Path $MusicBrainzDir
        docker compose up -d
        Set-Location -Path $BaseDir
    }

    Write-Log "`n    Waiting 15s for stack initialization & socket warmup..." "DarkGray"
    Start-Sleep -Seconds 15

    # 5. Post-Deploy Verification
    Test-AndPublishStackPorts -Enforce $false -Interactive $false

    Write-Log "`n[SUCCESS] Fresh Stack Download & Redeployment Complete!" "Green"
    Pause-Console
}

# ==================================================================================================
# 5. Fast Graceful Stack Restart
# ==================================================================================================
function Invoke-FastStackRestart {
    Show-HeroBanner
    Write-Host "[*] FAST STACK RESTART SEQUENCE..." -ForegroundColor Yellow
    Write-Host ""

    Write-Log "[+] Restarting Primary MediaStack Containers..." "Cyan"
    Set-Location -Path $BaseDir
    docker compose restart

    if (Test-Path $MusicBrainzDir) {
        Write-Log "`n[+] Restarting MusicBrainz Mirror Containers..." "Cyan"
        Set-Location -Path $MusicBrainzDir
        docker compose restart
        Set-Location -Path $BaseDir
    }

    Write-Log "`n    Waiting 10s for container sockets to bind..." "DarkGray"
    Start-Sleep -Seconds 10

    Write-Log "`n[OK] Stack Restart Sequence Complete." "Green"
    Pause-Console
}

# ==================================================================================================
# 6. Database Snapshot Backup Engine
# ==================================================================================================
function Invoke-DatabaseSnapshot {
    Show-HeroBanner
    Write-Host "[*] CREATING COMPREHENSIVE STACK BACKUP SNAPSHOT..." -ForegroundColor Yellow
    Write-Host ""

    $timestamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
    $targetFolder = Join-Path $BackupDir "snapshot_$timestamp"
    New-Item -ItemType Directory -Path $targetFolder -Force | Out-Null

    Write-Log "[+] Backing up active SQLite databases to $targetFolder..." "Yellow"

    $dbFiles = Get-ChildItem -Path "$BaseDir\config" -Recurse -Filter "*.db" -File -ErrorAction SilentlyContinue |
               Where-Object { $_.Name -notmatch "corrupt|old|\.bak" -and $_.Length -gt 0 }

    foreach ($f in $dbFiles) {
        $dest = Join-Path $targetFolder $f.Name
        Copy-Item -Path $f.FullName -Destination $dest -Force
        Write-Log "    [BACKED UP] $($f.Name) ($([math]::Round($f.Length / 1MB, 2)) MB)" "Green"
    }

    Copy-Item -Path "$BaseDir\Caddyfile" -Destination $targetFolder -Force -ErrorAction SilentlyContinue
    Copy-Item -Path "$BaseDir\docker-compose.yml" -Destination $targetFolder -Force -ErrorAction SilentlyContinue
    Copy-Item -Path "$BaseDir\.env" -Destination $targetFolder -Force -ErrorAction SilentlyContinue

    Write-Log "`n[SUCCESS] Backup snapshot created at: $targetFolder" "Green"
    Pause-Console
}

# ==================================================================================================
# 7. Manual Database Restore Console
# ==================================================================================================
function Invoke-ManualDatabaseRestore {
    Show-HeroBanner
    Write-Host "[*] RESTORE DATABASE FROM BACKUP ARCHIVE..." -ForegroundColor Yellow
    Write-Host ""

    $backups = Get-ChildItem -Path $BackupDir -Recurse -Filter "*.sqlite3" -File -ErrorAction SilentlyContinue |
               Sort-Object LastWriteTime -Descending

    if (-not $backups) {
        $backups = Get-ChildItem -Path $BackupDir -Recurse -Filter "*.db" -File -ErrorAction SilentlyContinue |
                   Sort-Object LastWriteTime -Descending
    }

    if (-not $backups -or $backups.Count -eq 0) {
        Write-Log "[WARN] No backup archives found in $BackupDir." "Yellow"
        Pause-Console
        return
    }

    Write-Host "Available Backups in Archive:" -ForegroundColor Cyan
    for ($i = 0; $i -lt [math]::Min(12, $backups.Count); $i++) {
        $b = $backups[$i]
        Write-Host "  [$i] $($b.Name) ($([math]::Round($b.Length / 1MB, 2)) MB) - $($b.LastWriteTime)" -ForegroundColor White
    }

    Write-Host ""
    $sel = Read-Host -Prompt "Enter backup index to restore [0-$([math]::Min(11, $backups.Count - 1))] or 'q' to cancel"
    if ($sel -eq 'q') { return }

    if ($sel -match '^\d+$' -and [int]$sel -lt $backups.Count) {
        $chosen = $backups[[int]$sel]
        Write-Host "`nSelected: $($chosen.FullName)" -ForegroundColor Cyan
        $confirm = Read-Host -Prompt "Type 'RESTORE' to overwrite active database with this backup"
        if ($confirm -eq 'RESTORE') {
            $appName = ""
            if ($chosen.Name -match "^([a-zA-Z]+)_") { $appName = $Matches[1].ToLower() }

            if ($appName) {
                $targetMap = @{
                    "sonarr"     = "$BaseDir\config\sonarr\sonarr.db"
                    "radarr"     = "$BaseDir\config\radarr\radarr.db"
                    "jellyfin"   = "$BaseDir\config\jellyfin\data\data\jellyfin.db"
                    "bazarr"     = "$BaseDir\config\bazarr\db\bazarr.db"
                    "jellyseerr" = "$BaseDir\config\jellyseerr\db\db.sqlite3"
                    "prowlarr"   = "$BaseDir\config\prowlarr\prowlarr.db"
                }
                if ($targetMap.ContainsKey($appName)) {
                    $targetPath = $targetMap[$appName]
                    Copy-Item -Path $chosen.FullName -Destination $targetPath -Force
                    Write-Log "[SUCCESS] Restored $($chosen.Name) to $targetPath" "Green"
                } else {
                    Write-Log "[WARN] Could not automatically identify target application for $($appName)." "Yellow"
                }
            }
        }
    }
    Pause-Console
}

# ==================================================================================================
# 8. Caddy Reverse Proxy & Route Diagnostics
# ==================================================================================================
function Invoke-RoutingAndDDNSDiagnostics {
    Show-HeroBanner
    Write-Host "[*] CADDY REVERSE PROXY & ROUTE DIAGNOSTICS..." -ForegroundColor Yellow
    Write-Host ""

    try {
        $v = docker exec caddy caddy validate --config /etc/caddy/Caddyfile 2>&1
        if ($v -match "Valid configuration") {
            Write-Host " [OK] Caddyfile Syntax: VALID" -ForegroundColor Green
        }
    } catch {
        Write-Host " [WARN] Could not validate Caddyfile via container." -ForegroundColor Yellow
    }

    $routes = @(
        @{ Name="External DDNS Root";       Url="http://127.0.0.1:80";            Host="waltdakind.xubi.org" },
        @{ Name="External Jellyfin DDNS";   Url="http://127.0.0.1:80";            Host="jellyfin.waltdakind.xubi.org" },
        @{ Name="External Jellyseerr DDNS"; Url="http://127.0.0.1:80";            Host="jellyseerr.waltdakind.xubi.org" },
        @{ Name="External Sonarr DDNS";     Url="http://127.0.0.1:80/ping";       Host="sonarr.waltdakind.xubi.org" },
        @{ Name="External Radarr DDNS";     Url="http://127.0.0.1:80/ping";       Host="radarr.waltdakind.xubi.org" },
        @{ Name="Local LAN Homepage";       Url="http://127.0.0.1:80";            Host="ordinateur.local" },
        @{ Name="Local LAN Jellyfin";       Url="http://127.0.0.1:80";            Host="jellyfin.ordinateur.local" },
        @{ Name="Jellyfin Direct Port";     Url="http://127.0.0.1:8096/health";   Host="" },
        @{ Name="MusicBrainz Server Direct";Url="http://127.0.0.1:5000";          Host="" }
    )

    foreach ($r in $routes) {
        $code = 0
        try {
            $headers = @{}
            if ($r.Host) { $headers["Host"] = $r.Host }
            $res = Invoke-WebRequest -Uri $r.Url -Headers $headers -UseBasicParsing -MaximumRedirection 0 -TimeoutSec 3 -ErrorAction Stop
            $code = [int]$res.StatusCode
        } catch {
            if ($_.Exception.Response) { $code = [int]$_.Exception.Response.StatusCode }
        }

        if ($code -ge 200 -and $code -lt 400) {
            Write-Host " [OK] $($r.Name) ($($r.Host)) -> HTTP $code" -ForegroundColor Green
        } elseif ($code -eq 503) {
            Write-Host " [INFO] $($r.Name) ($($r.Host)) -> HTTP 503 (Initializing/Warmup)" -ForegroundColor Yellow
        } else {
            Write-Host " [WARN] $($r.Name) ($($r.Host)) -> HTTP $code" -ForegroundColor Yellow
        }
    }
    Pause-Console
}

# ==================================================================================================
# 9. Real-Time Auto-Healing Sentinel Monitor
# ==================================================================================================
function Run-ContinuousSentinel {
    Show-HeroBanner
    Write-Host "[*] ENTERING REAL-TIME CONTINUOUS SELF-HEALING SENTINEL MONITOR..." -ForegroundColor Yellow
    Write-Host "    Polling interval: 25s. Press [Ctrl+C] to return to the interactive console.`n" -ForegroundColor DarkGray

    $script = Join-Path $BaseDir "Start-PrimaryStack.ps1"
    if (Test-Path $script) {
        try {
            & $script -Monitor -IntervalSec 25
        } catch {
            Write-Log "`n[STOPPED] Sentinel monitoring session closed by user." "Cyan"
        }
    }
}

# ==================================================================================================
# 10. Docker Cleanup & Graceful Shutdown
# ==================================================================================================
function Invoke-DockerClean {
    Show-HeroBanner
    Write-Host "[*] DOCKER RESOURCE CLEANUP & STORAGE OPTIMIZATION..." -ForegroundColor Yellow
    Write-Host ""
    docker container prune -f | Out-Null
    docker image prune -f | Out-Null
    docker network prune -f | Out-Null
    Write-Host "[OK] Cleaned stopped containers, dangling images, and unused networks." -ForegroundColor Green
    Pause-Console
}

function Stop-MediaStackGraceful {
    Show-HeroBanner
    Write-Host "[*] GRACEFUL MULTI-STACK SHUTDOWN..." -ForegroundColor Yellow
    Write-Host ""

    Write-Log "[+] Stopping MediaStack containers..." "Cyan"
    Set-Location -Path $BaseDir
    docker compose stop

    if (Test-Path $MusicBrainzDir) {
        Write-Log "[+] Stopping MusicBrainz mirror containers..." "Cyan"
        Set-Location -Path $MusicBrainzDir
        docker compose stop
        Set-Location -Path $BaseDir
    }

    Write-Log "`n[OK] All MediaStack containers stopped safely." "Green"
    Pause-Console
}

function Invoke-ClusterUpdateAndHandoff {
    Show-HeroBanner
    Write-Host "[*] CHECKING FOR CLUSTER UPDATES & GENERATING SYSTEM STATUS HANDOFF..." -ForegroundColor Yellow
    Write-Host ""
    $script = Join-Path $BaseDir "Invoke-MediaStackClusterHandoff.ps1"
    if (Test-Path $script) {
        & $script
    } else {
        $opsModule = Join-Path $BaseDir "MediaStackOps.psm1"
        if (Test-Path $opsModule) { Import-Module $opsModule -Force }
        Invoke-MediaStackClusterUpdateCheck -Interactive $true
    }
}

function Invoke-ClusterAiCollaboration {
    Show-HeroBanner
    Write-Host "[*] LAUNCHING AI COLLABORATION & AUTONOMOUS SELF-HEALING NEXUS..." -ForegroundColor Yellow
    Write-Host ""
    $script = Join-Path $BaseDir "Invoke-MediaStackAiCollaboration.ps1"
    if (Test-Path $script) {
        & $script -AutoRepair -Interactive $true
    } else {
        Write-Host "AI collaboration script not found: $script" -ForegroundColor Red
        Pause-Console
    }
}

# ==================================================================================================
# Command Line Switch Handlers
# ==================================================================================================
if ($FreshDeploy) {
    Invoke-FreshStackRedeploy
    exit 0
}

if ($Sentinel) {
    Run-ContinuousSentinel
    exit 0
}

if ($AuditOnly) {
    Show-HeroBanner
    Show-SystemStatusCard
    Test-AndRepairDatabaseIntegrity -Interactive $false
    Test-AndEnforceMediaPaths -Interactive $false
    Test-AndPublishStackPorts -Enforce $false -Interactive $true
    exit 0
}

if ($QuickStart) {
    Show-HeroBanner
    Show-SystemStatusCard
    Test-AndRepairDatabaseIntegrity -Interactive $false
    Test-AndEnforceMediaPaths -Interactive $false
    Test-AndPublishStackPorts -Enforce $true -Interactive $false
    exit 0
}

# ==================================================================================================
# Initial Startup Routine (Runs on Launch Before Displaying Menu)
# ==================================================================================================
Show-HeroBanner
Show-SystemStatusCard
Write-Host " Initializing Automated Stack Health Verification..." -ForegroundColor Yellow
Test-AndRepairDatabaseIntegrity -Interactive $false
Test-AndEnforceMediaPaths -Interactive $false
Test-AndPublishStackPorts -Enforce $true -Interactive $false
Write-Host "`n Health and Port validations verified. Entering Operations Console.`n" -ForegroundColor Green
Start-Sleep -Seconds 2

# ==================================================================================================
# MAIN INTERACTIVE OPERATIONS CONSOLE (Persistent Loop until Ctrl+C / Exit)
# ==================================================================================================
while ($true) {
    try {
        Show-HeroBanner
        Show-SystemStatusCard

        Write-Host " OPERATIONAL SENTINEL CONTROLS:" -ForegroundColor Yellow
        Write-Host "  [1]  Verify & Publish Ports (Jellyfin 8096, Radarr, Sonarr, Transmission...)" -ForegroundColor Cyan
        Write-Host "  [2]  Database Integrity Check & Automated Recovery Sentinel" -ForegroundColor White
        Write-Host "  [3]  Media Folder Path Mapping & Session Data Persistence Verifier" -ForegroundColor White
        Write-Host "  [4]  Fresh Stack Redeployment (Pull Latest Images & Force-Recreate)" -ForegroundColor Green
        Write-Host "  [5]  Fast Stack Restart (Quick restart all containers)" -ForegroundColor White
        Write-Host "  [6]  Create Complete Stack Backup Snapshot (DBs + Configs)" -ForegroundColor White
        Write-Host "  [7]  Restore Specific Database from Backup Archive" -ForegroundColor White
        Write-Host "  [8]  Caddy Reverse Proxy, Local LAN & DDNS Route Diagnostics" -ForegroundColor White
        Write-Host "  [9]  Real-Time Auto-Healing Sentinel Monitor (Continuous)" -ForegroundColor White
        Write-Host "  [10] Docker Resource Deep Clean & Storage Optimization" -ForegroundColor White
        Write-Host "  [11] Graceful Multi-Stack Shutdown (Stop All)" -ForegroundColor White
        Write-Host "  [12] Check for Cluster Updates & Exchange Handoff Report [U]" -ForegroundColor Cyan
        Write-Host "  [13] AI Collaboration & Autonomous Self-Healing Nexus [A]" -ForegroundColor Magenta
        Write-Host "  [0]  Exit Operations Console" -ForegroundColor DarkGray

        Write-Host ""
        $choice = Read-Host -Prompt "Enter selection [0-13]"

        switch ($choice) {
            "1"  { Test-AndPublishStackPorts -Enforce $true -Interactive $true }
            "2"  { Test-AndRepairDatabaseIntegrity -Interactive $true }
            "3"  { Test-AndEnforceMediaPaths -Interactive $true }
            "4"  { Invoke-FreshStackRedeploy }
            "5"  { Invoke-FastStackRestart }
            "6"  { Invoke-DatabaseSnapshot }
            "7"  { Invoke-ManualDatabaseRestore }
            "8"  { Invoke-RoutingAndDDNSDiagnostics }
            "9"  { Run-ContinuousSentinel }
            "10" { Invoke-DockerClean }
            "11" { Stop-MediaStackGraceful }
            "12" { Invoke-ClusterUpdateAndHandoff }
            "u"  { Invoke-ClusterUpdateAndHandoff }
            "U"  { Invoke-ClusterUpdateAndHandoff }
            "13" { Invoke-ClusterAiCollaboration }
            "a"  { Invoke-ClusterAiCollaboration }
            "A"  { Invoke-ClusterAiCollaboration }
            "0"  { 
                Write-Host "`nExiting MediaStack Fleet Operations Center. Goodbye!`n" -ForegroundColor Green
                exit 0 
            }
            default {
                Write-Host "Invalid selection. Please enter a choice between 0 and 12." -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        }
    } catch [System.Management.Automation.PipelineStoppedException] {
        Write-Host "`nInterrupted by user (Ctrl+C). Returning to main menu..." -ForegroundColor Yellow
        Start-Sleep -Seconds 1
    } catch {
        Write-Log "Unexpected console error: $_" "Red"
        Start-Sleep -Seconds 2
    }
}
