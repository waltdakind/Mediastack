<#
.SYNOPSIS
    Invoke-MediaStackMainLifecycle.ps1 - Master Main Lifecycle Forwarder.
#>
[CmdletBinding()]
param(
    [int]$IntervalSeconds = 60,
    [switch]$RunOnce,
    [switch]$Force,
    [switch]$NonInteractive
)

$target = Join-Path $PSScriptRoot "invoke-files\Invoke-MediaStackMainLifecycle.ps1"
& $target @PSBoundParameters
