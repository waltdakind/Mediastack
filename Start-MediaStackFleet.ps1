<#
.SYNOPSIS
    Start-MediaStackFleet.ps1 - Master Fleet Startup Forwarder.
#>
[CmdletBinding()]
param(
    [switch]$Interactive,
    [switch]$ForcePortKill,
    [switch]$SkipIntegrityCheck,
    [switch]$Fast,
    [switch]$Repair,
    [switch]$AuditOnly
)

$target = Join-Path $PSScriptRoot "start-files\Start-MediaStackFleet.ps1"
& $target @PSBoundParameters
