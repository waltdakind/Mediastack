<#
.SYNOPSIS
    Sync-MediaStackDatabases.ps1 - Master Databases Sync Forwarder.
#>
[CmdletBinding()]
param(
    [int]$IntervalSeconds = 300,
    [switch]$RunOnce,
    [switch]$PreSyncBackupOnly,
    [string]$ConfigDir = "$env:SystemDrive\MediastackConfig",
    [string]$BackupRoot = ""
)

$target = Join-Path $PSScriptRoot "sync-files\Sync-MediaStackDatabases.ps1"
& $target @PSBoundParameters
