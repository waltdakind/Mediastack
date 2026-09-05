<#
.SYNOPSIS
    Merge-OneDriveMediaStack.ps1 - Master OneDrive Merger Forwarder.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)][string]$OneDrivePath = "C:\Users\waltd\OneDrive\Mediastack",
    [Parameter(Mandatory=$false)][string]$LocalConfigPath = "$env:SystemDrive\MediastackConfig",
    [Parameter(Mandatory=$false)][bool]$PurgeStaleConflictFiles = $true,
    [Parameter(Mandatory=$false)][bool]$CreateBackupArchive = $true
)

$target = Join-Path $PSScriptRoot "sync-files\Merge-OneDriveMediaStack.ps1"
& $target @PSBoundParameters
