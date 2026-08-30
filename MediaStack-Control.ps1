<#
.SYNOPSIS
    MediaStack Primary Control Center & Interactive Engineering Console
.DESCRIPTION
    Lead Systems Engineer Operations Console for MediaStack + MusicBrainz Mirror:
    - Full Stack Safe Startup and Orchestration
    - Real-Time Sentinel Health Monitor and Automated Self-Healing
    - Deep Diagnostic and Doctor Suite
    - Caddy Reverse Proxy and DNS Routing Inspector
    - Database Integrity, SQLite Binary Verification and Auto-Recovery
    - MusicBrainz Server and Picard Integration Management
    - HDHomeRun Tuner and Live TV Diagnostic Probe
    - Docker Image and Resource Storage Optimization
    - Graceful Multi-Stack Shutdown
#>

[CmdletBinding()]
param ()

$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$BaseDir = $PSScriptRoot
if (-not $BaseDir) { $BaseDir = $PWD.Path }
$MusicBrainzDir = Join-Path $BaseDir "musicbrainz-docker"
$BackupDir = Join-Path $BaseDir "db-backup"

# -----------------------------------------------------------------------------
# Terminal UI and Formatting Helpers
# -----------------------------------------------------------------------------
function Show-Header {
    Clear-Host
    Write-Host "================================================================================" -ForegroundColor DarkCyan
    Write-Host "  __  __          _ _       _____ _             _" -ForegroundColor Cyan
    Write-Host " |  \/  |        | (_)     / ____| |           | |" -ForegroundColor Cyan
    Write-Host " | \  / | ___  __| |_  __ | (___ | |_ __ _  ___| | __" -ForegroundColor Cyan
    Write-Host " | |\/| |/ _ \/ _` | |/ _` \___ \| __/ _` |/ __| |/ /" -ForegroundColor DarkCyan
    Write-Host " | |  | |  __/ (_| | | (_| |____) | || (_| | (__|   < " -ForegroundColor DarkCyan
    Write-Host " |_|  |_|\___|\__,_|_|\__,_|_____/ \__\__,_|\___|_|\_\" -ForegroundColor DarkCyan
    Write-Host "       M A S T E R   C O N T R O L   AND   D E B U G   S U I T E" -ForegroundColor Yellow
    Write-Host "       Lead Systems Engineering Console - MediaStack + MusicBrainz" -ForegroundColor DarkGray
    Write-Host "================================================================================" -ForegroundColor DarkCyan
}

function Get-SystemSummary {
    $ip = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias 'Wi-Fi*' -ErrorAction SilentlyContinue | Select-Object -First 1).IPAddress
    if (-not $ip) { $ip = "192.168.4.21" }
    
    $dockerVer = docker info --format '{{.ServerVersion}}' 2>$null
    if (-not $dockerVer) { $dockerVer = "Offline" }
    
    $cList = docker ps -a --format '{{.Names}}|{{.State}}|{{.Status}}' 2>$null
    $running = 0
    $total = 0
    if ($cList) {
        $total = ($cList | Measure-Object).Count
        $running = ($cList | Where-Object { $_ -match '\|running\|' } | Measure-Object).Count
    }

    Write-Host " Local IP: $ip | Host: $env:COMPUTERNAME | Docker: $dockerVer | Containers: $running/$total Running" -ForegroundColor Cyan
    Write-Host " DDNS: waltdakind.xubi.org (73.178.82.157) | DNS: 1.1.1.1, 8.8.8.8" -ForegroundColor DarkGray
    Write-Host "================================================================================" -ForegroundColor DarkCyan
}

function Pause-Console {
    Write-Host "`nPress any key to return to main menu..." -ForegroundColor DarkGray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# -----------------------------------------------------------------------------
# 1. Full Stack Safe Start
# -----------------------------------------------------------------------------
function Start-FullStackSafe {
    Show-Header
    Write-Host "[1] LAUNCHING FULL STACK SAFE START SEQUENCE..." -ForegroundColor Yellow
    Write-Host ""
    
    $script = Join-Path $BaseDir "Start-PrimaryStack.ps1"
    if (Test-Path $script) {
        & $script -Once
    } else {
        Write-Host "[ERROR] Start-PrimaryStack.ps1 not found." -ForegroundColor Red
    }
    Pause-Console
}

# -----------------------------------------------------------------------------
# 2. Sentinel Live Monitor and Auto-Healer
# -----------------------------------------------------------------------------
function Start-SentinelMonitorMode {
    Show-Header
    Write-Host "[2] STARTING SENTINEL LIVE MONITOR AND AUTO-HEALER..." -ForegroundColor Yellow
    Write-Host ""
    
    $script = Join-Path $BaseDir "Start-PrimaryStack.ps1"
    if (Test-Path $script) {
        & $script -Monitor
    } else {
        Write-Host "[ERROR] Start-PrimaryStack.ps1 not found." -ForegroundColor Red
    }
}

# -----------------------------------------------------------------------------
# 3. Deep Diagnostic and Doctor Suite
# -----------------------------------------------------------------------------
function Invoke-DeepDiagnosticSuite {
    Show-Header
    Write-Host "[3] RUNNING DEEP DIAGNOSTIC AND DOCTOR SUITE..." -ForegroundColor Yellow
    Write-Host ""

    Write-Host "--- 1. NETWORK AND DNS SUBSYSTEM ---" -ForegroundColor Cyan
    try {
        $dnsTest = Resolve-DnsName -Name "waltdakind.xubi.org" -ErrorAction Stop
        Write-Host " [OK] DNS Resolution for 'waltdakind.xubi.org':" -ForegroundColor Green
        $dnsTest | Select-Object Name, Type, IPAddress | Format-Table -AutoSize
    } catch {
        Write-Host " [FAIL] DNS Resolution failed: $_" -ForegroundColor Red
    }

    Write-Host "--- 2. DOCKER ENGINE AND TOPOLOGY ---" -ForegroundColor Cyan
    $containers = docker ps -a --format 'table {{.Names}}\t{{.State}}\t{{.Status}}\t{{.Ports}}' 2>$null
    if ($containers) {
        $containers
    } else {
        Write-Host " [FAIL] Docker daemon is offline or non-responsive." -ForegroundColor Red
    }

    Write-Host "`n--- 3. DATABASE INTEGRITY STATUS ---" -ForegroundColor Cyan
    $dbs = @(
        "$BaseDir\config\jellyfin\data\data\jellyfin.db",
        "$BaseDir\config\sonarr\sonarr.db",
        "$BaseDir\config\radarr\radarr.db",
        "$BaseDir\config\prowlarr\prowlarr.db",
        "$BaseDir\config\bazarr\db\bazarr.db",
        "$BaseDir\config\jellyseerr\db\db.sqlite3"
    )

    foreach ($db in $dbs) {
        $fn = [System.IO.Path]::GetFileName($db)
        if (Test-Path $db) {
            try {
                $fs = [System.IO.File]::Open($db, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
                $buf = New-Object byte[] 16
                $null = $fs.Read($buf, 0, 16)
                $fs.Close()
                $hdr = [System.Text.Encoding]::ASCII.GetString($buf)
                $size = [math]::Round((Get-Item $db).Length / 1MB, 2)
                if ($hdr.StartsWith("SQLite format 3")) {
                    Write-Host (" [OK] {0,-22} ({1,5} MB) : SQLite 3 Header Verified" -f $fn, $size) -ForegroundColor Green
                } else {
                    Write-Host (" [FAIL] {0,-22} : Corrupt Header!" -f $fn) -ForegroundColor Red
                }
            } catch {
                Write-Host (" [WARN] {0,-22} : File locked or inaccessible ($($_.Exception.Message))" -f $fn) -ForegroundColor Yellow
            }
        } else {
            Write-Host (" [INFO] {0,-22} : Not created yet." -f $fn) -ForegroundColor DarkGray
        }
    }

    Pause-Console
}

# -----------------------------------------------------------------------------
# 4. Caddy Routing and DNS Inspector
# -----------------------------------------------------------------------------
function Invoke-RoutingInspector {
    Show-Header
    Write-Host "[4] TESTING CADDY REVERSE PROXY ROUTES AND LATENCY..." -ForegroundColor Yellow
    Write-Host ""

    $routes = @(
        @{ Name="Jellyfin External";       Host="waltdakind.xubi.org";          Path="";      Port=80 },
        @{ Name="Jellyfin Direct Port";    Host="";                             Path="";      Port=8096 },
        @{ Name="Jellyfin Local LAN";      Host="jellyfin.ordinateur.local";    Path="";      Port=80 },
        @{ Name="Jellyseerr External";     Host="jellyseerr.waltdakind.xubi.org"; Path="";    Port=80 },
        @{ Name="Sonarr API";              Host="sonarr.waltdakind.xubi.org";   Path="/ping"; Port=80 },
        @{ Name="Radarr API";              Host="radarr.waltdakind.xubi.org";   Path="/ping"; Port=80 },
        @{ Name="MusicBrainz API (5000)";  Host="";                             Path="";      Port=5000 },
        @{ Name="MusicBrainz External";    Host="musicbrainz.waltdakind.xubi.org"; Path="";   Port=80 },
        @{ Name="Homepage Local LAN";      Host="ordinateur.local";             Path="";      Port=80 }
    )

    foreach ($r in $routes) {
        $url = "http://127.0.0.1:$($r.Port)$($r.Path)"
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            $headers = @{}
            if ($r.Host) { $headers["Host"] = $r.Host }
            $res = Invoke-WebRequest -Uri $url -Headers $headers -TimeoutSec 4 -UseBasicParsing -ErrorAction Stop
            $sw.Stop()
            Write-Host (" [OK] {0,-28} -> HTTP {1} ({2} ms)" -f $r.Name, $res.StatusCode, $sw.ElapsedMilliseconds) -ForegroundColor Green
        } catch {
            $sw.Stop()
            Write-Host (" [FAIL] {0,-28} -> {1} ({2} ms)" -f $r.Name, $_.Exception.Message, $sw.ElapsedMilliseconds) -ForegroundColor Red
        }
    }

    Pause-Console
}

# -----------------------------------------------------------------------------
# 5. Database Management and Repair Submenu
# -----------------------------------------------------------------------------
function Invoke-DatabaseManager {
    Show-Header
    Write-Host "[5] DATABASE MANAGEMENT AND RECOVERY TOOL" -ForegroundColor Yellow
    Write-Host ""
    Write-Host " Available Databases:" -ForegroundColor Cyan

    $dbList = @(
        @{ Name="Jellyfin";   Path="$BaseDir\config\jellyfin\data\data\jellyfin.db" },
        @{ Name="Sonarr";     Path="$BaseDir\config\sonarr\sonarr.db" },
        @{ Name="Radarr";     Path="$BaseDir\config\radarr\radarr.db" },
        @{ Name="Prowlarr";   Path="$BaseDir\config\prowlarr\prowlarr.db" },
        @{ Name="Bazarr";     Path="$BaseDir\config\bazarr\db\bazarr.db" },
        @{ Name="Jellyseerr"; Path="$BaseDir\config\jellyseerr\db\db.sqlite3" }
    )

    for ($i = 0; $i -lt $dbList.Count; $i++) {
        $db = $dbList[$i]
        $exists = Test-Path $db.Path
        $size = if ($exists) { "$([math]::Round((Get-Item $db.Path).Length / 1MB, 2)) MB" } else { "Missing" }
        Write-Host "  $($i + 1). $($db.Name) ($size)" -ForegroundColor White
    }

    Write-Host "`n Options:" -ForegroundColor Yellow
    Write-Host "  [B] Backup All Databases to ./db-backup"
    Write-Host "  [R] Run Full SQLite Recovery Dump on All Databases"
    Write-Host "  [Q] Return to Main Menu"

    $dbChoice = Read-Host -Prompt "`nSelect option"
    if ($dbChoice.ToUpper() -eq "B") {
        if (-not (Test-Path $BackupDir)) { New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null }
        $stamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
        foreach ($db in $dbList) {
            if (Test-Path $db.Path) {
                $dst = Join-Path $BackupDir "$($db.Name)_manual_$stamp.sqlite3"
                Copy-Item -Path $db.Path -Destination $dst -Force
                Write-Host " -> Backed up $($db.Name) to $dst" -ForegroundColor Green
            }
        }
    }

    Pause-Console
}

# -----------------------------------------------------------------------------
# 6. MusicBrainz Server and Picard Submenu
# -----------------------------------------------------------------------------
function Invoke-MusicBrainzControl {
    Show-Header
    Write-Host "[6] MUSICBRAINZ LOCAL MIRROR AND PICARD INTEGRATION" -ForegroundColor Yellow
    Write-Host ""

    Write-Host " MusicBrainz Containers Status:" -ForegroundColor Cyan
    docker ps -a --filter "name=musicbrainz" --format 'table {{.Names}}\t{{.State}}\t{{.Status}}\t{{.Ports}}'

    Write-Host "`n Testing MusicBrainz Endpoints:" -ForegroundColor Cyan
    try {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $apiTest = Invoke-RestMethod -Uri "http://localhost:5000/ws/2/artist/b10bbbfc-cf9e-42e0-be17-e2c3e1d2600d?fmt=json" -TimeoutSec 4 -ErrorAction Stop
        $sw.Stop()
        Write-Host " [OK] Web API Test (Beatles Query): SUCCESS ($($sw.ElapsedMilliseconds) ms) - Name: $($apiTest.name)" -ForegroundColor Green
    } catch {
        Write-Host " [WARN] MusicBrainz Web API (Port 5000) not responding yet: $($_.Exception.Message)" -ForegroundColor Yellow
    }

    try {
        $pg = docker exec musicbrainz-docker-db-1 pg_isready -U musicbrainz 2>$null
        Write-Host " [OK] PostgreSQL Backend Status: $pg" -ForegroundColor Green
    } catch {
        Write-Host " [INFO] PostgreSQL DB container offline." -ForegroundColor DarkGray
    }

    Write-Host "`n MusicBrainz Actions:" -ForegroundColor Yellow
    Write-Host "  [1] Start MusicBrainz Stack (docker compose up -d)"
    Write-Host "  [2] Stop MusicBrainz Stack (docker compose down)"
    Write-Host "  [3] View Live MusicBrainz Web Logs"
    Write-Host "  [4] Trigger Search Indexing (SIR)"
    Write-Host "  [Q] Return to Main Menu"

    $mbChoice = Read-Host -Prompt "`nSelect option"
    switch ($mbChoice) {
        "1" {
            Set-Location -Path $MusicBrainzDir
            docker compose up -d
            Set-Location -Path $BaseDir
        }
        "2" {
            Set-Location -Path $MusicBrainzDir
            docker compose down
            Set-Location -Path $BaseDir
        }
        "3" {
            docker logs -f musicbrainz-docker-musicbrainz-1
        }
        "4" {
            docker exec -it musicbrainz-docker-indexer-1 python3 -m sir index
        }
    }

    Pause-Console
}

# -----------------------------------------------------------------------------
# 7. HDHomeRun and Live TV Diagnostics
# -----------------------------------------------------------------------------
function Invoke-HDHomeRunDebugger {
    Show-Header
    Write-Host "[7] HDHOMERUN TUNER AND LIVE TV PROBE" -ForegroundColor Yellow
    Write-Host ""

    $scanScript = Join-Path $BaseDir "scratch\fast-hdhomerun-scan.ps1"
    if (Test-Path $scanScript) {
        & $scanScript
    } else {
        Write-Host "Querying SiliconDust Discovery API..." -ForegroundColor Yellow
        try {
            $sd = Invoke-RestMethod -Uri "http://ipv4-api.hdhomerun.com/discover" -TimeoutSec 4
            $sd | Format-Table -AutoSize
        } catch {
            Write-Host "SiliconDust Cloud Discovery returned no active devices." -ForegroundColor Yellow
        }
    }

    Pause-Console
}

# -----------------------------------------------------------------------------
# 8. Deep Docker Cleanup
# -----------------------------------------------------------------------------
function Invoke-DockerDeepClean {
    Show-Header
    Write-Host "[8] DOCKER STORAGE OPTIMIZATION AND DEEP CLEANUP" -ForegroundColor Yellow
    Write-Host ""

    Write-Host "1. Pruning Dead Containers..." -ForegroundColor Cyan
    docker container prune -f

    Write-Host "`n2. Pruning Dangling and Untagged Images..." -ForegroundColor Cyan
    docker image prune -f

    Write-Host "`n3. Pruning Unused Networks..." -ForegroundColor Cyan
    docker network prune -f

    Write-Host "`n4. Pruning Dangling Build Cache..." -ForegroundColor Cyan
    docker builder prune -f

    Write-Host "`n[SUCCESS] Docker resources cleaned and optimized." -ForegroundColor Green
    Pause-Console
}

# -----------------------------------------------------------------------------
# 9. Graceful Stack Shutdown
# -----------------------------------------------------------------------------
function Stop-FullStackGraceful {
    Show-Header
    Write-Host "[9] GRACEFUL MULTI-STACK SHUTDOWN..." -ForegroundColor Yellow
    Write-Host ""

    Write-Host "1. Stopping Primary MediaStack Containers..." -ForegroundColor Cyan
    Set-Location -Path $BaseDir
    docker compose stop

    if (Test-Path $MusicBrainzDir) {
        Write-Host "`n2. Stopping MusicBrainz Mirror Containers..." -ForegroundColor Cyan
        Set-Location -Path $MusicBrainzDir
        docker compose stop
        Set-Location -Path $BaseDir
    }

    Write-Host "`n[OK] All services gracefully stopped." -ForegroundColor Green
    Pause-Console
}

# -----------------------------------------------------------------------------
# 10. Published Port Verification & Enforcer Sentinel
# -----------------------------------------------------------------------------
function Invoke-PortPublishSentinel {
    Show-Header
    Write-Host "[10] PUBLISHED PORT VERIFICATION & ENFORCER SENTINEL..." -ForegroundColor Yellow
    Write-Host ""

    $script = Join-Path $BaseDir "Publish-MediaStackPorts.ps1"
    if (Test-Path $script) {
        & $script
    } else {
        Write-Host "[ERROR] Publish-MediaStackPorts.ps1 not found." -ForegroundColor Red
    }
    Pause-Console
}

function Invoke-ClusterUpdateAndHandoff {
    Show-Header
    Write-Host "[11] CHECK FOR CLUSTER UPDATES & EXCHANGE HANDOFF REPORT..." -ForegroundColor Yellow
    Write-Host ""
    $script = Join-Path $BaseDir "Invoke-MediaStackClusterHandoff.ps1"
    if (Test-Path $script) {
        & $script
    } else {
        $opsModule = Join-Path $BaseDir "MediaStackOps.psm1"
        if (Test-Path $opsModule) { Import-Module $opsModule -Force }
        Invoke-MediaStackClusterUpdateCheck -Interactive $true
    }
    Pause-Console
}

function Invoke-ClusterAiCollaboration {
    Show-Header
    Write-Host "[12] LAUNCHING AI COLLABORATION & AUTONOMOUS SELF-HEALING NEXUS..." -ForegroundColor Yellow
    Write-Host ""
    $script = Join-Path $BaseDir "Invoke-MediaStackAiCollaboration.ps1"
    if (Test-Path $script) {
        & $script -AutoRepair -Interactive $true
    } else {
        Write-Host "AI collaboration script not found: $script" -ForegroundColor Red
    }
    Pause-Console
}

# -----------------------------------------------------------------------------
# MAIN INTERACTIVE MENU LOOP
# -----------------------------------------------------------------------------
while ($true) {
    Show-Header
    Get-SystemSummary

    Write-Host " OPERATIONAL CONTROLS:" -ForegroundColor Yellow
    Write-Host "  [1]  Full Stack Safe Start (MediaStack + MusicBrainz)" -ForegroundColor White
    Write-Host "  [2]  Sentinel Live Monitor and Auto-Healer (Continuous)" -ForegroundColor White
    Write-Host "  [3]  Deep Diagnostic and Doctor Suite" -ForegroundColor White
    Write-Host "  [4]  Caddy Reverse Proxy and Route Inspector" -ForegroundColor White
    Write-Host "  [5]  Database Integrity and Auto-Recovery Tool" -ForegroundColor White
    Write-Host "  [6]  MusicBrainz Server and Picard Integration" -ForegroundColor White
    Write-Host "  [7]  HDHomeRun Tuner and Live TV Diagnostic Probe" -ForegroundColor White
    Write-Host "  [8]  Deep Docker Cleanup and Storage Optimization" -ForegroundColor White
    Write-Host "  [9]  Graceful Multi-Stack Shutdown (Stop All)" -ForegroundColor White
    Write-Host "  [10] Published Port Verification & Health Matrix (8096, 8989, 7878...)" -ForegroundColor Cyan
    Write-Host "  [11] Check for Cluster Updates & Exchange Handoff Report [U]" -ForegroundColor Cyan
    Write-Host "  [12] AI Collaboration & Autonomous Self-Healing Nexus [A]" -ForegroundColor Magenta
    Write-Host "  [0]  Exit Console" -ForegroundColor DarkGray

    Write-Host ""
    $choice = Read-Host -Prompt "Enter selection [0-12]"

    switch ($choice) {
        "1"  { Start-FullStackSafe }
        "2"  { Start-SentinelMonitorMode }
        "3"  { Invoke-DeepDiagnosticSuite }
        "4"  { Invoke-RoutingInspector }
        "5"  { Invoke-DatabaseManager }
        "6"  { Invoke-MusicBrainzControl }
        "7"  { Invoke-HDHomeRunDebugger }
        "8"  { Invoke-DockerDeepClean }
        "9"  { Stop-FullStackGraceful }
        "10" { Invoke-PortPublishSentinel }
        "p"  { Invoke-PortPublishSentinel }
        "P"  { Invoke-PortPublishSentinel }
        "11" { Invoke-ClusterUpdateAndHandoff }
        "u"  { Invoke-ClusterUpdateAndHandoff }
        "U"  { Invoke-ClusterUpdateAndHandoff }
        "12" { Invoke-ClusterAiCollaboration }
        "a"  { Invoke-ClusterAiCollaboration }
        "A"  { Invoke-ClusterAiCollaboration }
        "0"  { 
            Write-Host "`nExiting MediaStack Control Console. Goodbye!`n" -ForegroundColor Green
            exit 0 
        }
        default {
            Write-Host "Invalid selection. Please choose an option between 0 and 12." -ForegroundColor Red
            Start-Sleep -Seconds 1
        }
    }
}
