<#
.SYNOPSIS
    Sync-VoltaireUnFeatureParity.ps1 - Master VoltaireUn Parity Forwarder.
#>
[CmdletBinding()]
param(
    [switch]$CheckOnly,
    [switch]$SkipHardware,
    [switch]$Force,
    [switch]$NonInteractive
)

$target = Join-Path $PSScriptRoot "sync-files\Sync-VoltaireUnFeatureParity.ps1"
& $target @PSBoundParameters
