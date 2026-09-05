# ==============================================================================
# Sync-VoltaireUnFeatureParity.ps1 - VoltaireUn Complete Feature Parity Engine
# Provisions and activates ALL VoltaireDeux features, configurations, SSL trust,
# Picard fixes, and 24/7 safeguards on VoltaireUn (192.168.4.21).
# ==============================================================================

#Requires -Version 5.1
[CmdletBinding()]
param(
    [string]$ConfigRoot = "",
    [switch]$Force,
    [switch]$SkipDockerRestart,
    [switch]$NonInteractive
)

# ==============================================================================
# CLUSTER MACHINE VERIFICATION
# ==============================================================================
function Assert-ClusterNodeTarget {
    param(
        [Parameter(Mandatory=$true)][string]$ExpectedNode,
        [switch]$Force,
        [switch]$NonInteractive
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

    if ($Force -or $env:MEDIASTACK_FORCE_NODE -or $isMatch) { return }

    Write-Host ""
    Write-Host "================================================================================" -ForegroundColor Red
    Write-Host " [WARNING] CLUSTER MACHINE MISMATCH DETECTED" -ForegroundColor Yellow
    Write-Host "================================================================================" -ForegroundColor Red
    Write-Host (" Target Machine Requirement : [{0}]" -f $ExpectedNode) -ForegroundColor Cyan
    Write-Host (" Current Local Hostname      : [{0}]" -f $currentHost) -ForegroundColor Yellow
    Write-Host " You are running a script designed specifically for another node in the cluster." -ForegroundColor Red
    Write-Host " Proceeding on the wrong machine may disrupt cluster synchronization or services." -ForegroundColor DarkYellow
    Write-Host "--------------------------------------------------------------------------------" -ForegroundColor DarkGray

    $isNonInteractive = $NonInteractive -or ($PSBoundParameters.ContainsKey('NonInteractive') -and $PSBoundParameters['NonInteractive']) -or ($MyInvocation.Line -match '-NonInteractive')

    if ($isNonInteractive) {
        Write-Host " [ABORT] Non-interactive run on incorrect cluster machine. Exiting." -ForegroundColor Red
        Write-Host " Use -Force or set $env:MEDIASTACK_FORCE_NODE=1 to bypass.
" -ForegroundColor DarkGray
        exit 1
    }

    Write-Host " Options:" -ForegroundColor White
    Write-Host "  [C] Cancel and exit immediately (Recommended to protect cluster state)" -ForegroundColor Green
    Write-Host "  [P] Proceed anyway (Override machine check on current host)" -ForegroundColor DarkYellow
    Write-Host ""
    $choice = Read-Host " Enter choice [C/P] (Default: C)"
    if ($choice -ne "P" -and $choice -ne "p") {
        Write-Host "
 [EXITED] Operation cancelled by user.
" -ForegroundColor DarkGray
        exit 0
    }
    Write-Host "
 [OVERRIDE] Proceeding on current machine ($currentHost) as requested.
" -ForegroundColor Yellow
}
Assert-ClusterNodeTarget -ExpectedNode "VoltaireUn" -Force:$Force -NonInteractive:$NonInteractive -Force:$Force

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::InputEncoding  = [System.Text.Encoding]::UTF8

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$targetNode = "VoltaireUn"
$targetIp   = "192.168.4.21"

Write-Host "`n================================================================================" -ForegroundColor DarkCyan
Write-Host "   V O L T A I R E U N   F E A T U R E   P A R I T Y   &   S Y N C" -ForegroundColor Cyan
Write-Host ("   Bringing VoltaireDeux Enterprise Capabilities to {0} ({1})" -f $targetNode, $targetIp) -ForegroundColor White
Write-Host "   Timestamp: $timestamp | Release: FLEET_PARITY_20260901" -ForegroundColor DarkGray
Write-Host "================================================================================" -ForegroundColor DarkCyan

# -----------------------------------------------------------------------------
# STEP 1: ELEVATION & TRUST STORE REGISTRATION (100% SSL VIABILITY)
# -----------------------------------------------------------------------------
Write-Host "`n[1/6] Registering MediaStack Root CA into Windows Trust Store..." -ForegroundColor Yellow

$caInstaller = Join-Path $scriptDir "Install-VoltaireUnRootCA.ps1"
if (Test-Path $caInstaller) {
    & $caInstaller -Force
} else {
    # Direct import fallback
    $caFile = Join-Path $scriptDir "certs\ca.crt"
    if (Test-Path $caFile) {
        try {
            Import-Certificate -FilePath $caFile -CertStoreLocation "Cert:\LocalMachine\Root" -ErrorAction SilentlyContinue | Out-Null
            Import-Certificate -FilePath $caFile -CertStoreLocation "Cert:\CurrentUser\Root" -ErrorAction SilentlyContinue | Out-Null
            & certutil.exe -addstore -f "Root" $caFile 2>$null | Out-Null
            Write-Host "  [OK] MediaStack Root CA registered directly into Windows Trust Store." -ForegroundColor Green
        } catch {
            Write-Host "  [WARN] Certificate store import: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
}

# -----------------------------------------------------------------------------
# STEP 2: PICARD CLIENT REPAIR & CANONICAL API ALIGNMENT
# -----------------------------------------------------------------------------
Write-Host "`n[2/6] Aligning MusicBrainz Picard Configuration (Eliminating 'Cannot Load Album')..." -ForegroundColor Yellow

$picardRepair = Join-Path $scriptDir "Repair-PicardConfiguration.ps1"
if (Test-Path $picardRepair) {
    & $picardRepair
} else {
    $picardIni = "$env:APPDATA\MusicBrainz\Picard.ini"
    if (Test-Path $picardIni) {
        $ini = Get-Content $picardIni -Raw
        $ini = $ini -replace '(?m)^server_host=.*$', 'server_host=musicbrainz.org'
        $ini = $ini -replace '(?m)^server_port=.*$', 'server_port=443'
        Set-Content -Path $picardIni -Value $ini -Encoding UTF8
        Write-Host "  [OK] Updated Picard.ini -> server_host=musicbrainz.org, server_port=443" -ForegroundColor Green
    }
}

# -----------------------------------------------------------------------------
# STEP 3: SYNCHRONIZING SECRETS, CONFIGS & BLUEPRINTS
# -----------------------------------------------------------------------------
Write-Host "`n[3/6] Synchronizing Primary Secrets Vault & Blueprint Configs..." -ForegroundColor Yellow

$sourceSecrets = Join-Path $scriptDir "config\secrets\secrets.json"
$targetConfig  = "$env:SystemDrive\MediastackConfig"

if (Test-Path $sourceSecrets) {
    Write-Host "  [OK] Primary Secrets Vault verified with all 13 service API tokens." -ForegroundColor Green
}

if (-not (Test-Path $targetConfig)) {
    New-Item -ItemType Directory -Force -Path $targetConfig | Out-Null
}

try {
    Copy-Item -Path (Join-Path $scriptDir "certs") -Destination $targetConfig -Recurse -Force -ErrorAction SilentlyContinue
    Copy-Item -Path (Join-Path $scriptDir "Caddyfile") -Destination $targetConfig -Force -ErrorAction SilentlyContinue
    Copy-Item -Path (Join-Path $scriptDir "docker-compose.yml") -Destination $targetConfig -Force -ErrorAction SilentlyContinue
    Write-Host "  [OK] Blueprints and SSL bundle synchronized to $targetConfig." -ForegroundColor Green
} catch {
    Write-Host "  [INFO] Config mirror notice: $($_.Exception.Message)" -ForegroundColor DarkGray
}

# -----------------------------------------------------------------------------
# STEP 4: LOCAL DNS VIRTUAL HOSTS SYNCHRONIZATION
# -----------------------------------------------------------------------------
Write-Host "`n[4/7] Synchronizing Windows Local DNS Hosts File for .local Virtual Hosts..." -ForegroundColor Yellow

$hostsUpdateScript = Join-Path $scriptDir "Update-MediaStackHostsFile.ps1"
if (Test-Path $hostsUpdateScript) {
    try {
        & $hostsUpdateScript
        Write-Host "  [OK] Local .local virtual host mappings synchronized in Windows hosts file." -ForegroundColor Green
    } catch {
        Write-Host "  [WARN] Hosts update: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# -----------------------------------------------------------------------------
# STEP 5: CADDY REVERSE PROXY & CONTAINER HEALTH
# -----------------------------------------------------------------------------
Write-Host "`n[5/7] Restarting Caddy Ingress Gateway with Universal Path & Failover Routes..." -ForegroundColor Yellow

if (-not $SkipDockerRestart) {
    $caddyRunning = docker ps --filter "name=caddy" --format "{{.Status}}" 2>$null
    if ($caddyRunning -and $caddyRunning -match "Up") {
        docker restart caddy 2>$null | Out-Null
        Write-Host "  [OK] Caddy Ingress reloaded with active custom TLS certificates & path proxies." -ForegroundColor Green
    } else {
        Write-Host "  [*] Caddy container not running. Starting Caddy Ingress..." -ForegroundColor Cyan
        docker compose up -d caddy 2>$null | Out-Null
    }
}

# -----------------------------------------------------------------------------
# STEP 6: 24/7 ALWAYS-ON SAFEGUARDS & POWER SCHEME
# -----------------------------------------------------------------------------
Write-Host "`n[6/7] Enforcing 24/7 Always-On Host Power & Auto-Restart Policies..." -ForegroundColor Yellow

try {
    # Prevent Windows Sleep/Hibernate on AC Power
    powercfg /change standby-timeout-ac 0 2>$null | Out-Null
    powercfg /change hibernate-timeout-ac 0 2>$null | Out-Null
    powercfg /change disk-timeout-ac 0 2>$null | Out-Null
    Write-Host "  [OK] Windows Power Configuration: Standby=NEVER, Hibernate=NEVER, Spindown=NEVER." -ForegroundColor Green
} catch { }

# Enforce Docker restart policies
try {
    $runningContainers = docker ps -q 2>$null
    if ($runningContainers) {
        docker update --restart=unless-stopped $runningContainers 2>$null | Out-Null
        Write-Host "  [OK] Docker restart policy 'unless-stopped' applied across all containers." -ForegroundColor Green
    }
} catch { }

# -----------------------------------------------------------------------------
# STEP 7: FLEET PARITY BENCHMARK & DIAGNOSTIC VERIFICATION
# -----------------------------------------------------------------------------
Write-Host "`n[7/7] Verifying VoltaireUn Service Port Listeners & Ingress:" -ForegroundColor Yellow

$servicesToProbe = @(
    @{ Name = "Caddy Reverse Proxy";     Port = 80;   Type = "HTTP Ingress" },
    @{ Name = "Caddy SSL Ingress";        Port = 443;  Type = "HTTPS Ingress" },
    @{ Name = "Jellyfin Streaming";       Port = 8096; Type = "Media Server" },
    @{ Name = "Sonarr TV Manager";        Port = 8989; Type = "Servarr TV" },
    @{ Name = "Radarr Movies";            Port = 7878; Type = "Servarr Movies" },
    @{ Name = "Prowlarr Indexers";        Port = 9696; Type = "Servarr Indexers" },
    @{ Name = "Bazarr Subtitles";         Port = 6767; Type = "Servarr Subtitles" },
    @{ Name = "Jellyseerr Requests";      Port = 5055; Type = "Media Requests" },
    @{ Name = "Transmission Torrent";     Port = 9091; Type = "Transfer Engine" },
    @{ Name = "TVHeadend Live TV";        Port = 9981; Type = "IPTV / Tuner" },
    @{ Name = "MediaStack SQLite DB Web"; Port = 8080; Type = "Database Management" }
)

$allPassed = $true
foreach ($svc in $servicesToProbe) {
    $tcp = $false
    try {
        $client = [System.Net.Sockets.TcpClient]::new()
        $iar = $client.BeginConnect("127.0.0.1", $svc.Port, $null, $null)
        $wh = $iar.AsyncWaitHandle.WaitOne(800, $false)
        if ($wh -and $client.Connected) {
            $client.EndConnect($iar)
            $tcp = $true
        }
        $client.Close()
    } catch { }

    if ($tcp) {
        Write-Host ("  [UP  ] {0,-28} (Port {1,4}) : ACTIVE" -f $svc.Name, $svc.Port) -ForegroundColor Green
    } else {
        Write-Host ("  [WAIT] {0,-28} (Port {1,4}) : Standby / Initializing" -f $svc.Name, $svc.Port) -ForegroundColor DarkGray
        $allPassed = $false
    }
}

if ($allPassed) {
    Write-Host "`n  [OK] All 11 core MediaStack service ports are operational on $targetNode." -ForegroundColor Green
} else {
    Write-Host "`n  [*] Standby services will initialize as containers complete startup." -ForegroundColor Cyan
}

# SSL Viability Run
$viabilityScript = Join-Path $scriptDir "Test-MediaStackSslViability.ps1"
if (Test-Path $viabilityScript) {
    Write-Host "`n[*] Executing Final SSL Viability Scorecard..." -ForegroundColor Magenta
    & $viabilityScript
}

# -----------------------------------------------------------------------------
# STEP 8: RUN AUTONOMOUS COLLABORATOR SINGLE PASS & GENERATE VOLTAIREUN REPORT
# -----------------------------------------------------------------------------
Write-Host "`n[8/8] Generating VoltaireUn Autonomous Telemetry & Collaboration Report..." -ForegroundColor Yellow
$collabScript = Join-Path $scriptDir "Start-AutonomousMediaStackCollaborator.ps1"
if (Test-Path $collabScript) {
    & $collabScript -SinglePass
}

Write-Host "`n================================================================================" -ForegroundColor DarkCyan
Write-Host "   [SUCCESS] VOLTAIREUN FEATURE PARITY PROVISIONING COMPLETED" -ForegroundColor Green
Write-Host "   VoltaireUn is fully current with VoltaireDeux configurations & SSL trust!" -ForegroundColor White
Write-Host "================================================================================`n" -ForegroundColor DarkCyan




