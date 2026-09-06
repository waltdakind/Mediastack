<#
.SYNOPSIS
    Stop-MediaStackAiCollaboration.ps1 - Direct AI Collaboration Exit & Sentinel Termination Trigger.

.DESCRIPTION
    Broadcasts a clean session conclusion signal across the cluster (handoffs/ai_collaboration_nexus.json),
    notifying both VoltaireDeux and VoltaireUn to conclude any active AI collaboration sprints,
    terminate frequent polling loops, and transition back to quiescent standby mode.

.PARAMETER Reason
    Optional explanation for why the collaboration session is being concluded.

.EXAMPLE
    .\Stop-MediaStackAiCollaboration.ps1
    .\Stop-MediaStackAiCollaboration.ps1 -Reason "Completed dual-node optimization sprint"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)][string]$Reason = "Operator executed Stop-MediaStackAiCollaboration"
)

$target = Join-Path $PSScriptRoot "invoke-files\Invoke-MediaStackAiCollaboration.ps1"
& $target -ExitSession -ExitReason $Reason
