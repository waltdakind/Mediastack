<#
.SYNOPSIS
    Invoke-MediaStackAiCollaboration.ps1 - Master AI Collaboration Forwarder.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)][switch]$AutoRepair,
    [Parameter(Mandatory = $false)][bool]$SyncKnowledge = $true,
    [Parameter(Mandatory = $false)][switch]$Continuous,
    [Parameter(Mandatory = $false)][int]$IntervalSeconds = 15,
    [Parameter(Mandatory = $false)][bool]$Interactive = $true,
    [Parameter(Mandatory = $false)][switch]$NonInteractive,
    [Parameter(Mandatory = $false)][Alias("Stop", "Exit", "Conclude")][switch]$ExitSession,
    [Parameter(Mandatory = $false)][string]$ExitReason = "Operator requested collaboration exit",
    [Parameter(Mandatory = $false)][switch]$DryRun
)

$target = Join-Path $PSScriptRoot "invoke-files\Invoke-MediaStackAiCollaboration.ps1"
& $target @PSBoundParameters
