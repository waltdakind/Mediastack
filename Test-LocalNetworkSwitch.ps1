<#
.SYNOPSIS
    Test-LocalNetworkSwitch.ps1 - Master Local Network Switch Forwarder.
#>
[CmdletBinding()]
param(
    [switch]$NonInteractive
)

$target = Join-Path $PSScriptRoot "test-files\Test-LocalNetworkSwitch.ps1"
& $target @PSBoundParameters
