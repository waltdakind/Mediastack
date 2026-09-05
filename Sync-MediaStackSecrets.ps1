<#
.SYNOPSIS
    Sync-MediaStackSecrets.ps1 - Master Secrets Sync Forwarder.
#>
[CmdletBinding()]
param(
    [switch]$Audit,
    [switch]$SyncLocal,
    [string]$MetaBrainzToken,
    [string]$AcoustIdKey,
    [string]$JellyWatchCode,
    [string]$GenerateEnvNode,
    [string]$RemoteNodeIP,
    [switch]$SkipReport
)

$target = Join-Path $PSScriptRoot "sync-files\Sync-MediaStackSecrets.ps1"
& $target @PSBoundParameters
