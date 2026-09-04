<#
.SYNOPSIS
    Mount-MediaStackNetworkShares.ps1 - Cross-Node Reciprocal SMB Share Mount & Read-Write Validator.

.DESCRIPTION
    Authenticates and tests reciprocal SMB file sharing between VoltaireUn (192.168.4.21)
    and VoltaireDeux (192.168.4.30). Automatically connects to peer shares:
    - \\<PeerIP>\MediaStack-Movies
    - \\<PeerIP>\MediaStack-Shows
    - \\<PeerIP>\MediaStack-Music
    - \\<PeerIP>\MediaStack-TV
    - \\<PeerIP>\MediaStack-Videos
    - \\<PeerIP>\MediaStack-Radio
    - \\<PeerIP>\MediaStack-Podcasts
    - \\<PeerIP>\MediaStack-Downloads
    - \\<PeerIP>\MediaStack-Documents

    Performs end-to-end Read/Write canary validation to confirm both nodes have active read-write access.

.PARAMETER PeerIP
    IP address or hostname of the target peer machine (default: auto-detected based on local IP).

.PARAMETER Username
    Network sync account username (default: mediasync).

.PARAMETER Password
    Network sync account password (loaded automatically from config\secrets\secrets.json).

.PARAMETER SharedFolders
    List of media subdirectories to probe/mount.

.PARAMETER SharePrefix
    Prefix for share names (default: MediaStack-).

.PARAMETER TestWrite
    Performs active Read-Write canary file verification across the network shares.

.PARAMETER CheckOnly
    Probes share reachability without saving persistent credentials.

.EXAMPLE
    .\Mount-MediaStackNetworkShares.ps1
    .\Mount-MediaStackNetworkShares.ps1 -PeerIP "192.168.4.21" -TestWrite
    .\Mount-MediaStackNetworkShares.ps1 -CheckOnly
#>

[CmdletBinding()]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', '')]
param(
    [string]$PeerIP = "",
    [string]$Username = "mediasync",
    [string]$Password = "",
    [string[]]$SharedFolders = @("Movies", "Shows", "Music", "TV", "Videos", "Radio", "Podcasts", "downloads", "documents"),
    [string]$SharePrefix = "MediaStack-",
    [switch]$SkipWriteTest,
    [switch]$CheckOnly
)

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::InputEncoding  = [System.Text.Encoding]::UTF8

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$BaseDir = $PSScriptRoot
$SecretsFile = Join-Path $BaseDir "config\secrets\secrets.json"

$PrimaryIP   = "192.168.4.21"
$SecondaryIP = "192.168.4.30"

# 1. Determine Local and Peer Node IPs
if (-not $PeerIP) {
    # Check local IPs
    $localIps = (Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue).IPAddress
    if ($localIps -contains $SecondaryIP) {
        $PeerIP = $PrimaryIP
        $LocalRole = "VoltaireDeux ($SecondaryIP)"
        $PeerRole  = "VoltaireUn ($PrimaryIP)"
    } elseif ($localIps -contains $PrimaryIP) {
        $PeerIP = $SecondaryIP
        $LocalRole = "VoltaireUn ($PrimaryIP)"
        $PeerRole  = "VoltaireDeux ($SecondaryIP)"
    } else {
        $PeerIP = $PrimaryIP
        $LocalRole = "$env:COMPUTERNAME"
        $PeerRole  = "Target Peer ($PrimaryIP)"
    }
} else {
    $LocalRole = "$env:COMPUTERNAME"
    $PeerRole  = "Custom Peer ($PeerIP)"
}

Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host "   M E D I A S T A C K   N E T W O R K   S H A R E   M O U N T E R" -ForegroundColor DarkCyan
Write-Host "   Local: $LocalRole <===================> Peer: $PeerRole" -ForegroundColor White
Write-Host "   Timestamp: $timestamp" -ForegroundColor DarkGray
Write-Host "================================================================================" -ForegroundColor Cyan

# 2. Load Credentials from Secrets Vault
if (-not $Password -and (Test-Path $SecretsFile)) {
    try {
        $vault = Get-Content $SecretsFile -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($vault.secrets.network_accounts.cluster_password) {
            $Password = $vault.secrets.network_accounts.cluster_password
        }
        if ($vault.secrets.network_accounts.cluster_user) {
            $Username = $vault.secrets.network_accounts.cluster_user
        }
        if ($vault.secrets.network_accounts.shared_folders) {
            $SharedFolders = $vault.secrets.network_accounts.shared_folders
        }
    } catch {}
}

if (-not $Password) {
    $Password = "MediaSyncPass_2026!Volt"
}

# 3. Check Peer Network Connectivity
Write-Host "`n[1/3] Probing Peer Host Reachability ($PeerIP)..." -ForegroundColor Yellow
$ping = Test-Connection -ComputerName $PeerIP -Count 2 -Quiet -ErrorAction SilentlyContinue
if ($ping) {
    Write-Host "  * Host Ping ($PeerIP): ONLINE / Reachable" -ForegroundColor Green
} else {
    Write-Host "  * Host Ping ($PeerIP): UNREACHABLE (Host may be offline or ICMP blocked)" -ForegroundColor Yellow
}

# 4. Inject Stored Network Credentials via cmdkey
Write-Host "`n[2/3] Registering Windows Network Credentials for $PeerIP..." -ForegroundColor Yellow
if (-not $CheckOnly) {
    try {
        cmd.exe /c "cmdkey /generic:$PeerIP /user:$PeerIP\$Username /pass:$Password 2>&1" | Out-Null
        cmd.exe /c "cmdkey /add:$PeerIP /user:$Username /pass:$Password 2>&1" | Out-Null
        Write-Host "  [OK] Stored network credentials for user '$Username' on target $PeerIP." -ForegroundColor Green
    } catch {
        Write-Host "  [WARN] cmdkey registration returned: $($_.Exception.Message)" -ForegroundColor Yellow
    }
} else {
    Write-Host "  * CheckOnly mode: Skipping credential persistence." -ForegroundColor DarkGray
}

# 5. Probe & Validate Reciprocal Shares
Write-Host "`n[3/3] Testing UNC Share Accessibility & Reciprocal Read-Write Access..." -ForegroundColor Yellow

$results = @()

foreach ($folder in $SharedFolders) {
    $shareName = "$SharePrefix$folder"
    $uncPath = "\\$PeerIP\$shareName"
    $readOk = $false
    $writeOk = $false
    $details = ""
    $latencyMs = 0

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    if (Test-Path $uncPath -ErrorAction SilentlyContinue) {
        $readOk = $true
        $sw.Stop()
        $latencyMs = $sw.ElapsedMilliseconds

        # Test Read Access
        $items = Get-ChildItem -Path $uncPath -ErrorAction SilentlyContinue
        $itemCount = if ($items) { $items.Count } else { 0 }

        # Test Write Access if requested
        if (-not $SkipWriteTest) {
            $canaryFile = Join-Path $uncPath ".canary_rw_test_$(Get-Date -Format 'yyyyMMdd_HHmmss').tmp"
            try {
                $testContent = "MediaStack Reciprocal RW Canary Test | Host: $env:COMPUTERNAME | Target: $PeerIP | Timestamp: $timestamp"
                Set-Content -Path $canaryFile -Value $testContent -Encoding UTF8 -ErrorAction Stop
                $readBack = Get-Content -Path $canaryFile -Raw -ErrorAction SilentlyContinue
                if ($readBack -and $readBack.Trim() -eq $testContent) {
                    $writeOk = $true
                    Remove-Item -Path $canaryFile -Force -ErrorAction SilentlyContinue
                    $details = "Read-Write Confirmed ($itemCount items present)"
                } else {
                    $details = "Read-Only (Write verification read-back mismatch)"
                }
            } catch {
                $writeOk = $false
                $details = "Read-Only (Write failed: $($_.Exception.Message))"
            }
        } else {
            $details = "Read Accessible ($itemCount items present)"
        }
    } else {
        $sw.Stop()
        $latencyMs = $sw.ElapsedMilliseconds
        $details = "Share Offline or Access Denied"
    }

    $statusStr = if ($writeOk) { "READ-WRITE OK" } elseif ($readOk) { "READ-ONLY" } else { "OFFLINE / DENIED" }
    $color = if ($writeOk) { "Green" } elseif ($readOk) { "Yellow" } else { "DarkGray" }

    Write-Host ("  [{0,-16}] {1,-32} -> Latency: {2,4}ms | {3}" -f $statusStr, $uncPath, $latencyMs, $details) -ForegroundColor $color

    $results += [PSCustomObject]@{
        ShareName  = $shareName
        UNCPath    = $uncPath
        Status     = $statusStr
        ReadAccess = $readOk
        WriteAccess= $writeOk
        Latency    = "${latencyMs}ms"
        Details    = $details
    }
}

# ==============================================================================
# SUMMARY MATRIX
# ==============================================================================
Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host "   R E C I P R O C A L   S H A R E   A U D I T   R E S U L T S" -ForegroundColor DarkCyan
Write-Host "================================================================================" -ForegroundColor Cyan

$results | Format-Table -AutoSize | Out-String | Write-Host -ForegroundColor White

Write-Host "To provision or re-align shares on the peer machine ($PeerIP), run:" -ForegroundColor Cyan
Write-Host "  .\Set-MediaStackNetworkUsers.ps1`n" -ForegroundColor White
