<#
.SYNOPSIS
    Start-VoltaireUn.ps1 - Master VoltaireUn Startup Forwarder.
#>
[CmdletBinding()]
param(
    [switch]$SkipHardware,
    [switch]$Fast,
    [switch]$Force,
    [switch]$NonInteractive
)

$target = Join-Path $PSScriptRoot "start-files\Start-VoltaireUn.ps1"
& $target @PSBoundParameters
