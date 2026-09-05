<#
.SYNOPSIS
    s-sync.ps1 - Fast Priority Cluster Sync Forwarder.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)][string]$PrimaryIP = "192.168.4.21",
    [Parameter(Mandatory = $false)][string]$SecondaryIP = "192.168.4.30",
    [Parameter(Mandatory = $false)][string]$ExternalDomain = "waltdakind.xubi.org",
    [Parameter(Mandatory = $false)][switch]$NonInteractive
)

$target = Join-Path $PSScriptRoot "sync-files\s-sync.ps1"
& $target @PSBoundParameters
