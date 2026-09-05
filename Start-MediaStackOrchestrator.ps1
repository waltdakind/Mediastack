<#
.SYNOPSIS
    Start-MediaStackOrchestrator.ps1 - Master Orchestrator Startup Forwarder.
#>
[CmdletBinding()]
param(
    [switch]$NonInteractive
)

$target = Join-Path $PSScriptRoot "start-files\Start-MediaStackOrchestrator.ps1"
& $target @PSBoundParameters
