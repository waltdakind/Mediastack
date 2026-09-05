<#
.SYNOPSIS
    Set-MediaStackHostSafeguards.ps1 - Master Host Safeguards Forwarder.
#>
[CmdletBinding()]
param(
    [switch]$ApplyPowerPolicies = $true,
    [switch]$InstallScheduledTasks = $true,
    [switch]$NonInteractive
)

$target = Join-Path $PSScriptRoot "setup-files\Set-MediaStackHostSafeguards.ps1"
& $target @PSBoundParameters
