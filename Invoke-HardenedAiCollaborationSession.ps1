<#
.SYNOPSIS
    Invoke-HardenedAiCollaborationSession.ps1 - Master Hardened AI Session Forwarder.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)][int]$TargetScore = 100,
    [Parameter(Mandatory=$false)][int]$MaxIterations = 30,
    [Parameter(Mandatory=$false)][int]$PollIntervalSeconds = 8,
    [Parameter(Mandatory=$false)][bool]$AutoRepair = $true,
    [Parameter(Mandatory=$false)][Alias("Stop", "Exit", "Conclude")][switch]$ExitSession,
    [Parameter(Mandatory=$false)][string]$ExitReason = "Operator concluded hardened AI collaboration session",
    [Parameter(Mandatory=$false)][switch]$Continuous
)

$target = Join-Path $PSScriptRoot "invoke-files\Invoke-HardenedAiCollaborationSession.ps1"
& $target @PSBoundParameters
