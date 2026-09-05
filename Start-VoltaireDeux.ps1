<#
.SYNOPSIS
    Start-VoltaireDeux.ps1 - Master VoltaireDeux Startup Forwarder.
#>
[CmdletBinding()]
param(
    [switch]$SkipCaddy,
    [switch]$Force,
    [switch]$NonInteractive
)

$target = Join-Path $PSScriptRoot "start-files\Start-VoltaireDeux.ps1"
& $target @PSBoundParameters
