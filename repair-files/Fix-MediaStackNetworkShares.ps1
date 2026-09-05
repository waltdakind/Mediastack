<#
.SYNOPSIS
    Fix-MediaStackNetworkShares.ps1 - Provision & Re-align Network Shares to C:\Users\waltd\OneDrive\Mediastack.

.DESCRIPTION
    Removes legacy network shares mapped to C:\Users\Public and provisions fresh
    MediaStack-* network shares rooted as subfolders of Mediastack (C:\Users\waltd\OneDrive\Mediastack\):
    - MediaStack-Movies    -> C:\Users\waltd\OneDrive\Mediastack\Movies
    - MediaStack-Shows     -> C:\Users\waltd\OneDrive\Mediastack\Shows
    - MediaStack-Music     -> C:\Users\waltd\OneDrive\Mediastack\Music
    - MediaStack-TV        -> C:\Users\waltd\OneDrive\Mediastack\TV
    - MediaStack-Videos    -> C:\Users\waltd\OneDrive\Mediastack\Videos
    - MediaStack-Radio     -> C:\Users\waltd\OneDrive\Mediastack\Radio
    - MediaStack-Podcasts  -> C:\Users\waltd\OneDrive\Mediastack\Podcasts
    - MediaStack-Downloads -> C:\Users\waltd\OneDrive\Mediastack\downloads
    - MediaStack-Documents -> C:\Users\waltd\OneDrive\Mediastack\documents

.PARAMETER Elevate
    Automatically elevates to Administrator prompt if not already running with administrative rights.
#>

[CmdletBinding()]
param(
    [string]$MediaBasePath = "",
    [switch]$CheckOnly,
    [switch]$Elevate
)

if (-not $MediaBasePath) {
    $MediaBasePath = $PSScriptRoot
    if (-not $MediaBasePath) { $MediaBasePath = (Get-Location).Path }
}

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if ((-not $isAdmin) -and (-not $CheckOnly)) {
    if ($Elevate) {
        Write-Host "Elevating to Administrator privileges..." -ForegroundColor Cyan
        Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        return
    } else {
        Write-Host "`n[NOTE] Not running as Administrator. If share modifications fail, re-run with: .\Fix-MediaStackNetworkShares.ps1 -Elevate" -ForegroundColor Yellow
    }
}

Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host "   M E D I A S T A C K   N E T W O R K   S H A R E   R E - A L I G N M E N T" -ForegroundColor DarkCyan
Write-Host "   Target Root: $MediaBasePath" -ForegroundColor White
Write-Host "   Mode: $(if ($CheckOnly) { 'Audit / CheckOnly' } else { 'Active Provisioning' })" -ForegroundColor DarkGray
Write-Host "================================================================================" -ForegroundColor Cyan

$SharedFolders = @(
    @{ Name = "MediaStack-Movies";    Sub = "Movies" },
    @{ Name = "MediaStack-Shows";     Sub = "Shows" },
    @{ Name = "MediaStack-Music";     Sub = "Music" },
    @{ Name = "MediaStack-TV";        Sub = "TV" },
    @{ Name = "MediaStack-Videos";    Sub = "Videos" },
    @{ Name = "MediaStack-Radio";     Sub = "Radio" },
    @{ Name = "MediaStack-Podcasts";  Sub = "Podcasts" },
    @{ Name = "MediaStack-Downloads"; Sub = "downloads" },
    @{ Name = "MediaStack-Documents"; Sub = "documents" }
)

# 1. Clean old shares
$legacyShares = @("Public-Downloads", "Public-Music", "Public-Pictures", "Public-Videos")

if (-not $CheckOnly) {
    Write-Host "`n[1/3] Removing Obsolete Public Folder Shares..." -ForegroundColor Yellow
    foreach ($ls in $legacyShares) {
        $existing = Get-SmbShare -Name $ls -ErrorAction SilentlyContinue
        if ($existing) {
            try {
                Remove-SmbShare -Name $ls -Force -ErrorAction Stop | Out-Null
                Write-Host "  [REMOVED] Legacy share: $ls ($($existing.Path))" -ForegroundColor Green
            } catch {
                Write-Host "  [WARN] Could not remove $($ls): $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }

    $docShare = Get-SmbShare -Name "MediaStack-Documents" -ErrorAction SilentlyContinue
    if ($docShare -and ($docShare.Path -match "Public")) {
        try {
            Remove-SmbShare -Name "MediaStack-Documents" -Force -ErrorAction Stop | Out-Null
            Write-Host "  [REMOVED] Misaligned MediaStack-Documents pointing to Public." -ForegroundColor Green
        } catch {}
    }
}

# 2. Provision directories and shares
Write-Host "`n[2/3] Provisioning Directories and MediaStack-* SMB Shares..." -ForegroundColor Yellow
$summaryTable = @()

foreach ($item in $SharedFolders) {
    $shareName = $item.Name
    $subDir    = $item.Sub
    $targetPath = Join-Path $MediaBasePath $subDir

    if (-not (Test-Path $targetPath)) {
        if (-not $CheckOnly) {
            New-Item -ItemType Directory -Path $targetPath -Force | Out-Null
            Write-Host "  [CREATED] Directory: $targetPath" -ForegroundColor Green
        } else {
            Write-Host "  [MISSING] Directory: $targetPath" -ForegroundColor Yellow
        }
    }

    $currentShare = Get-SmbShare -Name $shareName -ErrorAction SilentlyContinue

    if ($CheckOnly) {
        $status = if ($currentShare) {
            if ($currentShare.Path -eq $targetPath) { "CORRECT ($($currentShare.Path))" } else { "MISALIGNED ($($currentShare.Path))" }
        } else {
            "NOT_PROVISIONED"
        }
        $summaryTable += [PSCustomObject]@{
            ShareName   = $shareName
            TargetPath  = $targetPath
            CurrentPath = if ($currentShare) { $currentShare.Path } else { "-" }
            Status      = $status
        }
    } else {
        if ($currentShare -and ($currentShare.Path -ne $targetPath)) {
            try {
                Remove-SmbShare -Name $shareName -Force -ErrorAction Stop | Out-Null
                Write-Host "  [REPLACING] Share $shareName from old path $($currentShare.Path)..." -ForegroundColor Yellow
                $currentShare = $null
            } catch {
                Write-Host "  [WARN] Could not replace $($shareName): $($_.Exception.Message)" -ForegroundColor Red
            }
        }

        if (-not $currentShare) {
            try {
                New-SmbShare -Name $shareName -Path $targetPath -FullAccess @("Everyone", "Authenticated Users") -ErrorAction Stop | Out-Null
                Write-Host "  [ONLINE] Share $shareName -> $targetPath" -ForegroundColor Green
                $status = "CREATED_ONLINE"
            } catch {
                Write-Host "  [ERROR] Failed creating $($shareName): $($_.Exception.Message)" -ForegroundColor Red
                $status = "FAILED: $($_.Exception.Message)"
            }
        } else {
            Write-Host "  [OK] Share $shareName already correctly mapped -> $targetPath" -ForegroundColor Green
            $status = "ONLINE"
        }

        $summaryTable += [PSCustomObject]@{
            ShareName  = $shareName
            TargetPath = $targetPath
            Status     = $status
        }
    }
}

# 3. Output summary
Write-Host "`n[3/3] Network Shares Alignment Summary:" -ForegroundColor Yellow
$summaryTable | Format-Table -AutoSize | Out-String | Write-Host -ForegroundColor White

Write-Host "Completed. SMB Shares now point relative to: $MediaBasePath`n" -ForegroundColor Cyan
