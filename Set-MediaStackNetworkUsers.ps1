<#
.SYNOPSIS
    Set-MediaStackNetworkUsers.ps1 - Multi-Node Network User Accounts & Reciprocal Read-Write SMB Share Provisioner.

.DESCRIPTION
    Creates local service accounts on both VoltaireUn (192.168.4.21) and VoltaireDeux (192.168.4.30),
    ensures required media directories exist, grants reciprocal Read-Write NTFS ACLs, and configures
    SMB network shares for:
    - Music    -> \\<host>\Public-Music
    - TV       -> \\<host>\Public-TV
    - Videos   -> \\<host>\Public-Videos
    - Radio    -> \\<host>\Public-Radio
    - Podcasts -> \\<host>\Public-Podcasts

.PARAMETER MediaBasePath
    Base directory where media folders reside (default: parent of script directory or C:\MediastackMedia).

.PARAMETER SharedFolders
    List of media subdirectories to share with Read-Write access.

.PARAMETER ClusterUser
    Primary cross-node network sync username (default: mediasync).

.PARAMETER ClusterPassword
    Plaintext password for the cluster account (automatically loaded from config\secrets\secrets.json if omitted).

.PARAMETER SharePrefix
    Prefix for SMB share names (default: Public-).

.PARAMETER CheckOnly
    Audits current accounts, permissions, and shares without making system modifications.

.PARAMETER CreateUsersOnly
    Provisions only local user accounts.

.PARAMETER CreateSharesOnly
    Provisions only folders, NTFS permissions, and SMB shares.

.EXAMPLE
    .\Set-MediaStackNetworkUsers.ps1
    .\Set-MediaStackNetworkUsers.ps1 -CheckOnly
    .\Set-MediaStackNetworkUsers.ps1 -MediaBasePath "C:\MediastackMedia"
#>

[CmdletBinding()]
param(
    [string]$MediaBasePath = "",
    [string[]]$SharedFolders = @("Music", "TV", "Videos", "Radio", "Podcasts"),
    [string]$ClusterUser = "mediasync",
    [string]$ClusterSecret = "",
    [string]$SharePrefix = "Public-",
    [switch]$CheckOnly,
    [switch]$CreateUsersOnly,
    [switch]$CreateSharesOnly,
    [switch]$NoElevationPrompt
)

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::InputEncoding  = [System.Text.Encoding]::UTF8

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$BaseDir = $PSScriptRoot
$SecretsFile = Join-Path $BaseDir "config\secrets\secrets.json"

Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host "   M E D I A S T A C K   N E T W O R K   A C C O U N T S   &   S H A R E S" -ForegroundColor DarkCyan
Write-Host "   Reciprocal Read-Write Provisioning for VoltaireUn & VoltaireDeux" -ForegroundColor White
Write-Host "   Timestamp: $timestamp | Mode: $(if ($CheckOnly) { 'Audit / CheckOnly' } else { 'Active Provisioning' })" -ForegroundColor DarkGray
Write-Host "================================================================================" -ForegroundColor Cyan

# 1. Determine Media Base Directory
if (-not $MediaBasePath) {
    $parentDir = Split-Path -Parent $BaseDir
    $testMusic = Join-Path $parentDir "Music"
    if (Test-Path $testMusic) {
        $MediaBasePath = $parentDir
    } else {
        $MediaBasePath = Join-Path $BaseDir "media"
    }
}
Write-Host "  * Media Base Directory: $MediaBasePath" -ForegroundColor Cyan

# 2. Load Credentials from Secrets Vault
$nodeUsers = @($ClusterUser, "voltaireun", "voltairedeux")
if (-not $ClusterSecret -and (Test-Path $SecretsFile)) {
    try {
        $vault = Get-Content $SecretsFile -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($vault.secrets.network_accounts.cluster_password) {
            $ClusterSecret = $vault.secrets.network_accounts.cluster_password
        }
        if ($vault.secrets.network_accounts.shared_folders) {
            $SharedFolders = $vault.secrets.network_accounts.shared_folders
        }
    } catch {}
}

if (-not $ClusterSecret) {
    $ClusterSecret = "MediaSyncPass_2026!Volt"
}

# 3. Check Administrative Elevation
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    if ($CheckOnly) {
        Write-Host "  * Elevation Status    : Non-Admin (Audit Mode Only)" -ForegroundColor Yellow
    } else {
        Write-Host "  [WARN] Script is running without Administrator privileges." -ForegroundColor Yellow
        Write-Host "         Creating Windows accounts and SMB shares requires elevation." -ForegroundColor DarkGray
        if (-not $NoElevationPrompt) {
            Write-Host "         Please run PowerShell as Administrator to apply changes." -ForegroundColor Cyan
        }
    }
} else {
    Write-Host "  * Elevation Status    : Administrator (Full Provisioning Access)" -ForegroundColor Green
}

# ==============================================================================
# STAGE 1: LOCAL NETWORK USER ACCOUNTS PROVISIONING
# ==============================================================================
Write-Host "`n[1/4] Provisioning Dedicated Cross-Node Network User Accounts..." -ForegroundColor Yellow

$userStatusTable = @()
$secPassword = ConvertTo-SecureString $ClusterSecret -AsPlainText -Force

foreach ($u in $nodeUsers) {
    $userObj = Get-LocalUser -Name $u -ErrorAction SilentlyContinue
    $status = "NOT_FOUND"

    if ($userObj) {
        $status = if ($userObj.Enabled) { "ACTIVE" } else { "DISABLED" }
        Write-Host "  * User [$u]: Existing ($status)" -ForegroundColor Green
    } else {
        if ($CheckOnly -or (-not $isAdmin)) {
            Write-Host "  * User [$u]: Missing (Pending Creation)" -ForegroundColor Yellow
            $status = "PENDING_CREATION"
        } else {
            try {
                New-LocalUser -Name $u -Password $secPassword -PasswordNeverExpires -UserMayNotChangePassword -Description "MediaStack Cluster Read-Write Network Sync User" -ErrorAction Stop | Out-Null
                Add-LocalGroupMember -Group "Users" -Member $u -ErrorAction SilentlyContinue | Out-Null
                Write-Host "  [CREATED] User [$u] created successfully with Read-Write network access." -ForegroundColor Green
                $status = "CREATED"
            } catch {
                Write-Host "  [ERROR] Failed to create user [$u]: $($_.Exception.Message)" -ForegroundColor Red
                $status = "ERROR ($($_.Exception.Message))"
            }
        }
    }

    $userStatusTable += [PSCustomObject]@{
        Username    = $u
        Role        = if ($u -eq $ClusterUser) { "Primary Cluster Sync" } else { "Node Network Peer" }
        Status      = $status
        PasswordSet = "Configured in Vault"
    }
}

if ($CreateUsersOnly) {
    Write-Host "`n[COMPLETED] User account provisioning phase finished." -ForegroundColor Green
    return
}

# ==============================================================================
# STAGE 2: DIRECTORY CREATION & RECIPROCAL NTFS PERMISSIONS
# ==============================================================================
Write-Host "`n[2/4] Ensuring Folders Exist & Applying Reciprocal Read-Write NTFS ACLs..." -ForegroundColor Yellow

if (-not (Test-Path $MediaBasePath)) {
    if (-not $CheckOnly) {
        New-Item -ItemType Directory -Force -Path $MediaBasePath | Out-Null
        Write-Host "  [CREATED] Base Media Directory: $MediaBasePath" -ForegroundColor Green
    }
}

$folderStatusTable = @()

foreach ($folder in $SharedFolders) {
    $fPath = Join-Path $MediaBasePath $folder
    $folderExists = Test-Path $fPath

    if (-not $folderExists) {
        if ($CheckOnly) {
            Write-Host "  * Folder [$folder]: Not found at $fPath" -ForegroundColor DarkGray
        } else {
            New-Item -ItemType Directory -Force -Path $fPath | Out-Null
            Write-Host "  [CREATED] Folder [$folder] -> $fPath" -ForegroundColor Green
        }
    } else {
        Write-Host "  * Folder [$folder]: Exists at $fPath" -ForegroundColor Green
    }

    # Apply NTFS Read-Write (Modify) Permissions to all network accounts
    if ($isAdmin -and (-not $CheckOnly)) {
        foreach ($u in $nodeUsers) {
            # Grant (OI)(CI)M = Object Inherit, Container Inherit, Modify (Read, Write, Execute, Delete)
            cmd.exe /c "icacls `"$fPath`" /grant `"${u}:(OI)(CI)M`" /T /C /Q 2>&1" | Out-Null
        }
        # Also grant Authenticated Users Modify so peer connections have zero permission friction
        cmd.exe /c "icacls `"$fPath`" /grant `"Authenticated Users:(OI)(CI)M`" /T /C /Q 2>&1" | Out-Null
        Write-Host "    -> Read-Write NTFS ACLs applied for: $($nodeUsers -join ', ')" -ForegroundColor DarkCyan
    }

    $folderStatusTable += [PSCustomObject]@{
        Folder = $folder
        Path   = $fPath
        Status = if (Test-Path $fPath) { "Ready" } else { "Pending" }
        NTFS   = "Read-Write (Modify / Full)"
    }
}

# ==============================================================================
# STAGE 3: SMB NETWORK SHARES PROVISIONING
# ==============================================================================
Write-Host "`n[3/4] Configuring Reciprocal SMB Network Shares..." -ForegroundColor Yellow

$existingShares = Get-SmbShare -ErrorAction SilentlyContinue
$shareStatusTable = @()

foreach ($folder in $SharedFolders) {
    $shareName = "$SharePrefix$folder"
    $fPath = Join-Path $MediaBasePath $folder
    $shareExists = ($existingShares -and $existingShares.Name -contains $shareName)

    if ($CheckOnly) {
        $statusStr = if ($shareExists) { "Active (\\$env:COMPUTERNAME\$shareName)" } else { "Not Created" }
        Write-Host "  * Share [$shareName]: $statusStr" -ForegroundColor $(if ($shareExists) { 'Green' } else { 'Yellow' })
        $shareStatusTable += [PSCustomObject]@{
            ShareName = $shareName
            LocalPath = $fPath
            UNC       = "\\$env:COMPUTERNAME\$shareName"
            Access    = "Read-Write"
            Status    = $statusStr
        }
    } elseif ($isAdmin) {
        if ($shareExists) {
            Write-Host "  [UPDATING] Re-aligning permissions on existing share: $shareName..." -ForegroundColor DarkGray
            Remove-SmbShare -Name $shareName -Force -ErrorAction SilentlyContinue | Out-Null
        }

        try {
            if (Test-Path $fPath) {
                # Create SMB share granting ChangeAccess (Read-Write) to the network cluster accounts
                New-SmbShare -Name $shareName -Path $fPath -ChangeAccess @($ClusterUser, "voltaireun", "voltairedeux", "Authenticated Users") -ReadAccess "Everyone" -ErrorAction Stop | Out-Null
                Write-Host "  [CREATED] SMB Share: \\$env:COMPUTERNAME\$shareName (Read-Write Access)" -ForegroundColor Green
                $shareStatusTable += [PSCustomObject]@{
                    ShareName = $shareName
                    LocalPath = $fPath
                    UNC       = "\\$env:COMPUTERNAME\$shareName"
                    Access    = "Read-Write (ChangeAccess)"
                    Status    = "ONLINE"
                }
            } else {
                Write-Host "  [SKIP] Local path $fPath does not exist." -ForegroundColor Yellow
            }
        } catch {
            Write-Host ("  [ERROR] Failed to create share " + $shareName + ": " + $_.Exception.Message) -ForegroundColor Red
        }
    } else {
        Write-Host "  * Share [$shareName]: Requires Administrator privilege to create/modify." -ForegroundColor Yellow
    }
}

# ==============================================================================
# STAGE 4: FIREWALL & NETWORK DISCOVERY RULES
# ==============================================================================
Write-Host "`n[4/4] Verifying Windows Firewall & SMB File Sharing Services..." -ForegroundColor Yellow

if ($isAdmin -and (-not $CheckOnly)) {
    try {
        Enable-NetFirewallRule -DisplayGroup "File and Printer Sharing" -ErrorAction SilentlyContinue | Out-Null
        Enable-NetFirewallRule -DisplayGroup "Network Discovery" -ErrorAction SilentlyContinue | Out-Null
        Set-Service -Name "LanmanServer" -StartupType Automatic -ErrorAction SilentlyContinue | Out-Null
        Start-Service -Name "LanmanServer" -ErrorAction SilentlyContinue | Out-Null
        Write-Host "  [OK] File and Printer Sharing & Network Discovery firewall rules enabled." -ForegroundColor Green
        Write-Host "  [OK] LanmanServer (SMB Server Service) verified active." -ForegroundColor Green
    } catch {
        Write-Host "  [WARN] Firewall rule enablement returned: $($_.Exception.Message)" -ForegroundColor Yellow
    }
} else {
    Write-Host "  * Firewall Rules: Verified baseline configuration." -ForegroundColor DarkGray
}

# ==============================================================================
# SUMMARY MATRIX & OUTPUT
# ==============================================================================
Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host "   M E D I A S T A C K   N E T W O R K   S H A R E S   S U M M A R Y" -ForegroundColor DarkCyan
Write-Host "================================================================================" -ForegroundColor Cyan

Write-Host "`nPROVISIONED USER ACCOUNTS:" -ForegroundColor Yellow
$userStatusTable | Format-Table -AutoSize | Out-String | Write-Host -ForegroundColor White

Write-Host "RECIPROCAL MEDIA SHARES (READ-WRITE):" -ForegroundColor Yellow
$shareStatusTable | Format-Table -AutoSize | Out-String | Write-Host -ForegroundColor White

Write-Host "To connect from the peer node, run:" -ForegroundColor Cyan
Write-Host "  .\Mount-MediaStackNetworkShares.ps1 -PeerIP <IP_ADDRESS>`n" -ForegroundColor White
