<#
.SYNOPSIS
    Install-MediaStackUpdate.ps1 - Master Update Installer Forwarder.
#>
[CmdletBinding()]
param(
    [string]$ZipPath = "",
    [string]$TargetDir = "",
    [switch]$Force,
    [switch]$NonInteractive
)

$target = Join-Path $PSScriptRoot "update-files\Install-MediaStackUpdate.ps1"
& $target @PSBoundParameters
