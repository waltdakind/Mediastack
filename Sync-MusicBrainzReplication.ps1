<#
.SYNOPSIS
    Sync-MusicBrainzReplication.ps1 - Master MusicBrainz Replication Forwarder.
#>
[CmdletBinding()]
param(
    [string]$ReplicationToken = "",
    [string]$PrimaryHost = "127.0.0.1",
    [int]$PrimaryPort = 5001,
    [string]$FallbackHost = "192.168.4.21",
    [int]$FallbackPort = 5000,
    [switch]$ForceSync,
    [switch]$SkipReport
)

$target = Join-Path $PSScriptRoot "sync-files\Sync-MusicBrainzReplication.ps1"
& $target @PSBoundParameters
