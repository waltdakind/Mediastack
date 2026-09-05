<#
.SYNOPSIS
    Invoke-MediaStackCleanShutdown.ps1 - Master Clean Shutdown Forwarder.
#>
[CmdletBinding()]
param(
    [switch]$Force,
    [switch]$NonInteractive
)

$target = Join-Path $PSScriptRoot "invoke-files\Invoke-MediaStackCleanShutdown.ps1"
& $target @PSBoundParameters
