<#
.SYNOPSIS
    Start-MediaStackAiWatcher.ps1 - Background/Foreground AI Collaboration Monitor & Reactor.

.DESCRIPTION
    Launches the real-time AI Collaboration Sentinel in continuous monitoring mode.
    Listens for telemetry, error logs, and handoff reports emitted by VoltaireUn,
    automatically executing deep stack optimization, database sanitation, and
    pushing synthesized updates back to VoltaireUn.

.PARAMETER IntervalSeconds
    Polling interval in seconds between checks. Default is 15 seconds.

.EXAMPLE
    .\Start-MediaStackAiWatcher.ps1
    .\Start-MediaStackAiWatcher.ps1 -IntervalSeconds 10
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)][int]$IntervalSeconds = 15
)

$scriptPath = Join-Path $PSScriptRoot "Invoke-MediaStackAiCollaboration.ps1"
& $scriptPath -Continuous -IntervalSeconds $IntervalSeconds -AutoRepair -NonInteractive
