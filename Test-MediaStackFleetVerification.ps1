<#
.SYNOPSIS
    Test-MediaStackFleetVerification.ps1 - Master Fleet Verification Forwarder.
#>
[CmdletBinding()]
param(
    [string]$Service = "All",
    [switch]$All,
    [switch]$Fast,
    [switch]$NonInteractive
)

$target = Join-Path $PSScriptRoot "test-files\Test-MediaStackFleetVerification.ps1"
& $target @PSBoundParameters
