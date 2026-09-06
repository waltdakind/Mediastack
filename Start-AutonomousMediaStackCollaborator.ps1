<#
.SYNOPSIS
    Start-AutonomousMediaStackCollaborator.ps1 - Master Autonomous Collaborator Forwarder.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)][int]$PollIntervalSeconds = 15,
    [Parameter(Mandatory=$false)][int]$FullAuditIntervalSeconds = 120,
    [Parameter(Mandatory=$false)][bool]$AutoExecuteRepairs = $true,
    [Parameter(Mandatory=$false)][Alias("Stop", "Exit", "Conclude")][switch]$ExitSession,
    [Parameter(Mandatory=$false)][string]$ExitReason = "Operator concluded autonomous AI collaboration",
    [Parameter(Mandatory=$false)][switch]$ExitOnPeerExit,
    [Parameter(Mandatory=$false)][int]$StandbyIntervalSeconds = 300,
    [Parameter(Mandatory=$false)][switch]$SinglePass
)

$target = Join-Path $PSScriptRoot "start-files\Start-AutonomousMediaStackCollaborator.ps1"
& $target @PSBoundParameters
