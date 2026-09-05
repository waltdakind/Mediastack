<#
.SYNOPSIS
    Invoke-MediaStackFullRebootSuite.ps1 - Master Full Reboot Suite Forwarder.
#>
[CmdletBinding()]
param(
    [switch]$SkipStateSnapshot,
    [switch]$SkipDrain,
    [switch]$Force,
    [switch]$NonInteractive
)

$target = Join-Path $PSScriptRoot "invoke-files\Invoke-MediaStackFullRebootSuite.ps1"
& $target @PSBoundParameters
