<#
.SYNOPSIS
    Test-MediaStackFleetConnectivity.ps1 - Master Fleet Connectivity Forwarder.
#>
[CmdletBinding()]
param(
    [switch]$All,
    [switch]$DeepAuth,
    [string]$Service = "All"
)

$target = Join-Path $PSScriptRoot "test-files\Test-MediaStackFleetConnectivity.ps1"
& $target @PSBoundParameters
