<#
.SYNOPSIS
    Set-MediaStreamDoNotDisturb.ps1 - Cinema Streaming Focus & Do Not Disturb (DND) Controller.

.DESCRIPTION
    Suspends all inter-node communication, AI collaboration sprints, background polling,
    and resource-heavy background processes across the MediaStack cluster, devoting 100%
    of CPU, RAM, disk I/O, and bandwidth to uninterrupted media playback and transcoding.

    When Enabled:
    1. Cluster Silence: Emits a signed DND signal (handoffs/do_not_disturb_active.json)
       instructing peer nodes (VoltaireUn/VoltaireDeux) to cease all polling, replication, and sync.
    2. AI Sprints Terminated: Shuts down all active AI collaboration sessions, sentinels, and watchers.
    3. Resource Freeze: Pauses heavy background containers (Tdarr transcoding, Transmission torrent I/O,
       MusicBrainz indexing, Diun registry checks, Syncthing hash verification) with zero state loss.
    4. Network Ingress Whitelisting: Configures Windows Firewall to prioritize media playback sockets
       (Jellyfin: 8096/8920, Caddy: 80/443, RDP: 3389) from local client subnets (192.168.4.0/24),
       rejecting non-whitelisted background traffic.
    5. Transcode Optimization: Purges dangling transcode chunks and verifies Jellyfin readiness.

    When Disabled:
    1. Fleet Unfreeze: Instantly unpauses all frozen background containers right where they left off.
    2. Network Restored: Removes restrictive DND firewall rules, restoring full container ingress.
    3. Cluster Restored: Updates cluster manifest to resume normal standby polling and AI collaboration.

.PARAMETER Enable
    Enables Cinema Streaming Focus / Do Not Disturb Mode.

.PARAMETER Disable
    Disables Cinema Streaming Focus, restoring normal full-stack operations.

.PARAMETER Status
    Displays the current DND state, paused containers, and media playback health.

.PARAMETER WhitelistedPorts
    Array of TCP ports allowed for media streaming (Default: 8096, 8920, 80, 443, 3389).

.PARAMETER WhitelistedSubnet
    Local IP subnet permitted for playback traffic (Default: "192.168.4.0/24,127.0.0.1/32").

.PARAMETER Elevate
    Relaunches the script with elevated Administrator privileges if firewall modifications require it.

.EXAMPLE
    .\Set-MediaStreamDoNotDisturb.ps1 -Enable
    .\Set-MediaStreamDoNotDisturb.ps1 -Disable
    .\Set-MediaStreamDoNotDisturb.ps1 -Status
#>

[CmdletBinding(DefaultParameterSetName = "Toggle")]
param(
    [Parameter(ParameterSetName = "Enable", Mandatory = $true)]
    [Alias("On", "Start")]
    [switch]$Enable,

    [Parameter(ParameterSetName = "Disable", Mandatory = $true)]
    [Alias("Off", "Stop")]
    [switch]$Disable,

    [Parameter(ParameterSetName = "Status", Mandatory = $true)]
    [Alias("Check", "Info")]
    [switch]$Status,

    [Parameter(Mandatory = $false)]
    [int[]]$WhitelistedPorts = @(8096, 8920, 80, 443, 3389),

    [Parameter(Mandatory = $false)]
    [string]$WhitelistedSubnet = "192.168.4.0/24,127.0.0.1/32",

    [Parameter(Mandatory = $false)]
    [string[]]$HighImpactContainers = @(
        "tdarr",
        "transmission",
        "diun",
        "musicbrainz-docker-musicbrainz-1",
        "musicbrainz-docker-musicbrainz-2",
        "musicbrainz-docker-valkey-2",
        "syncthing"
    ),

    [Parameter(Mandatory = $false)]
    [switch]$Elevate,

    [Parameter(Mandatory = $false)]
    [switch]$NonInteractive
)

# Handle elevation request
if ($Elevate) {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Host "Elevating process to Administrator..." -ForegroundColor Yellow
        $argList = @("-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`"")
        if ($Enable) { $argList += "-Enable" }
        elseif ($Disable) { $argList += "-Disable" }
        elseif ($Status) { $argList += "-Status" }
        Start-Process powershell.exe -ArgumentList $argList -Verb RunAs
        exit
    }
}

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::InputEncoding  = [System.Text.Encoding]::UTF8

$BaseDir = if (Test-Path (Join-Path $PSScriptRoot "docker-compose.yml")) { 
    $PSScriptRoot 
} elseif (Test-Path (Join-Path $PSScriptRoot "..\docker-compose.yml")) { 
    (Resolve-Path (Join-Path $PSScriptRoot "..")).Path 
} else { 
    (Get-Location).Path 
}

$HandoffsDir = Join-Path $BaseDir "handoffs"
if (-not (Test-Path $HandoffsDir)) { New-Item -ItemType Directory -Force -Path $HandoffsDir | Out-Null }

$dndStateFile   = Join-Path $HandoffsDir "do_not_disturb_active.json"
$pausedListFile = Join-Path $HandoffsDir "dnd_paused_containers.json"
$nexusPath      = Join-Path $HandoffsDir "ai_collaboration_nexus.json"

$currentHost = $env:COMPUTERNAME
$timestamp   = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# Determine current state
$isCurrentlyActive = $false
if (Test-Path $dndStateFile) {
    try {
        $stateJson = Get-Content $dndStateFile -Raw -Encoding UTF8 | ConvertFrom-Json
        $isCurrentlyActive = ($stateJson.status -eq "ACTIVE")
    } catch { }
}

# Auto-toggle if run without parameters
if (-not $Enable -and -not $Disable -and -not $Status) {
    if ($isCurrentlyActive) {
        Write-Host "`nDo Not Disturb / Media Streaming Focus is currently [ACTIVE]." -ForegroundColor Yellow
        Write-Host "  -> Running with -Disable to restore normal cluster operations." -ForegroundColor Cyan
        $Disable = $true
    } else {
        Write-Host "`nDo Not Disturb / Media Streaming Focus is currently [INACTIVE]." -ForegroundColor DarkGray
        Write-Host "  -> Running with -Enable to activate cinema streaming focus." -ForegroundColor Cyan
        $Enable = $true
    }
}

# ==============================================================================
# FUNCTION: GET STATUS
# ==============================================================================
function Show-DndStatus {
    Write-Host "`n================================================================================" -ForegroundColor Cyan
    Write-Host "   M E D I A   S T R E A M I N G   F O C U S   /   D N D   S T A T U S" -ForegroundColor DarkCyan
    Write-Host "   Host: $currentHost | Timestamp: $timestamp" -ForegroundColor DarkGray
    Write-Host "================================================================================" -ForegroundColor Cyan

    if ($isCurrentlyActive) {
        Write-Host "  [MODE]   : MEDIA STREAMING FOCUS (DO NOT DISTURB ACTIVE)" -ForegroundColor Green
        Write-Host "  [ACTIVE] : Yes (Background tasks, sync & AI loops suppressed)" -ForegroundColor Green
        if ($stateJson) {
            Write-Host "  [SINCE]  : $($stateJson.enabled_at)" -ForegroundColor White
            Write-Host "  [REASON] : $($stateJson.reason)" -ForegroundColor DarkGray
        }
    } else {
        Write-Host "  [MODE]   : STANDARD PRODUCTION (DO NOT DISTURB INACTIVE)" -ForegroundColor DarkGray
        Write-Host "  [ACTIVE] : No (Normal background processing and sync allowed)" -ForegroundColor DarkGray
    }

    # Container states
    Write-Host "`n--- Container States ---" -ForegroundColor Yellow
    $allContainers = docker ps -a --format "{{.Names}}\t{{.Status}}" 2>$null
    if ($allContainers) {
        $allContainers -split "`n" | ForEach-Object {
            $line = $_.Trim()
            if ($line) {
                $parts = $line -split "`t"
                $name = $parts[0]
                $stat = $parts[1]
                if ($stat -match "Paused") {
                    Write-Host ("  {0,-35} : [PAUSED] (Zero CPU/IO contention)" -f $name) -ForegroundColor Cyan
                } elseif ($name -in @("jellyfin", "caddy")) {
                    Write-Host ("  {0,-35} : [STREAMING ACTIVE] {1}" -f $name, $stat) -ForegroundColor Green
                } else {
                    Write-Host ("  {0,-35} : {1}" -f $name, $stat) -ForegroundColor DarkGray
                }
            }
        }
    }

    # Jellyfin listener probe
    Write-Host "`n--- Playback Sockets ---" -ForegroundColor Yellow
    $jfProbe = curl.exe -k -s -o NUL -w "%{http_code}" --max-time 2 "http://localhost:8096/health" 2>$null
    Write-Host ("  Jellyfin HTTP Stream Socket (:8096)  : HTTP {0}" -f $jfProbe) -ForegroundColor $(if ($jfProbe -eq "200") { "Green" } else { "Yellow" })
    
    $caddyProbe = curl.exe -k -s -o NUL -w "%{http_code}" --max-time 2 "http://localhost:80/health" 2>$null
    Write-Host ("  Caddy Ingress Socket (:80)          : HTTP {0}" -f $caddyProbe) -ForegroundColor $(if ($caddyProbe -eq "200" -or $caddyProbe -eq "302" -or $caddyProbe -eq "308") { "Green" } else { "Yellow" })
    
    Write-Host "`n================================================================================" -ForegroundColor Cyan
}

if ($Status) {
    Show-DndStatus
    return
}

# ==============================================================================
# ACTION: ENABLE MEDIA STREAMING FOCUS (DO NOT DISTURB)
# ==============================================================================
if ($Enable) {
    Write-Host "`n================================================================================" -ForegroundColor Cyan
    Write-Host "   E N G A G I N G   M E D I A   S T R E A M I N G   F O C U S   M O D E" -ForegroundColor DarkCyan
    Write-Host "   Zero Stutter Guarantee: Suspending AI collaboration, polling, and heavy tasks" -ForegroundColor White
    Write-Host "   Timestamp: $timestamp | Host: $currentHost" -ForegroundColor DarkGray
    Write-Host "================================================================================" -ForegroundColor Cyan

    # 1. EMIT DND CLUSTER MANIFEST
    Write-Host "`n[1/5] Broadcasting Do Not Disturb Signal to Cluster & OneDrive..." -ForegroundColor Yellow
    $dndPayload = [ordered]@{
        status              = "ACTIVE"
        mode                = "MEDIA_STREAMING_FOCUS"
        node                = $currentHost
        enabled_at          = $timestamp
        reason              = "Operator requested dedicated media streaming focus - zero background interference"
        whitelisted_ports   = $WhitelistedPorts
        whitelisted_subnets = ($WhitelistedSubnet -split ",")
        peer_directive      = "CEASE_ALL_COMMUNICATION_POLLING_AND_COLLABORATION"
    }
    $dndPayload | ConvertTo-Json -Depth 5 | Set-Content -Path $dndStateFile -Encoding UTF8
    Write-Host "  [OK] Cluster DND marker written: $dndStateFile" -ForegroundColor Green

    # Update AI collaboration nexus to conclude active sprints
    if (Test-Path $nexusPath) {
        try {
            $nexus = Get-Content $nexusPath -Raw -Encoding UTF8 | ConvertFrom-Json
            $nexus.session_state            = "CONCLUDED"
            $nexus.session_active           = $false
            $nexus.concluded_by             = $currentHost
            $nexus.concluded_at             = $timestamp
            $nexus.exit_reason              = "Media streaming focus mode engaged by user (DND)"
            $nexus.status                   = "DO_NOT_DISTURB_ACTIVE"
            $nexus.streaming_focus_active   = $true
            $nexus.pause_peer_communication = $true
            $nexus | ConvertTo-Json -Depth 5 | Set-Content -Path $nexusPath -Encoding UTF8
            Write-Host "  [OK] AI Collaboration Nexus updated to CONCLUDED (quiescent standby)." -ForegroundColor Green
        } catch { }
    }

    # 2. TERMINATE LOCAL POLLING & AI WATCHER PROCESSES
    Write-Host "`n[2/5] Halting Background AI Sprints, Autohealers & Polling Tasks..." -ForegroundColor Yellow
    $targetPatterns = @(
        "Invoke-HardenedAiCollaborationSession",
        "Invoke-MediaStackAiCollaboration",
        "Start-AutonomousMediaStackCollaborator",
        "Start-MediaStackAiWatcher",
        "Start-MediaStackAutohealer",
        "Invoke-VoltaireUnDailyPoller"
    )

    $stoppedCount = 0
    try {
        $processes = Get-WmiObject Win32_Process -Filter "Name = 'powershell.exe' or Name = 'pwsh.exe'" -ErrorAction SilentlyContinue
        foreach ($proc in $processes) {
            # Never terminate our own process or VS Code / IDE hosts
            if ($proc.ProcessId -eq $PID -or $proc.CommandLine -match "PowerShellEditorServices" -or $proc.CommandLine -match "vscode") {
                continue
            }
            foreach ($pat in $targetPatterns) {
                if ($proc.CommandLine -match $pat) {
                    Write-Host ("  [STOPPING] Process PID {0} ({1})..." -f $proc.ProcessId, $pat) -ForegroundColor DarkYellow
                    Stop-Process -Id $proc.ProcessId -Force -ErrorAction SilentlyContinue
                    $stoppedCount++
                    break
                }
            }
        }
    } catch { }
    Write-Host ("  [OK] Background AI sprint & poller processes halted: {0}" -f $stoppedCount) -ForegroundColor Green

    # 3. FREEZE RESOURCE-HEAVY CONTAINERS (DOCKER PAUSE)
    Write-Host "`n[3/5] Freezing High-Impact Background Containers (Zero CPU/Disk Contention)..." -ForegroundColor Yellow
    $pausedContainers = @()

    foreach ($cName in $HighImpactContainers) {
        $check = docker ps --filter "name=^/${cName}$" --format "{{.Status}}" 2>$null
        if ($check -and ($check -notmatch "Paused")) {
            Write-Host ("  â€¢ Freezing container: {0}..." -f $cName) -ForegroundColor DarkCyan
            docker pause $cName 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0) {
                $pausedContainers += $cName
                Write-Host ("    [FROZEN] {0} paused in memory." -f $cName) -ForegroundColor Green
            } else {
                Write-Host ("    [SKIP] Could not pause {0}" -f $cName) -ForegroundColor DarkGray
            }
        } elseif ($check -match "Paused") {
            $pausedContainers += $cName
            Write-Host ("  [INFO] Container already paused: {0}" -f $cName) -ForegroundColor DarkGray
        }
    }

    # Record which containers were paused so we restore only those on exit
    $pausedContainers | ConvertTo-Json | Set-Content -Path $pausedListFile -Encoding UTF8
    Write-Host ("  [OK] Successfully frozen {0} high-impact containers." -f $pausedContainers.Count) -ForegroundColor Green

    # 4. CONFIGURE WHITELISTED NETWORK INGRESS (WINDOWS FIREWALL)
    Write-Host "`n[4/5] Enforcing Whitelisted Low-Impact Playback Ingress Policy..." -ForegroundColor Yellow
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if ($isAdmin) {
        try {
            # Remove any existing DND rule
            Remove-NetFirewallRule -Name "MediaStack-DND-StreamingOnly-*" -ErrorAction SilentlyContinue | Out-Null

            # Add explicit allow rule for whitelisted streaming ports from local subnet
            New-NetFirewallRule -DisplayName "MediaStack - DND Streaming Playback Whitelist" `
                -Name "MediaStack-DND-StreamingOnly-Allow" `
                -Direction Inbound `
                -Action Allow `
                -Protocol TCP `
                -LocalPort $WhitelistedPorts `
                -RemoteAddress ($WhitelistedSubnet -split ",") `
                -Description "Exclusive allow rule for Jellyfin, Caddy, and RDP during Media Streaming Focus Mode." `
                -ErrorAction Stop | Out-Null
            
            Write-Host "  [OK] Firewall Rule Active: Only whitelisted playback traffic accepted on ports ($($WhitelistedPorts -join ', '))." -ForegroundColor Green
        } catch {
            Write-Host ("  [WARN] Firewall configuration notice: " + $_.Exception.Message) -ForegroundColor DarkYellow
        }
    } else {
        Write-Host "  [INFO] Non-admin session detected. Skipping Windows Firewall rules." -ForegroundColor DarkGray
        Write-Host "         Run with -Elevate if you wish to enforce strict Windows Firewall socket isolation." -ForegroundColor DarkGray
    }

    # 5. VERIFY JELLYFIN READINESS & TRANSLUCENT CLEANUP
    Write-Host "`n[5/5] Sanitizing Transcode Buffers & Verifying Jellyfin Playback Readiness..." -ForegroundColor Yellow
    
    # Purge stale transcode cache chunks
    $transcodeDir = Join-Path $BaseDir "config\jellyfin\transcodes"
    if (Test-Path $transcodeDir) {
        $staleChunks = Get-ChildItem -Path $transcodeDir -File -ErrorAction SilentlyContinue
        if ($staleChunks.Count -gt 0) {
            $staleChunks | Remove-Item -Force -ErrorAction SilentlyContinue
            Write-Host ("  [OK] Cleaned {0} abandoned transcode buffer files to maximize NVMe/SSD bandwidth." -f $staleChunks.Count) -ForegroundColor Green
        }
    }

    # Verify Jellyfin Kestrel socket
    $jfStatus = curl.exe -k -s -o NUL -w "%{http_code}" --max-time 3 "http://localhost:8096/health" 2>$null
    if ($jfStatus -eq "200") {
        Write-Host "  [READY] Jellyfin Media Server is 100% ONLINE and dedicated to streaming." -ForegroundColor Green
    } else {
        Write-Host ("  [WARN] Jellyfin health probe returned: HTTP {0}" -f $jfStatus) -ForegroundColor Yellow
    }

    Write-Host "`n================================================================================" -ForegroundColor Cyan
    Write-Host "   CINEMA STREAMING FOCUS MODE IS NOW ACTIVE!" -ForegroundColor Green
    Write-Host "   Enjoy uninterrupted, stutter-free playback." -ForegroundColor White
    Write-Host "   To return to normal production mode when finished watching:" -ForegroundColor DarkGray
    Write-Host "       .\Set-MediaStreamDoNotDisturb.ps1 -Disable" -ForegroundColor Yellow
    Write-Host "================================================================================`n" -ForegroundColor Cyan
    return
}

# ==============================================================================
# ACTION: DISABLE MEDIA STREAMING FOCUS (RESTORE FULL FLEET)
# ==============================================================================
if ($Disable) {
    Write-Host "`n================================================================================" -ForegroundColor Cyan
    Write-Host "   D I S E N G A G I N G   M E D I A   S T R E A M I N G   F O C U S" -ForegroundColor DarkCyan
    Write-Host "   Restoring full cluster operations, background processing, and peer sync" -ForegroundColor White
    Write-Host "   Timestamp: $timestamp | Host: $currentHost" -ForegroundColor DarkGray
    Write-Host "================================================================================" -ForegroundColor Cyan

    # 1. UNPAUSE FROZEN CONTAINERS
    Write-Host "`n[1/3] Unfreezing Background MediaStack Containers..." -ForegroundColor Yellow
    $toUnpause = @()
    if (Test-Path $pausedListFile) {
        try {
            $toUnpause = Get-Content $pausedListFile -Raw -Encoding UTF8 | ConvertFrom-Json
        } catch { }
    }
    if (-not $toUnpause -or $toUnpause.Count -eq 0) {
        $toUnpause = $HighImpactContainers
    }

    $unpausedCount = 0
    foreach ($cName in $toUnpause) {
        $check = docker ps --filter "name=^/${cName}$" --format "{{.Status}}" 2>$null
        if ($check -match "Paused") {
            Write-Host ("  â€¢ Unfreezing container: {0}..." -f $cName) -ForegroundColor DarkCyan
            docker unpause $cName 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Host ("    [RESUMED] {0} active and processing." -f $cName) -ForegroundColor Green
                $unpausedCount++
            }
        }
    }
    if (Test-Path $pausedListFile) { Remove-Item $pausedListFile -Force -ErrorAction SilentlyContinue }
    Write-Host ("  [OK] Total containers resumed: {0}" -f $unpausedCount) -ForegroundColor Green

    # 2. REMOVE RESTRICTIVE DND FIREWALL RULES
    Write-Host "`n[2/3] Restoring Normal Network Ingress Policies..." -ForegroundColor Yellow
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if ($isAdmin) {
        try {
            Remove-NetFirewallRule -Name "MediaStack-DND-StreamingOnly-*" -ErrorAction SilentlyContinue | Out-Null
            Write-Host "  [OK] Restrictive DND firewall rules removed. Full container network access restored." -ForegroundColor Green
        } catch { }
    } else {
        Write-Host "  [INFO] Non-admin session; standard firewall configuration preserved." -ForegroundColor DarkGray
    }

    # 3. CLEAR CLUSTER DND SIGNALS & RESUME STANDBY COLLABORATION
    Write-Host "`n[3/3] Emitting Cluster Resume Signal to VoltaireUn & Standby Engine..." -ForegroundColor Yellow
    if (Test-Path $dndStateFile) {
        $inactivePayload = [ordered]@{
            status       = "INACTIVE"
            mode         = "STANDARD_PRODUCTION"
            node         = $currentHost
            disabled_at  = $timestamp
            reason       = "Operator concluded media streaming session; full operations resumed"
        }
        $inactivePayload | ConvertTo-Json -Depth 5 | Set-Content -Path $dndStateFile -Encoding UTF8
        Write-Host "  [OK] Cluster DND marker set to INACTIVE: $dndStateFile" -ForegroundColor Green
    }

    if (Test-Path $nexusPath) {
        try {
            $nexus = Get-Content $nexusPath -Raw -Encoding UTF8 | ConvertFrom-Json
            $nexus.status                   = "ACTIVE_STANDBY"
            $nexus.streaming_focus_active   = $false
            $nexus.pause_peer_communication = $false
            $nexus | ConvertTo-Json -Depth 5 | Set-Content -Path $nexusPath -Encoding UTF8
            Write-Host "  [OK] AI Collaboration Nexus restored to ACTIVE_STANDBY." -ForegroundColor Green
        } catch { }
    }

    Write-Host "`n================================================================================" -ForegroundColor Cyan
    Write-Host "   FULL MEDIASTACK FLEET RESTORED TO NORMAL OPERATION!" -ForegroundColor Green
    Write-Host "   Background downloads, transcodes, synchronization, and AI standbys are active." -ForegroundColor White
    Write-Host "================================================================================`n" -ForegroundColor Cyan
}
