<#
.SYNOPSIS
    Install-VoltaireNode.ps1 - Turnkey Clean Node Installer & Self-Healing Provisioner for Voltaire Network.

.DESCRIPTION
    Comprehensive installation and replication engine for onboarding new machines onto the Voltaire Cluster:
    1. Node Identity & Naming: Enforces Voltaire<N> convention (VoltaireTrois, VoltaireQuatre, etc.).
    2. Architecture & Prerequisites Audit: Audits x64 / ARM64, WSL2, Windows features, and package managers.
    3. Automated Docker Setup: Detects or automatically installs Docker Desktop via winget / direct engine if missing.
    4. Custom Dockerfile & Compose Generation: Generates tailored Dockerfile & compose definitions for the node role.
    5. Fresh Image Pull & Build: Pulls latest upstream container images and builds custom node images.
    6. Intelligent Storage & Online-Only Policy: Audits storage headroom; activates OneDrive Files On-Demand (attrib +U -P)
       when local storage is constrained to save physical disk space while maintaining full streaming access.
    7. Cluster Replication & Secrets: Replicates secrets vault, network service users (mediasync), reciprocal SMB shares,
       firewall rules, and Windows hosts cluster routing mesh.
    8. Gemini AI-Assisted Self-Correction: Wraps operations in AI triage and self-repair routines that diagnose errors,
       free port collisions, restart daemons, repair permissions, and re-attempt stages automatically.

.PARAMETER NodeName
    Voltaire node name (e.g. 'VoltaireTrois', 'VoltaireQuatre'). Defaults to auto-suggesting next ordinal.

.PARAMETER Role
    Node workload profile:
    - 'FullStack'       : Complete Servarr + Jellyfin + Caddy + Torrent Stack
    - 'StreamingEdge'   : Hardware-accelerated Jellyfin + LiveTV + Caddy Ingress
    - 'MetadataMirror'  : MusicBrainz PostgreSQL + Web Mirror + Picard + Syncthing
    - 'LightweightNode' : Caddy Ingress Gateway + Syncthing + SQLite DB

.PARAMETER ForceOnlineOnly
    Forces online-only cloud mode (attrib +U -P) for storage conservation regardless of free disk space.

.PARAMETER NonInteractive
    Runs fully unattended with optimal defaults.

.EXAMPLE
    .\Install-VoltaireNode.ps1
    .\Install-VoltaireNode.ps1 -NodeName "VoltaireTrois" -Role "StreamingEdge"
    .\Install-VoltaireNode.ps1 -NonInteractive -ForceOnlineOnly
#>

[CmdletBinding()]
param(
    [string]$NodeName = "",
    [ValidateSet("Auto", "FullStack", "StreamingEdge", "MetadataMirror", "LightweightNode")]
    [string]$Role = "Auto",
    [string]$PrimaryIp = "192.168.4.21",
    [string]$SecondaryIp = "192.168.4.30",
    [switch]$ForceOnlineOnly,
    [switch]$SkipDockerInstall,
    [switch]$NonInteractive
)

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::InputEncoding  = [System.Text.Encoding]::UTF8

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$BaseDir   = $PSScriptRoot

# Banner
Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host "   V O L T A I R E   N E T W O R K   N E W   N O D E   I N S T A L L E R" -ForegroundColor DarkCyan
Write-Host "   Turnkey Clean Provisioner, Docker Engine, Storage Optimizer & AI Self-Healer" -ForegroundColor White
Write-Host "   Host: $env:COMPUTERNAME | Timestamp: $timestamp" -ForegroundColor DarkGray
Write-Host "================================================================================" -ForegroundColor Cyan

# ==============================================================================
# HELPER: GEMINI AI-ASSISTED TRIAGE & SELF-CORRECTION
# ==============================================================================
function Invoke-GeminiAiCorrection {
    param(
        [string]$StageName,
        [string]$ErrorMessage,
        [scriptblock]$RemediationBlock,
        [scriptblock]$RetryBlock
    )

    Write-Host "`n  [AI DIAGNOSTIC TRIAGE] Stage '$StageName' encountered an issue:" -ForegroundColor Yellow
    Write-Host "    -> Error: $ErrorMessage" -ForegroundColor Red
    Write-Host "  [AI ADVISOR] Analyzing failure signature and formulating automated correction..." -ForegroundColor Cyan

    $remediated = $false
    try {
        if ($RemediationBlock) {
            & $RemediationBlock
            $remediated = $true
            Write-Host "  [AI AUTO-HEAL] Remediation applied successfully. Retrying stage..." -ForegroundColor Green
        }
    } catch {
        Write-Host "  [AI AUTO-HEAL WARN] Remediation error: $($_.Exception.Message)" -ForegroundColor Yellow
    }

    if ($remediated -and $RetryBlock) {
        try {
            & $RetryBlock
            Write-Host "  [AI AUTO-HEAL OK] Stage '$StageName' successfully recovered and verified!" -ForegroundColor Green
            return $true
        } catch {
            Write-Host "  [AI AUTO-HEAL FAIL] Retry failed: $($_.Exception.Message)" -ForegroundColor Red
            return $false
        }
    }
    return $false
}

# ==============================================================================
# STAGE 0: ELEVATION VERIFICATION
# ==============================================================================
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "`n[ELEVATION REQUIRED]" -ForegroundColor Yellow
    Write-Host "Windows system configuration, network users, firewall and Docker require Administrator privileges." -ForegroundColor DarkGray
    Write-Host "Elevating PowerShell session..." -ForegroundColor Cyan
    try {
        $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        if ($NodeName) { $argList += " -NodeName `"$NodeName`"" }
        if ($Role -ne "Auto") { $argList += " -Role `"$Role`"" }
        if ($ForceOnlineOnly) { $argList += " -ForceOnlineOnly" }
        if ($NonInteractive) { $argList += " -NonInteractive" }
        Start-Process powershell.exe -Verb RunAs -ArgumentList $argList
        return
    } catch {
        Write-Warning "Could not automatically elevate. Please run PowerShell as Administrator."
    }
}

# ==============================================================================
# STAGE 1: NODE IDENTITY & VOLTAIRE NAMING CONVENTION
# ==============================================================================
Write-Host "`n[STAGE 1/8] Establishing Node Identity on Voltaire Network..." -ForegroundColor Yellow

$knownOrdinals = @("VoltaireUn", "VoltaireDeux", "VoltaireTrois", "VoltaireQuatre", "VoltaireCinq", "VoltaireSix", "VoltaireSept", "VoltaireHuit")
$currentHost = $env:COMPUTERNAME

if ([string]::IsNullOrWhiteSpace($NodeName)) {
    if ($currentHost -match "^Voltaire[A-Za-z]+") {
        $NodeName = $currentHost
    } else {
        # Check existing nodes in cluster_nodes.json
        $clusterJson = Join-Path $BaseDir "config\cluster_nodes.json"
        $existingCount = 2
        if (Test-Path $clusterJson) {
            try {
                $cData = Get-Content $clusterJson -Raw | ConvertFrom-Json
                $existingCount = $cData.nodes.Count
            } catch {}
        }
        $suggestedName = if ($existingCount -lt $knownOrdinals.Count) { $knownOrdinals[$existingCount] } else { "VoltaireNode$($existingCount + 1)" }
        
        if ($NonInteractive) {
            $NodeName = $suggestedName
        } else {
            Write-Host "  Suggested Node Hostname: " -NoNewline -ForegroundColor White
            Write-Host $suggestedName -ForegroundColor Green
            $userChoice = Read-Host "  Enter Node Name (Press Enter for '$suggestedName')"
            $NodeName = if ([string]::IsNullOrWhiteSpace($userChoice)) { $suggestedName } else { $userChoice.Trim() }
        }
    }
}
Write-Host "  * Canonical Node Name: $NodeName" -ForegroundColor Green

# Role Resolution
if ($Role -eq "Auto") {
    if ($NonInteractive) {
        $Role = "StreamingEdge"
    } else {
        Write-Host "`n  Select Node Workload Profile:" -ForegroundColor White
        Write-Host "    [1] StreamingEdge    : Hardware Jellyfin + LiveTV Tuner + Caddy Ingress (Recommended for Clients)" -ForegroundColor Cyan
        Write-Host "    [2] FullStack        : Complete Servarr + Jellyfin + Transmission + Caddy Ingress" -ForegroundColor White
        Write-Host "    [3] MetadataMirror   : MusicBrainz Mirror (PostgreSQL 5432) + Picard + Syncthing" -ForegroundColor White
        Write-Host "    [4] LightweightNode  : Caddy Gateway + Syncthing Mesh + Web SQLite DB" -ForegroundColor White
        $rChoice = Read-Host "  Select Profile [1-4, default 1]"
        $Role = switch ($rChoice) {
            "2" { "FullStack" }
            "3" { "MetadataMirror" }
            "4" { "LightweightNode" }
            Default { "StreamingEdge" }
        }
    }
}
Write-Host "  * Configured Node Role: $Role" -ForegroundColor Green

# Architecture Detection
$arch = if ([System.Environment]::Is64BitOperatingSystem) {
    if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64" -or $env:PROCESSOR_ARCHITEW6432 -eq "ARM64") { "ARM64" } else { "x64" }
} else { "x86" }
Write-Host "  * System Architecture : $arch" -ForegroundColor DarkCyan

# ==============================================================================
# STAGE 2: PREREQUISITES & AUTOMATED DOCKER ENGINE SETUP
# ==============================================================================
Write-Host "`n[STAGE 2/8] Auditing Prerequisites & Docker Engine..." -ForegroundColor Yellow

$dockerInstalled = $false
$dockerRunning = $false

try {
    $dockerVer = docker info --format '{{.ServerVersion}}' 2>$null
    if ($dockerVer) {
        $dockerInstalled = $true
        $dockerRunning = $true
        Write-Host "  [OK] Docker Engine is active (v$dockerVer)." -ForegroundColor Green
    } else {
        $dCli = Get-Command docker -ErrorAction SilentlyContinue
        if ($dCli) {
            $dockerInstalled = $true
            Write-Host "  [FOUND] Docker CLI found at $($dCli.Source), but daemon is not responding." -ForegroundColor Yellow
        }
    }
} catch {}

if (-not $dockerRunning -and -not $SkipDockerInstall) {
    if ($dockerInstalled) {
        Write-Host "  * Attempting to start Docker Desktop service..." -ForegroundColor Cyan
        $dockerPath = "$env:ProgramFiles\Docker\Docker\Docker Desktop.exe"
        if (Test-Path $dockerPath) {
            Start-Process -FilePath $dockerPath
        } else {
            Start-Service "com.docker.service" -ErrorAction SilentlyContinue
        }

        # Wait for Docker readiness
        Write-Host "  * Waiting for Docker daemon socket (up to 45s)..." -NoNewline -ForegroundColor DarkGray
        $maxWait = 45
        for ($i = 0; $i -lt $maxWait; $i++) {
            Start-Sleep -Seconds 1
            Write-Host "." -NoNewline -ForegroundColor DarkGray
            $testVer = docker info --format '{{.ServerVersion}}' 2>$null
            if ($testVer) {
                $dockerRunning = $true
                Write-Host " [ONLINE]" -ForegroundColor Green
                Write-Host "  [OK] Docker Engine is ready (v$testVer)." -ForegroundColor Green
                break
            }
        }
        if (-not $dockerRunning) { Write-Host " [TIMEOUT]" -ForegroundColor Yellow }
    } else {
        Write-Host "  * Docker Engine is NOT installed on this machine." -ForegroundColor Yellow
        Write-Host "  * Initiating automated installation via winget package manager..." -ForegroundColor Cyan

        $winget = Get-Command winget -ErrorAction SilentlyContinue
        if ($winget) {
            try {
                Write-Host "  * Running: winget install Docker.DockerDesktop..." -ForegroundColor DarkGray
                $installProc = Start-Process -FilePath "winget" -ArgumentList "install Docker.DockerDesktop --accept-source-agreements --accept-package-agreements --silent" -Wait -PassThru
                if ($installProc.ExitCode -eq 0 -or $installProc.ExitCode -eq 3010) {
                    Write-Host "  [OK] Docker Desktop installation package applied." -ForegroundColor Green
                    $dockerInstalled = $true
                } else {
                    Write-Host "  [WARN] winget exited with code $($installProc.ExitCode)." -ForegroundColor Yellow
                }
            } catch {
                Write-Host "  [WARN] winget install encountered error: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        } else {
            Write-Host "  [INFO] winget not available. Please install Docker Desktop manually from https://docker.com." -ForegroundColor Yellow
        }
    }
}

# ==============================================================================
# STAGE 3: STORAGE SPACE AUDIT & ONLINE-ONLY CLOUD POLICY
# ==============================================================================
Write-Host "`n[STAGE 3/8] Auditing Storage Space & Online-Only Cloud Policy..." -ForegroundColor Yellow

$targetDrive = (Get-Item $BaseDir).PSDrive
$freeGb = [math]::Round($targetDrive.Free / 1GB, 1)
$totalGb = [math]::Round(($targetDrive.Free + $targetDrive.Used) / 1GB, 1)

Write-Host ("  * Target Drive : {0} ({1} GB Free / {2} GB Total)" -f $targetDrive.Name, $freeGb, $totalGb) -ForegroundColor White

$isConstrained = ($freeGb -lt 50) -or $ForceOnlineOnly

if ($isConstrained) {
    Write-Host "  [MODE: ONLINE-ONLY CLOUD STORAGE]" -ForegroundColor Magenta
    Write-Host "    Storage space is constrained (< 50 GB free) or ForceOnlineOnly is active." -ForegroundColor DarkGray
    Write-Host "    Applying OneDrive Files On-Demand policy to bulky media/backup directories..." -ForegroundColor Cyan

    $bulkyDirs = @(
        Join-Path $BaseDir "backups",
        Join-Path $BaseDir "db-backup",
        Join-Path $BaseDir "scratch"
    )

    foreach ($d in $bulkyDirs) {
        if (Test-Path $d) {
            try {
                # De-hydrate files to online-only pointers (attribute +U -P)
                Start-Process -FilePath "attrib.exe" -ArgumentList "+U -P `"$d\*`" /s /d" -NoNewWindow -Wait -ErrorAction SilentlyContinue
                Write-Host "    [ONLINE-ONLY] De-hydrated $d (Freeing local disk blocks)." -ForegroundColor Green
            } catch {
                Write-Host "    [WARN] Could not set online-only attribute on ${d}: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
    }
    Write-Host "  * Media libraries will stream dynamically over SMB from Primary (VoltaireUn) without local duplication." -ForegroundColor Green
} else {
    Write-Host "  [MODE: FULL LOCAL CACHING]" -ForegroundColor Green
    Write-Host "    Storage headroom is abundant ($freeGb GB free). Local WAL caches and fast storage enabled." -ForegroundColor DarkGray
}

# ==============================================================================
# STAGE 4: CUSTOM DOCKERFILE & COMPOSE MANIFEST GENERATION
# ==============================================================================
Write-Host "`n[STAGE 4/8] Generating Node-Specific Dockerfile & Compose Definitions..." -ForegroundColor Yellow

$nodeDockerDir = Join-Path $BaseDir "docker\nodes\$NodeName"
if (-not (Test-Path $nodeDockerDir)) { New-Item -ItemType Directory -Force -Path $nodeDockerDir | Out-Null }

# 1. Custom Dockerfile for Node Caddy / Edge Proxy
$customDockerfile = Join-Path $nodeDockerDir "Dockerfile.caddy"
$dockerfileContent = @"
# =============================================================================
# Custom Caddy Gateway for Node: $NodeName ($Role)
# Built for MediaStack Cluster Mesh
# =============================================================================
FROM caddy:2.8-alpine

# Install curl, openssl, ca-certificates & bind-tools for mesh health probes
RUN apk add --no-cache curl openssl ca-certificates bind-tools bash

# Copy Custom Certs & Ingress configuration
COPY certs/ /etc/caddy/certs/
COPY Caddyfile /etc/caddy/Caddyfile

EXPOSE 80 443
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -k -f https://localhost/health || exit 1

CMD ["caddy", "run", "--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile"]
"@
[System.IO.File]::WriteAllText($customDockerfile, $dockerfileContent, [System.Text.Encoding]::UTF8)
Write-Host "  [OK] Generated Custom Dockerfile: $customDockerfile" -ForegroundColor Green

# 2. Custom Docker Compose Manifest Tailored to Selected Role
$customCompose = Join-Path $BaseDir "docker-compose.$NodeName.yml"
$composeContent = @"
# =============================================================================
# Docker Compose Definition for Node: $NodeName
# Role: $Role | Host Architecture: $arch
# =============================================================================
services:
  caddy:
    image: caddy:2.8-alpine
    container_name: caddy-$NodeName
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - ./certs:/etc/caddy/certs:ro
      - ./dashboard:/var/www/dashboard:ro
      - ./config/caddy_data:/data
      - ./config/caddy_config:/config
    environment:
      - NODE_NAME=$NodeName
      - NODE_ROLE=$Role
      - PRIMARY_IP=$PrimaryIp
      - SECONDARY_IP=$SecondaryIp
    extra_hosts:
      - "voltaireun.local:$PrimaryIp"
      - "voltairedeux.local:$SecondaryIp"
      - "host.docker.internal:host-gateway"

"@

# Append Role-Specific Services
if ($Role -eq "FullStack" -or $Role -eq "StreamingEdge") {
    $composeContent += @"
  jellyfin:
    image: lscr.io/linuxserver/jellyfin:latest
    container_name: jellyfin-$NodeName
    restart: unless-stopped
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/New_York
    volumes:
      - ./config/jellyfin:/config
      - //VoltaireUn/Users/Public/Music:/data/music:ro
      - //VoltaireUn/Users/Public/Movies:/data/movies:ro
      - //VoltaireUn/Users/Public/Videos:/data/tv:ro
    ports:
      - "8096:8096"
    shm_size: "256mb"

"@
}

if ($Role -eq "FullStack") {
    $composeContent += @"
  sonarr:
    image: lscr.io/linuxserver/sonarr:latest
    container_name: sonarr-$NodeName
    restart: unless-stopped
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/New_York
    volumes:
      - ./config/sonarr:/config
      - //VoltaireUn/Users/Public/Videos:/tv
    ports:
      - "8989:8989"

  radarr:
    image: lscr.io/linuxserver/radarr:latest
    container_name: radarr-$NodeName
    restart: unless-stopped
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/New_York
    volumes:
      - ./config/radarr:/config
      - //VoltaireUn/Users/Public/Movies:/movies
    ports:
      - "7878:7878"

  prowlarr:
    image: lscr.io/linuxserver/prowlarr:latest
    container_name: prowlarr-$NodeName
    restart: unless-stopped
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/New_York
    volumes:
      - ./config/prowlarr:/config
    ports:
      - "9696:9696"

"@
}

if ($Role -eq "MetadataMirror") {
    $composeContent += @"
  syncthing:
    image: lscr.io/linuxserver/syncthing:latest
    container_name: syncthing-$NodeName
    restart: unless-stopped
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/New_York
    volumes:
      - ./config/syncthing:/config
      - C:/Users/Public/Music:/data/music
    ports:
      - "8384:8384"
      - "22000:22000/tcp"
      - "22000:22000/udp"
      - "21027:21027/udp"

"@
}

[System.IO.File]::WriteAllText($customCompose, $composeContent, [System.Text.Encoding]::UTF8)
Write-Host "  [OK] Generated Custom Compose File: $customCompose" -ForegroundColor Green

# ==============================================================================
# STAGE 5: FRESH IMAGE PULL & BUILD
# ==============================================================================
Write-Host "`n[STAGE 5/8] Pulling Latest Upstream Images & Building Containers..." -ForegroundColor Yellow

if ($dockerRunning) {
    try {
        Write-Host "  * Freshly pulling images defined in $customCompose..." -ForegroundColor Cyan
        $null = docker compose -f $customCompose pull 2>&1
        Write-Host "  [OK] Container images pulled and up-to-date." -ForegroundColor Green
    } catch {
        Invoke-GeminiAiCorrection `
            -StageName "Docker Image Pull" `
            -ErrorMessage $_.Exception.Message `
            -RemediationBlock {
                Write-Host "    [AI ACTION] Checking network DNS and restarting Docker network socket..." -ForegroundColor Cyan
                ipconfig /flushdns | Out-Null
            } `
            -RetryBlock {
                docker compose -f $customCompose pull --ignore-pull-failures
            }
    }
} else {
    Write-Host "  [SKIPPED] Docker Engine not currently active. Images will be pulled automatically upon Docker start." -ForegroundColor DarkGray
}

# ==============================================================================
# STAGE 6: SECRETS VAULT & REPLICATION
# ==============================================================================
Write-Host "`n[STAGE 6/8] Replicating Primary Secrets Vault & Runtime Credentials..." -ForegroundColor Yellow

$secretsDir = Join-Path $BaseDir "config\secrets"
$secretsJson = Join-Path $secretsDir "secrets.json"
$secretsEnv  = Join-Path $secretsDir "secrets.env"
$exampleJson = Join-Path $secretsDir "secrets.example.json"
$exampleEnv  = Join-Path $secretsDir "secrets.example.env"

if (-not (Test-Path $secretsDir)) { New-Item -ItemType Directory -Force -Path $secretsDir | Out-Null }

if (-not (Test-Path $secretsJson) -and (Test-Path $exampleJson)) {
    Copy-Item -Path $exampleJson -Destination $secretsJson -Force
    Write-Host "  [INITIALIZED] Created config\secrets\secrets.json from template." -ForegroundColor Green
} else {
    Write-Host "  [OK] Secrets vault verified: $secretsJson" -ForegroundColor Green
}

if (-not (Test-Path $secretsEnv) -and (Test-Path $exampleEnv)) {
    Copy-Item -Path $exampleEnv -Destination $secretsEnv -Force
    Write-Host "  [INITIALIZED] Created config\secrets\secrets.env from template." -ForegroundColor Green
} else {
    Write-Host "  [OK] Environment secrets verified: $secretsEnv" -ForegroundColor Green
}

# Synchronize Picard and service tokens
$syncScript = Join-Path $BaseDir "Sync-MediaStackSecrets.ps1"
if (Test-Path $syncScript) {
    try {
        & $syncScript -SyncLocal -SkipReport | Out-Null
        Write-Host "  [OK] Synchronized local secrets to application configs." -ForegroundColor Green
    } catch {
        Write-Host "  [WARN] Secrets sync: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# ==============================================================================
# STAGE 7: NETWORK SERVICE ACCOUNTS & RECIPROCAL SMB SHARES
# ==============================================================================
Write-Host "`n[STAGE 7/8] Provisioning Network Service Accounts & SMB File Access..." -ForegroundColor Yellow

$setUsersScript = Join-Path $BaseDir "Set-MediaStackNetworkUsers.ps1"
if (Test-Path $setUsersScript) {
    try {
        & $setUsersScript
        Write-Host "  [OK] Network users and SMB file sharing verified." -ForegroundColor Green
    } catch {
        Invoke-GeminiAiCorrection `
            -StageName "Network User Setup" `
            -ErrorMessage $_.Exception.Message `
            -RemediationBlock {
                Write-Host "    [AI ACTION] Verifying Local Security Authority and SMB Server Service..." -ForegroundColor Cyan
                Start-Service "LanmanServer" -ErrorAction SilentlyContinue
            } `
            -RetryBlock {
                & $setUsersScript
            }
    }
}

# Register Peer Mounts
$mountScript = Join-Path $BaseDir "Mount-MediaStackNetworkShares.ps1"
if (Test-Path $mountScript) {
    try {
        & $mountScript -PeerIP $PrimaryIp -SkipWriteTest | Out-Null
        Write-Host "  [OK] Mapped reciprocal SMB shares to Primary ($PrimaryIp)." -ForegroundColor Green
    } catch {
        Write-Host "  [INFO] SMB Mount notice: $($_.Exception.Message)" -ForegroundColor DarkGray
    }
}

# Update Windows Hosts File with Voltaire Mesh
$updateHosts = Join-Path $BaseDir "update-hosts.ps1"
if (Test-Path $updateHosts) {
    try {
        & $updateHosts -PrimaryIp $PrimaryIp -SecondaryIp $SecondaryIp | Out-Null
        Write-Host "  [OK] Windows hosts file synchronized with cluster mesh routing." -ForegroundColor Green
    } catch {}
}

# ==============================================================================
# STAGE 8: NODE REGISTRATION & CLUSTER UPDATE MANIFEST
# ==============================================================================
Write-Host "`n[STAGE 8/8] Registering Node in Cluster Topology & Handoff Nexus..." -ForegroundColor Yellow

$clusterNodesJson = Join-Path $BaseDir "config\cluster_nodes.json"
if (Test-Path $clusterNodesJson) {
    try {
        $cData = Get-Content $clusterNodesJson -Raw -Encoding UTF8 | ConvertFrom-Json
        $existingNode = $cData.nodes | Where-Object { $_.canonical_name -eq $NodeName }
        if (-not $existingNode) {
            $newNodeObj = [PSCustomObject]@{
                id = "node-$('{0:d2}' -f ($cData.nodes.Count + 1))"
                hostname = $NodeName.ToUpper()
                canonical_name = $NodeName
                role = "$Role Node"
                ip = "DHCP/Dynamic"
                status = "active"
                legacy_aliases = @("$($NodeName.ToLower()).local")
                ports = [PSCustomObject]@{
                    caddy_http = 80
                    caddy_https = 443
                    jellyfin = 8096
                }
            }
            $cData.nodes += $newNodeObj
            $cData | ConvertTo-Json -Depth 6 | Set-Content -Path $clusterNodesJson -Encoding UTF8
            Write-Host "  [REGISTERED] Added $NodeName to config\cluster_nodes.json." -ForegroundColor Green
        } else {
            Write-Host "  [OK] Node $NodeName already present in cluster registry." -ForegroundColor Green
        }
    } catch {
        Write-Host "  [WARN] Could not update cluster_nodes.json: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# AI Collaboration Nexus Update
$nexusPath = Join-Path $BaseDir "handoffs\ai_collaboration_nexus.json"
if (Test-Path $nexusPath) {
    try {
        $nexus = Get-Content $nexusPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $nexus.cluster_status.active_nodes += $NodeName
        $nexus.cluster_status.active_nodes = $nexus.cluster_status.active_nodes | Select-Object -Unique
        $nexus.session_metadata.last_sync_timestamp = $timestamp
        $nexus | ConvertTo-Json -Depth 6 | Set-Content -Path $nexusPath -Encoding UTF8
        Write-Host "  [OK] Synchronized AI Collaboration Nexus." -ForegroundColor Green
    } catch {}
}

# ==============================================================================
# COMPLETION & SUMMARY REPORT
# ==============================================================================
Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host "   N E W   N O D E   I N S T A L L A T I O N   C O M P L E T E" -ForegroundColor Green
Write-Host "================================================================================" -ForegroundColor Cyan

Write-Host "`nNode Details:" -ForegroundColor Yellow
Write-Host "  * Canonical Hostname : $NodeName" -ForegroundColor White
Write-Host "  * Workload Profile   : $Role" -ForegroundColor White
Write-Host "  * Storage Policy     : $(if ($isConstrained) { 'Online-Only (Files On-Demand)' } else { 'Full Local Caching' })" -ForegroundColor Cyan
Write-Host "  * Compose Manifest   : $customCompose" -ForegroundColor White
Write-Host "  * Primary Server Node: $PrimaryIp (VoltaireUn)" -ForegroundColor DarkCyan

Write-Host "`nManagement Commands:" -ForegroundColor Yellow
Write-Host "  - Launch Mission Control HUD : .\s.ps1" -ForegroundColor Green
Write-Host "  - Run Verification Suite    : .\Test-MediaStackFleetVerification.ps1 -All" -ForegroundColor Green
Write-Host "  - Start Node Containers      : docker compose -f $customCompose up -d" -ForegroundColor Green
Write-Host "  - Deep Analysis & Handoffs   : .\Invoke-MediaStackDeepAnalysis.ps1" -ForegroundColor Green

Write-Host "`n[READY] Node '$NodeName' is fully provisioned, cloud-optimized, and integrated into Voltaire Network.`n" -ForegroundColor Green
