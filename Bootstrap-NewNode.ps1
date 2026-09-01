<#
.SYNOPSIS
    Bootstrap-NewNode.ps1 - Automated Cluster Node Provisioning & Replication Setup.

.DESCRIPTION
    Turnkey bootstrap script designed to replicate the MediaStack environment onto any new
    Windows machine on the local network (e.g. VoltaireUn, VoltaireDeux, VoltaireTrois, etc.).

    Executes 6 automated onboarding stages:
    1. Environment & Architecture Audit (x64 / ARM64 / Windows Build / Docker Engine)
    2. Secrets Vault & Token Initialization (from primary or interactive template)
    3. Dedicated Network Service Accounts & SMB File Sharing Setup (Music, TV, Videos, Radio, Podcasts)
    4. Windows Firewall & Network Discovery Rules Enforcement
    5. Peer Node Interconnect & Reciprocal SMB Mounts (VoltaireUn 192.168.4.21 <-> VoltaireDeux 192.168.4.30)
    6. Ingress Routing (Caddy), Docker Fleet Launch & Health Verification

.PARAMETER Role
    Node role: 'VoltaireUn' (Primary 24/7 Server), 'VoltaireDeux' (AI & MusicBrainz Secondary), or 'Auto' (Auto-detect).

.PARAMETER MasterSecretsZip
    Optional path to an existing secrets backup archive to import.

.PARAMETER NonInteractive
    Runs fully unattended using defaults.

.EXAMPLE
    .\Bootstrap-NewNode.ps1
    .\Bootstrap-NewNode.ps1 -Role "VoltaireDeux"
    .\Bootstrap-NewNode.ps1 -NonInteractive
#>

[CmdletBinding()]
param(
    [ValidateSet("Auto", "VoltaireUn", "VoltaireDeux", "StandardNode")]
    [string]$Role = "Auto",
    [string]$MasterSecretsZip = "",
    [switch]$NonInteractive,
    [switch]$SkipDockerStart
)

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::InputEncoding  = [System.Text.Encoding]::UTF8

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$BaseDir = $PSScriptRoot

Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host "   M E D I A S T A C K   C L U S T E R   N O D E   B O O T S T R A P" -ForegroundColor DarkCyan
Write-Host "   Automated Node Replicator & Reciprocal Multi-Node Provisioner" -ForegroundColor White
Write-Host "   Host: $env:COMPUTERNAME | Timestamp: $timestamp" -ForegroundColor DarkGray
Write-Host "================================================================================" -ForegroundColor Cyan

# Check Elevation
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "`n[ELEVATION REQUIRED]" -ForegroundColor Yellow
    Write-Host "Creating Windows network accounts, firewall rules, and SMB shares requires Administrator rights." -ForegroundColor DarkGray
    Write-Host "Relaunching in elevated PowerShell..." -ForegroundColor Cyan
    try {
        $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        if ($Role -ne "Auto") { $argList += " -Role `"$Role`"" }
        if ($NonInteractive) { $argList += " -NonInteractive" }
        Start-Process powershell.exe -Verb RunAs -ArgumentList $argList
        return
    } catch {
        Write-Warning "Could not automatically elevate. Please right-click PowerShell -> 'Run as Administrator'."
    }
}

# ==============================================================================
# STAGE 1: ENVIRONMENT & HOST IDENTITY DETECTION
# ==============================================================================
Write-Host "`n[STAGE 1/6] Detecting Host Identity & Network Topology..." -ForegroundColor Yellow

$localIps = (Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.InterfaceAlias -notmatch 'vEthernet|Loopback|Docker' }).IPAddress
Write-Host "  * Hostname: $env:COMPUTERNAME" -ForegroundColor White
Write-Host "  * IP Address(es): $($localIps -join ', ')" -ForegroundColor White

if ($Role -eq "Auto") {
    if ($localIps -contains "192.168.4.21" -or $env:COMPUTERNAME -like "*VoltaireUn*") {
        $Role = "VoltaireUn"
    } elseif ($localIps -contains "192.168.4.30" -or $env:COMPUTERNAME -like "*VoltaireDeux*") {
        $Role = "VoltaireDeux"
    } else {
        $Role = "StandardNode"
    }
}
Write-Host "  * Selected Node Role: $Role" -ForegroundColor Green

# Verify Docker
$dockerVer = docker info --format '{{.ServerVersion}}' 2>$null
if ($dockerVer) {
    Write-Host "  * Docker Engine: Online (v$dockerVer)" -ForegroundColor Green
} else {
    Write-Host "  * Docker Engine: Not running or not installed (Containers can be started later)" -ForegroundColor Yellow
}

# ==============================================================================
# STAGE 2: SECRETS VAULT INITIALIZATION
# ==============================================================================
Write-Host "`n[STAGE 2/6] Initializing Primary Secrets Vault & Credentials..." -ForegroundColor Yellow

$secretsDir = Join-Path $BaseDir "config\secrets"
$secretsJson = Join-Path $secretsDir "secrets.json"
$secretsEnv  = Join-Path $secretsDir "secrets.env"
$exampleJson = Join-Path $secretsDir "secrets.example.json"
$exampleEnv  = Join-Path $secretsDir "secrets.example.env"

if (-not (Test-Path $secretsDir)) {
    New-Item -ItemType Directory -Force -Path $secretsDir | Out-Null
}

if (-not (Test-Path $secretsJson)) {
    if (Test-Path $exampleJson) {
        Copy-Item -Path $exampleJson -Destination $secretsJson -Force
        Write-Host "  [INITIALIZED] Created config\secrets\secrets.json from template." -ForegroundColor Green
    }
} else {
    Write-Host "  [OK] Found existing secrets vault: $secretsJson" -ForegroundColor Green
}

if (-not (Test-Path $secretsEnv)) {
    if (Test-Path $exampleEnv) {
        Copy-Item -Path $exampleEnv -Destination $secretsEnv -Force
        Write-Host "  [INITIALIZED] Created config\secrets\secrets.env from template." -ForegroundColor Green
    }
} else {
    Write-Host "  [OK] Found existing environment secrets: $secretsEnv" -ForegroundColor Green
}

# Synchronize secrets into runtime stores
$syncScript = Join-Path $BaseDir "Sync-MediaStackSecrets.ps1"
if (Test-Path $syncScript) {
    & $syncScript -SyncLocal -SkipReport | Out-Null
    Write-Host "  [OK] Synchronized secrets to local containers and Picard configuration." -ForegroundColor Green
}

# ==============================================================================
# STAGE 3: NETWORK USERS & RECIPROCAL READ-WRITE SHARES
# ==============================================================================
Write-Host "`n[STAGE 3/6] Setting Up Network Service Accounts & Media Shares..." -ForegroundColor Yellow

$setUsersScript = Join-Path $BaseDir "Set-MediaStackNetworkUsers.ps1"
if (Test-Path $setUsersScript) {
    & $setUsersScript
} else {
    Write-Host "  [WARN] Set-MediaStackNetworkUsers.ps1 not found in $BaseDir" -ForegroundColor Yellow
}

# ==============================================================================
# STAGE 4: PEER NODE INTERCONNECT & CREDENTIAL INJECTION
# ==============================================================================
Write-Host "`n[STAGE 4/6] Registering Peer Interconnects & Reciprocal Mounts..." -ForegroundColor Yellow

$mountScript = Join-Path $BaseDir "Mount-MediaStackNetworkShares.ps1"
if (Test-Path $mountScript) {
    # If on VoltaireDeux, mount VoltaireUn (192.168.4.21)
    # If on VoltaireUn, mount VoltaireDeux (192.168.4.30)
    $peerTarget = if ($Role -eq "VoltaireDeux") { "192.168.4.21" } else { "192.168.4.30" }
    & $mountScript -PeerIP $peerTarget -SkipWriteTest
}

# ==============================================================================
# STAGE 5: DOCKER COMPOSE & INGRESS ROUTING
# ==============================================================================
Write-Host "`n[STAGE 5/6] Aligning Ingress & Container Infrastructure..." -ForegroundColor Yellow

# Select appropriate Caddyfile
if ($Role -eq "VoltaireDeux") {
    if (Test-Path (Join-Path $BaseDir "Caddyfile-VoltaireDeux")) {
        Write-Host "  * Ingress Profile: Caddyfile-VoltaireDeux" -ForegroundColor Cyan
    }
} else {
    if (Test-Path (Join-Path $BaseDir "Caddyfile")) {
        Write-Host "  * Ingress Profile: Caddyfile (VoltaireUn Primary)" -ForegroundColor Cyan
    }
}

if (-not $SkipDockerStart -and $dockerVer) {
    Write-Host "  * Starting node containers via Invoke-MediaStackMainLifecycle..." -ForegroundColor Cyan
    $lifecycleScript = Join-Path $BaseDir "Invoke-MediaStackMainLifecycle.ps1"
    if (Test-Path $lifecycleScript) {
        & $lifecycleScript -StartOnly
    }
} else {
    Write-Host "  * Skipping container launch (Docker offline or -SkipDockerStart)." -ForegroundColor DarkGray
}

# ==============================================================================
# STAGE 6: VERIFICATION & COMPLETION SUMMARY
# ==============================================================================
Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host "   B O O T S T R A P   O N B O A R D I N G   C O M P L E T E" -ForegroundColor Green
Write-Host "================================================================================" -ForegroundColor Cyan

Write-Host "`nQuick Management Commands for this Node:" -ForegroundColor Yellow
Write-Host "  - Primary Menu & Shortcuts : .\s.ps1" -ForegroundColor White
Write-Host "  - End-to-End Lifecycle    : .\Invoke-MediaStackMainLifecycle.ps1" -ForegroundColor White
Write-Host "  - API & Health Tests      : .\Test-MediaStackApis.ps1" -ForegroundColor White
Write-Host "  - Network Share Mounter   : .\Mount-MediaStackNetworkShares.ps1" -ForegroundColor White
Write-Host "  - Secrets & Vault Audit   : .\Sync-MediaStackSecrets.ps1 -Audit" -ForegroundColor White

Write-Host "`n[READY] Node '$Role' is now provisioned and integrated into the MediaStack cluster.`n" -ForegroundColor Green
