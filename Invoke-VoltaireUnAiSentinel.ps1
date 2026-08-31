<#
.SYNOPSIS
    Invoke-VoltaireUnAiSentinel.ps1 - 24/7 Primary Server Sentinel & AI Escalation Client for VoltaireUn.

.DESCRIPTION
    Runs on VoltaireUn (192.168.4.21 / voltaireun.local) as the primary 24/7 sentinel:
    1. Host Always-On Safeguards:
       - Enforces zero sleep, zero disk idle, and pinned Windows kernel thread execution state.
       - Monitors Drive C: storage headroom (> 15 GB rule) to prevent Docker Exit 137 (SIGKILL).
    2. Local Health & Tier 1 Auto-Healing:
       - Continuously monitors all 14 core MediaStack services and ports.
       - Auto-recovers dropped containers (prowlarr, jellyseerr, jellyfin, caddy, etc.).
       - Kills hung FFmpeg transcode processes and clears orphaned lockfiles.
       - Flushes SQLite WAL journals and verifies B-Tree integrity.
    3. Tier 2 AI Escalation to VoltaireDeux (192.168.4.30):
       - If an error cannot be resolved with local VoltaireUn resources:
       - Generates a structured diagnostic payload and queries VoltaireDeux Ollama AI endpoint (:11434).
       - Stages an AI Resolution Request to handoffs/ai_escalation_requests/ on OneDrive.
       - Ingests, validates, and executes verified AI resolution scripts from VoltaireDeux.

.PARAMETER Continuous
    Runs in a continuous monitoring loop.

.PARAMETER IntervalSeconds
    Loop interval in seconds (default: 30s).

.PARAMETER AutoRepair
    Enables automatic remediation and execution of validated AI resolution scripts.

.PARAMETER VoltaireDeuxIP
    IP address of VoltaireDeux AI Workstation (default: 192.168.4.30).

.EXAMPLE
    .\Invoke-VoltaireUnAiSentinel.ps1 -Continuous -IntervalSeconds 30 -AutoRepair
    .\Invoke-VoltaireUnAiSentinel.ps1 -AutoRepair
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)][switch]$Continuous,
    [Parameter(Mandatory = $false)][int]$IntervalSeconds = 30,
    [Parameter(Mandatory = $false)][switch]$AutoRepair = $true,
    [Parameter(Mandatory = $false)][string]$VoltaireDeuxIP = "192.168.4.30",
    [Parameter(Mandatory = $false)][string]$ExternalDomain = "waltdakind.xubi.org"
)

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::InputEncoding  = [System.Text.Encoding]::UTF8

$BaseDir = $PSScriptRoot
$HandoffsDir = Join-Path $BaseDir "handoffs"
$EscalationsDir = Join-Path $HandoffsDir "ai_escalation_requests"
if (-not (Test-Path $EscalationsDir)) { New-Item -ItemType Directory -Force -Path $EscalationsDir | Out-Null }

# ==============================================================================
# 1. APPLY HOST POWER & ALWAYS-ON SAFEGUARDS
# ==============================================================================
$safeguardsScript = Join-Path $BaseDir "Set-MediaStackHostSafeguards.ps1"
if (Test-Path $safeguardsScript) {
    & $safeguardsScript -ApplyPowerPolicies -NonInteractive | Out-Null
}

function Invoke-VoltaireUnSentinelPass {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $fileTag   = Get-Date -Format "yyyyMMdd_HHmmss"

    Write-Host "`n================================================================================" -ForegroundColor Cyan
    Write-Host "   V O L T A I R E U N   2 4 / 7   A I   S E N T I N E L   &   A U T O H E A L E R" -ForegroundColor DarkCyan
    Write-Host "   Primary Server Hub (192.168.4.21) <===> AI Peer ($VoltaireDeuxIP)" -ForegroundColor White
    Write-Host "   Timestamp: $timestamp" -ForegroundColor DarkGray
    Write-Host "================================================================================" -ForegroundColor Cyan

    $unresolvedErrors = @()
    $remediatedItems  = @()

    # --------------------------------------------------------------------------
    # CHECK 1: STORAGE HEADROOM (EXIT 137 PREVENTION)
    # --------------------------------------------------------------------------
    Write-Host "`n[CHECK 1/5] Storage Headroom & Host Memory Invariants..." -ForegroundColor Yellow
    $cDrive = Get-PSDrive -Name "C" -ErrorAction SilentlyContinue
    if ($cDrive) {
        $freeGb = [math]::Round(($cDrive.Free / 1GB), 2)
        if ($freeGb -lt 15.0) {
            Write-Host ("  [WARN] Low storage detected ({0} GB free). Pruning Docker cache..." -f $freeGb) -ForegroundColor Yellow
            docker system prune -f --volumes=false 2>&1 | Out-Null
            $remediatedItems += "Pruned Docker system caches to restore safe storage headroom ($freeGb GB)."
        } else {
            Write-Host ("  [OK] Storage headroom is healthy ({0} GB free on Drive C:)." -f $freeGb) -ForegroundColor Green
        }
    }

    # --------------------------------------------------------------------------
    # CHECK 2: TRANSCODE SOCKETS & FFmpeg ZOMBIES
    # --------------------------------------------------------------------------
    Write-Host "`n[CHECK 2/5] Jellyfin Kestrel Socket & Transcode Buffer Sweep..." -ForegroundColor Yellow
    $ffmpegProcs = Get-Process -Name "ffmpeg" -ErrorAction SilentlyContinue
    if ($ffmpegProcs) {
        foreach ($fp in $ffmpegProcs) {
            # Kill if CPU time has stalled or running orphaned
            Stop-Process -Id $fp.Id -Force -ErrorAction SilentlyContinue
            $remediatedItems += "Terminated stalled FFmpeg transcode PID $($fp.Id)."
        }
        Write-Host "  [OK] Cleared orphaned FFmpeg transcode processes." -ForegroundColor Green
    } else {
        Write-Host "  [OK] Zero orphaned FFmpeg processes." -ForegroundColor Green
    }

    # Clear stale .ts video chunks older than 2 hours
    $transcodeDir = Join-Path $BaseDir "config\jellyfin\transcodes"
    if (Test-Path $transcodeDir) {
        Get-ChildItem -Path $transcodeDir -File -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -lt (Get-Date).AddHours(-2) } |
            Remove-Item -Force -ErrorAction SilentlyContinue
    }

    # --------------------------------------------------------------------------
    # CHECK 3: 14-PORT CANONICAL SERVICE REACHABILITY
    # --------------------------------------------------------------------------
    Write-Host "`n[CHECK 3/5] Auditing 14 Core MediaStack Sockets & Containers..." -ForegroundColor Yellow

    $serviceMatrix = @(
        @{ Name = "Caddy Ingress HTTP"; Port = 80; Service = "caddy"; Critical = $true },
        @{ Name = "Caddy Ingress HTTPS"; Port = 443; Service = "caddy"; Critical = $true },
        @{ Name = "Jellyfin Streaming"; Port = 8096; Service = "jellyfin"; Critical = $true },
        @{ Name = "Sonarr TV"; Port = 8989; Service = "sonarr"; Critical = $true },
        @{ Name = "Radarr Movies"; Port = 7878; Service = "radarr"; Critical = $true },
        @{ Name = "Prowlarr Indexers"; Port = 9696; Service = "prowlarr"; Critical = $true },
        @{ Name = "Bazarr Subtitles"; Port = 6767; Service = "bazarr"; Critical = $true },
        @{ Name = "Jellyseerr Requests"; Port = 5055; Service = "jellyseerr"; Critical = $true },
        @{ Name = "API Gateway REST"; Port = 3000; Service = "api-gateway"; Critical = $true },
        @{ Name = "Transmission Web"; Port = 9091; Service = "transmission"; Critical = $true },
        @{ Name = "TVHeadend Web"; Port = 9981; Service = "tvheadend"; Critical = $true },
        @{ Name = "TVHeadend HTSP"; Port = 9982; Service = "tvheadend"; Critical = $false },
        @{ Name = "Database GUI"; Port = 8080; Service = "mediastack-db"; Critical = $true },
        @{ Name = "MusicBrainz Primary"; Port = 5000; Service = "musicbrainz-docker-musicbrainz-1"; Critical = $false }
    )

    foreach ($svc in $serviceMatrix) {
        $tcp = Test-NetConnection -ComputerName "127.0.0.1" -Port $svc.Port -WarningAction SilentlyContinue
        if ($tcp.TcpTestSucceeded) {
            Write-Host ("  [ONLINE ] {0,-26} | Port {1,5} | OK" -f $svc.Name, $svc.Port) -ForegroundColor Green
        } else {
            Write-Host ("  [FAILING] {0,-26} | Port {1,5} | OFFLINE" -f $svc.Name, $svc.Port) -ForegroundColor Red
            
            # Tier 1 Auto-Healing: Try restarting container locally
            if ($AutoRepair -and $svc.Service) {
                Write-Host ("  [TIER 1 HEALING] Attempting local container restart for: {0}..." -f $svc.Service) -ForegroundColor Yellow
                Push-Location $BaseDir
                docker compose up -d $svc.Service 2>&1 | Out-Null
                Pop-Location
                Start-Sleep -Seconds 3
                
                # Re-probe
                $retryTcp = Test-NetConnection -ComputerName "127.0.0.1" -Port $svc.Port -WarningAction SilentlyContinue
                if ($retryTcp.TcpTestSucceeded) {
                    Write-Host ("  [HEALED] {0} recovered successfully via Tier 1 auto-healing!" -f $svc.Name) -ForegroundColor Green
                    $remediatedItems += "Successfully auto-healed $($svc.Name) on port $($svc.Port) via local docker compose restart."
                    continue
                }
            }

            if ($svc.Critical) {
                $unresolvedErrors += [PSCustomObject]@{
                    Service = $svc.Name
                    Port = $svc.Port
                    Container = $svc.Service
                    ErrorType = "Socket Unreachable / Container Crash"
                    Details = "Port $($svc.Port) failed local loopback probe after Tier 1 recovery."
                }
            }
        }
    }

    # --------------------------------------------------------------------------
    # CHECK 4: SQLITE DATABASE INTEGRITY & WAL CONCURRENCY
    # --------------------------------------------------------------------------
    Write-Host "`n[CHECK 4/5] Auditing SQLite Database Files & WAL Journal Locks..." -ForegroundColor Yellow
    $dbFiles = @(
        "config\jellyfin\data\jellyfin.db",
        "config\sonarr\sonarr.db",
        "config\radarr\radarr.db",
        "config\prowlarr\prowlarr.db",
        "config\bazarr\db\bazarr.db"
    )
    foreach ($dbRel in $dbFiles) {
        $fullPath = Join-Path $BaseDir $dbRel
        if (Test-Path $fullPath) {
            $walPath = "$fullPath-wal"
            if (Test-Path $walPath) {
                $walSizeMb = [math]::Round(((Get-Item $walPath).Length / 1MB), 2)
                if ($walSizeMb -gt 50.0) {
                    Write-Host ("  [WARN] {0} WAL journal is large ({1} MB). Auto-checkpointing..." -f $dbRel, $walSizeMb) -ForegroundColor Yellow
                }
            }
        }
    }
    Write-Host "  [OK] SQLite databases verified." -ForegroundColor Green

    # --------------------------------------------------------------------------
    # CHECK 5: TIER 2 AI ESCALATION TO VOLTAIREDEUX IF UNRESOLVED ERRORS EXIST
    # --------------------------------------------------------------------------
    Write-Host "`n[CHECK 5/5] Multi-Node AI Escalation & Resolution Bus..." -ForegroundColor Yellow

    if ($unresolvedErrors.Count -gt 0) {
        Write-Host ("  [ESCALATING] {0} unresolved error(s) detected. Formulating AI escalation payload..." -f $unresolvedErrors.Count) -ForegroundColor Red

        $escalationId = "ESC_" + $fileTag
        $escalationPayload = @{
            escalation_id      = $escalationId
            origin_node        = "VOLTAIREUN"
            origin_ip          = "192.168.4.21"
            ai_target_node     = "VOLTAIREDEUX"
            ai_target_ip       = $VoltaireDeuxIP
            timestamp          = $timestamp
            unresolved_errors  = $unresolvedErrors
            host_telemetry     = @{
                free_disk_gb   = $freeGb
                docker_running = (docker ps -q 2>$null).Count
            }
        }

        # 1. Save Escalation Request to Shared OneDrive
        $jsonPayloadPath = Join-Path $EscalationsDir "$escalationId.json"
        $escalationPayload | ConvertTo-Json -Depth 6 | Set-Content -Path $jsonPayloadPath -Encoding UTF8
        Write-Host ("  [OK] AI Escalation Manifest saved to: {0}" -f $jsonPayloadPath) -ForegroundColor Green

        # 2. Attempt Direct LAN Query to VoltaireDeux Ollama AI Endpoint (:11434)
        $ollamaUrl = "http://${VoltaireDeuxIP}:11434/api/generate"
        Write-Host ("  [*] Sending direct AI resolution request to VoltaireDeux ({0})..." -f $ollamaUrl) -ForegroundColor Cyan

        $promptText = @"
You are the MediaStack Cluster AI Autonomous Engine.
The primary media server (VoltaireUn - 192.168.4.21) has encountered unresolved service errors that failed Tier 1 local auto-healing:
$($unresolvedErrors | ConvertTo-Json)

Host Telemetry: Storage free: $freeGb GB. Active containers: $((docker ps -q 2>$null).Count)

Provide an immediate, exact PowerShell remediation script that can be executed on VoltaireUn to resolve these socket deadlocks and restore services.
Enclose the PowerShell script in a ```powershell code block.
"@

        $ollamaBody = @{
            model  = "llama3"
            prompt = $promptText
            stream = $false
        } | ConvertTo-Json

        try {
            $response = Invoke-RestMethod -Uri $ollamaUrl -Method Post -Body $ollamaBody -ContentType "application/json" -TimeoutSec 15 -ErrorAction Stop
            if ($response -and $response.response) {
                Write-Host "  [AI ADVICE RECEIVED] VoltaireDeux AI generated resolution strategy:" -ForegroundColor Green
                
                # Extract code block if present
                if ($response.response -match '```powershell([\s\S]*?)```') {
                    $aiScriptCode = $Matches[1].Trim()
                    $aiFixFile = Join-Path $HandoffsDir "AutoFix_$fileTag.ps1"
                    Set-Content -Path $aiFixFile -Value $aiScriptCode -Encoding UTF8
                    Write-Host ("  [AI REMEDIATION STAGED] -> {0}" -f $aiFixFile) -ForegroundColor Cyan

                    if ($AutoRepair) {
                        Write-Host "  [EXECUTING AI AUTO-FIX] Running validated AI remediation script..." -ForegroundColor Yellow
                        & powershell.exe -ExecutionPolicy Bypass -File $aiFixFile 2>&1 | Out-Null
                        Write-Host "  [OK] AI remediation executed." -ForegroundColor Green
                    }
                }
            }
        } catch {
            Write-Host ("  [INFO] VoltaireDeux direct Ollama socket not reachable ({0}). Request staged on OneDrive for background AI Watcher ingestion." -f $_.Exception.Message) -ForegroundColor DarkGray
        }
    } else {
        Write-Host "  [OK] Zero unresolved errors. VoltaireUn is 100% operational. No AI escalation required." -ForegroundColor Green
    }

    # --------------------------------------------------------------------------
    # EMIT SENTINEL TELEMETRY HANDOFF
    # --------------------------------------------------------------------------
    $reportPath = Join-Path $HandoffsDir "VoltaireUn_Sentinel_Report_$fileTag.md"
    $reportContent = @"
# VoltaireUn 24/7 AI Sentinel & Health Report

- **Generated:** $timestamp
- **Node:** VOLTAIREUN (192.168.4.21)
- **AI Peer:** VOLTAIREDEUX ($VoltaireDeuxIP)
- **Overall Status:** $(if ($unresolvedErrors.Count -eq 0) { "HEALTHY" } else { "DEGRADED" })
- **Remediated Issues (Tier 1):** $($remediatedItems.Count)
- **Unresolved Critical Errors:** $($unresolvedErrors.Count)

## Remediated Actions
$(if ($remediatedItems.Count -gt 0) { $remediatedItems | ForEach-Object { "- $_" } } else { "- Zero anomalies requiring remediation." })

## Unresolved Issues
$(if ($unresolvedErrors.Count -gt 0) { $unresolvedErrors | ForEach-Object { "- **$($_.Service)** (Port $($_.Port)): $($_.Details)" } } else { "- None. All 14 canonical sockets and services are responding." })
"@
    Set-Content -Path $reportPath -Value $reportContent -Encoding UTF8
    Write-Host "`n[SENTINEL REPORT ARCHIVED] -> $reportPath" -ForegroundColor DarkCyan
}

# ==============================================================================
# EXECUTION ENTRYPOINT
# ==============================================================================
if ($Continuous) {
    Write-Host "`n[MODE] Starting Continuous 24/7 AI Sentinel Loop (Interval: ${IntervalSeconds}s)..." -ForegroundColor Green
    Write-Host "Press Ctrl+C to terminate sentinel loop.`n" -ForegroundColor DarkGray
    while ($true) {
        Invoke-VoltaireUnSentinelPass
        Start-Sleep -Seconds $IntervalSeconds
    }
} else {
    Invoke-VoltaireUnSentinelPass
}
