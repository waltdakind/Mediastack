<#
.SYNOPSIS
    Invoke-MediaStackCleanStart.ps1 - Master Clean Start Forwarder.
#>
[CmdletBinding()]
param(
    [switch]$SkipDrain,
    [switch]$Force,
    [switch]$NonInteractive
)

$target = Join-Path $PSScriptRoot "invoke-files\Invoke-MediaStackCleanStart.ps1"
& $target @PSBoundParameters
