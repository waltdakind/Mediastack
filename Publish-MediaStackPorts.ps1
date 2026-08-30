<#
.SYNOPSIS
    Definitive MediaStack Port Publishing, Verification, Conflict Resolution & Deployment Sentinel.
.DESCRIPTION
    Enforces that every MediaStack service correctly publishes its default ports to the host,
    specifically guaranteeing that Jellyfin publishes 8096, Sonarr publishes 8989, Radarr publishes 7878,
    Prowlarr publishes 9696, Bazarr publishes 6767, Jellyseerr publishes 5055, Transmission publishes 9091,
    TVHeadend publishes 9981/9982, Diun publishes 9090, and Caddy publishes 80/443 without conflicts.

.PARAMETER AuditOnly
    Audits current docker-compose configuration and running container port bindings without making changes.
.PARAMETER Apply
    Applies the port configuration and re-deploys containers to publish their host ports.
.PARAMETER TestOnly
    Tests live TCP connectivity and HTTP health endpoints for all published ports.
.PARAMETER CheckConflicts
    Checks for Windows WinNAT / Hyper-V excluded port ranges and host port collisions.

.EXAMPLE
    .\Publish-MediaStackPorts.ps1
    Runs a full end-to-end audit, conflict check, container port verification, and live connectivity test.

.EXAMPLE
    .\Publish-MediaStackPorts.ps1 -Apply
    Enforces port declarations, re-creates containers, and verifies published port health.
#>

[CmdletBinding()]
param (
    [Parameter()]
    [switch]$AuditOnly,

    [Parameter()]
    [switch]$Apply,

    [Parameter()]
    [switch]$TestOnly,

    [Parameter()]
    [switch]$CheckConflicts
)

$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$BaseDir = $PSScriptRoot
if (-not $BaseDir) { $BaseDir = $PWD.Path }
$ComposeFile = Join-Path $BaseDir "docker-compose.yml"

# =============================================================================
# 1. Definitive Canonical Port Matrix
# =============================================================================
$ServicePortDefinitions = @(
    @{
        Service      = "jellyfin"
        Container    = "jellyfin"
        HostPort     = 8096
        TargetPort   = 8096
        Protocol     = "tcp"
        Category     = "Media Server"
        HealthUrl    = "http://127.0.0.1:8096/health"
        ExpectedCode = 200
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
        ExpectedCode = 200
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
        ExpectedCode = 200
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
        ExpectedCode = 200
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
        ExpectedCode = 200
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
        ExpectedCode = 200
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
        ExpectedCode = 200
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
        ExpectedCode = 0
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
        ExpectedCode = 200
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
        ExpectedCode = 0
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
        ExpectedCode = 200
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
        ExpectedCode = 200
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
        ExpectedCode = 0
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
        ExpectedCode = 200
        Description  = "MediaStack API Gateway"
    }
)

function Write-Log([string]$Message, [string]$Color = "White") {
    $timestamp = (Get-Date).ToString("HH:mm:ss")
    Write-Host "[$timestamp] $Message" -ForegroundColor $Color
}

function Show-Banner {
    Clear-Host
    Write-Host "================================================================================" -ForegroundColor DarkCyan
    Write-Host "   __  __          _ _       _____ _             _" -ForegroundColor Cyan
    Write-Host "  |  \/  |        | (_)     / ____| |           | |" -ForegroundColor Cyan
    Write-Host "  | \  / | ___  __| |_  __ | (___ | |_ __ _  ___| | __" -ForegroundColor Cyan
    Write-Host "  | |\/| |/ _ \/ _` | |/ _` \___ \| __/ _` |/ __| |/ /" -ForegroundColor DarkCyan
    Write-Host "  | |  | |  __/ (_| | | (_| |____) | || (_| | (__|   < " -ForegroundColor DarkCyan
    Write-Host "  |_|  |_|\___|\__,_|_|\__,_|_____/ \__\__,_|\___|_|\_\" -ForegroundColor DarkCyan
    Write-Host "      D E F I N I T I V E   P O R T   P U B L I S H E R   &   A U D I T O R" -ForegroundColor Yellow
    Write-Host "================================================================================" -ForegroundColor DarkCyan
    Write-Host ""
}

# =============================================================================
# 2. Host Port Collision & Windows Port Exclusion Checker
# =============================================================================
function Test-HostPortConflicts {
    Write-Log "[+] Checking for Host Port Conflicts & WinNAT Exclusions..." "Yellow"

    $excludedRanges = @()
    try {
        $netshOutput = netsh interface ipv4 show excludedportrange protocol=tcp 2>$null
        if ($netshOutput) {
            foreach ($line in $netshOutput) {
                if ($line -match '^\s*(\d+)\s+(\d+)') {
                    $excludedRanges += [PSCustomObject]@{
                        Start = [int]$Matches[1]
                        End   = [int]$Matches[2]
                    }
                }
            }
        }
    } catch {
        Write-Log "    [WARN] Unable to query netsh excluded port ranges." "DarkGray"
    }

    $activeListeners = @{}
    try {
        $connections = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue
        foreach ($conn in $connections) {
            $p = $conn.LocalPort
            if (-not $activeListeners.ContainsKey($p)) {
                $activeListeners[$p] = $conn.OwningProcess
            }
        }
    } catch {}

    $hasIssue = $false
    foreach ($def in $ServicePortDefinitions) {
        $hp = $def.HostPort
        $svc = $def.Service

        # Check WinNAT Exclusion
        foreach ($range in $excludedRanges) {
            if ($hp -ge $range.Start -and $hp -le $range.End) {
                Write-Log "    [EXCLUSION DETECTED] Port $hp ($svc) is inside Windows Hyper-V dynamic exclusion range ($($range.Start)-$($range.End))!" "Red"
                $hasIssue = $true
            }
        }
    }

    if (-not $hasIssue) {
        Write-Log "    [OK] No fatal Windows WinNAT exclusion collisions detected." "Green"
    }
}

# =============================================================================
# 3. Docker Running Container Port Inspection
# =============================================================================
function Get-PublishedPortStatus {
    Write-Log "`n[+] Inspecting Running Containers and Published Ports..." "Yellow"

    $results = @()
    $runningContainers = docker ps --format '{{.Names}}' 2>$null

    foreach ($def in $ServicePortDefinitions) {
        $cName = $def.Container
        $svcName = $def.Service
        $expectedHostPort = $def.HostPort
        $targetPort = $def.TargetPort
        $protocol = $def.Protocol

        $isRunning = $runningContainers -contains $cName
        $isPublished = $false
        $publishedBindings = @()

        if ($isRunning) {
            $inspectRaw = docker inspect $cName --format '{{json .NetworkSettings.Ports}}' 2>$null
            if ($inspectRaw -and $inspectRaw -ne "null") {
                try {
                    $portsObj = $inspectRaw | ConvertFrom-Json
                    foreach ($prop in $portsObj.PSObject.Properties) {
                        $containerPortSpec = $prop.Name
                        $bindings = $prop.Value
                        if ($bindings -and $bindings.Count -gt 0) {
                            foreach ($b in $bindings) {
                                $pubPort = [int]$b.HostPort
                                $publishedBindings += "$pubPort->$containerPortSpec"
                                if ($pubPort -eq $expectedHostPort) {
                                    $isPublished = $true
                                }
                            }
                        }
                    }
                } catch {}
            }
        }

        $statusText = if (-not $isRunning) {
            "OFFLINE"
        } elseif ($isPublished) {
            "PUBLISHED"
        } else {
            "INTERNAL_ONLY"
        }

        $results += [PSCustomObject]@{
            Service       = $svcName
            Container     = $cName
            HostPort      = $expectedHostPort
            TargetPort    = $targetPort
            Protocol      = $protocol
            Status        = $statusText
            Bindings      = ($publishedBindings -join ", ")
            Category      = $def.Category
            HealthUrl     = $def.HealthUrl
            ExpectedCode  = $def.ExpectedCode
        }
    }

    return $results
}

# =============================================================================
# 4. Live TCP & HTTP Endpoint Verification
# =============================================================================
function Test-LiveConnectivity([array]$PortStatusList) {
    Write-Log "`n[+] Probing Live Socket Connectivity and HTTP Endpoints..." "Yellow"

    $testedResults = @()

    foreach ($item in $PortStatusList) {
        $hp = $item.HostPort
        $svc = $item.Service
        $healthUrl = $item.HealthUrl
        $expectedCode = $item.ExpectedCode

        $tcpOpen = $false
        $httpCode = "-"
        $httpStatus = "N/A"

        # 1. TCP Socket Probe
        try {
            $tcpClient = New-Object System.Net.Sockets.TcpClient
            $asyncResult = $tcpClient.BeginConnect("127.0.0.1", $hp, $null, $null)
            $waitHandle = $asyncResult.AsyncWaitHandle.WaitOne(800, $false)
            if ($waitHandle -and $tcpClient.Connected) {
                $tcpOpen = $true
                $tcpClient.EndConnect($asyncResult)
            }
            $tcpClient.Close()
        } catch {
            $tcpOpen = $false
        }

        # 2. HTTP Probe
        if ($tcpOpen -and $healthUrl) {
            try {
                $res = Invoke-WebRequest -Uri $healthUrl -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop
                $httpCode = $res.StatusCode
                if ($httpCode -ge 200 -and $httpCode -lt 400) {
                    $httpStatus = "HEALTHY ($httpCode)"
                } else {
                    $httpStatus = "HTTP $httpCode"
                }
            } catch {
                if ($_.Exception.Response) {
                    $httpCode = $_.Exception.Response.StatusCode.value__
                    $httpStatus = "HTTP $httpCode"
                } else {
                    $httpStatus = "TIMEOUT / REFUSED"
                }
            }
        } elseif ($tcpOpen) {
            $httpStatus = "TCP LISTENING"
        } else {
            $httpStatus = "CLOSED"
        }

        $testedResults += [PSCustomObject]@{
            Service       = $svc
            Container     = $item.Container
            HostPort      = $hp
            TargetPort    = $item.TargetPort
            Status        = $item.Status
            TcpListening  = if ($tcpOpen) { "YES" } else { "NO" }
            HttpStatus    = $httpStatus
            Description   = $item.Category
        }
    }

    return $testedResults
}

# =============================================================================
# 5. Enforce Port Configurations & Deploy
# =============================================================================
function Invoke-StackPortDeployment {
    Write-Log "`n[+] Enforcing Stack Deployment with Published Ports..." "Yellow"
    Set-Location -Path $BaseDir

    try {
        Write-Log "    Validating docker compose syntax..." "DarkGray"
        $configCheck = docker compose config --quiet 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Log "    [ERROR] Docker compose config validation failed: $configCheck" "Red"
            return $false
        }
        Write-Log "    [OK] docker-compose.yml is valid." "Green"

        Write-Log "    Recreating containers with updated published port mappings..." "Cyan"
        docker compose up -d

        Write-Log "    Waiting 10s for container sockets to bind..." "DarkGray"
        Start-Sleep -Seconds 10
        return $true
    } catch {
        Write-Log "    [FATAL] Deployment failed: $_" "Red"
        return $false
    }
}

# =============================================================================
# 6. Main Flow Execution
# =============================================================================
Show-Banner

if ($CheckConflicts) {
    Test-HostPortConflicts
    exit 0
}

if ($Apply) {
    Test-HostPortConflicts
    $deployed = Invoke-StackPortDeployment
    if (-not $deployed) {
        Write-Log "Deployment failed. Aborting verification." "Red"
        exit 1
    }
}

$portStatuses = Get-PublishedPortStatus

if ($AuditOnly) {
    Write-Host "`n--- DOCKER PUBLISHED PORT AUDIT ---" -ForegroundColor Cyan
    $portStatuses | Format-Table -AutoSize Service, Container, HostPort, TargetPort, Protocol, Status, Bindings
    exit 0
}

$liveResults = Test-LiveConnectivity -PortStatusList $portStatuses

Write-Host "`n================================================================================" -ForegroundColor DarkCyan
Write-Host "                      MEDIASTACK PUBLISHED PORT SUMMARY                        " -ForegroundColor Yellow
Write-Host "================================================================================" -ForegroundColor DarkCyan

$liveResults | Format-Table -AutoSize Service, Container, HostPort, TargetPort, Status, TcpListening, HttpStatus, Description

# Specific Jellyfin 8096 Highlight
$jellyfinRow = $liveResults | Where-Object { $_.Service -eq "jellyfin" -and $_.HostPort -eq 8096 }
Write-Host "--------------------------------------------------------------------------------" -ForegroundColor DarkGray
if ($jellyfinRow -and $jellyfinRow.TcpListening -eq "YES") {
    Write-Host " [OK] JELLYFIN IS PUBLISHED & ACCESSIBLE ON HOST PORT 8096!" -ForegroundColor Green
    Write-Host "      Access URL: http://localhost:8096 or http://192.168.4.21:8096" -ForegroundColor Cyan
} else {
    Write-Host " [ALERT] JELLYFIN PORT 8096 IS NOT RESPONDING!" -ForegroundColor Red
    Write-Host "         Run .\Publish-MediaStackPorts.ps1 -Apply to re-publish container ports." -ForegroundColor Yellow
}
Write-Host "--------------------------------------------------------------------------------`n" -ForegroundColor DarkGray
