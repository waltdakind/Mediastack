<#
.SYNOPSIS
    Test-MediaStackSslViability.ps1 - Master SSL Viability Forwarder.
#>
[CmdletBinding()]
param(
    [switch]$ForceRegenerate,
    [switch]$NonInteractive
)

$target = Join-Path $PSScriptRoot "test-files\Test-MediaStackSslViability.ps1"
& $target @PSBoundParameters
