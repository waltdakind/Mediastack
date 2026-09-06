<#
.SYNOPSIS
    Enter-MediaStreamFocusMode.ps1 - Fast Launcher for Cinema Streaming Focus & Do Not Disturb.

.DESCRIPTION
    Suspends AI sprints, background pollers, and heavy background Docker tasks
    to dedicate 100% of host and network bandwidth to smooth, uninterrupted media playback.
#>
[CmdletBinding()]
param(
    [switch]$Elevate,
    [switch]$NonInteractive
)

$script = Join-Path $PSScriptRoot "Set-MediaStreamDoNotDisturb.ps1"
if (Test-Path $script) {
    & $script -Enable -Elevate:$Elevate -NonInteractive:$NonInteractive
} else {
    Write-Error "Set-MediaStreamDoNotDisturb.ps1 not found in $PSScriptRoot"
}
