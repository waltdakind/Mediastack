<#
.SYNOPSIS
    Publish-VoltaireDeuxUpdates.ps1 - Master VoltaireDeux Updates Forwarder.
#>
[CmdletBinding()]
param(
    [string]$Message = "",
    [switch]$SkipPortTest,
    [switch]$DryRun,
    [switch]$Force,
    [switch]$NonInteractive
)

$target = Join-Path $PSScriptRoot "update-files\Publish-VoltaireDeuxUpdates.ps1"
& $target @PSBoundParameters
