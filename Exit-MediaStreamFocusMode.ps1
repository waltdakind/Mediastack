<#
.SYNOPSIS
    Exit-MediaStreamFocusMode.ps1 - Immediate Exit for Media Streaming Focus & Full Fleet Resume.

.DESCRIPTION
    Restores frozen background containers, removes DND firewall restrictions,
    and signals peer nodes to resume regular standby operations.
#>
[CmdletBinding()]
param(
    [switch]$Elevate,
    [switch]$NonInteractive
)

$script = Join-Path $PSScriptRoot "Set-MediaStreamDoNotDisturb.ps1"
if (Test-Path $script) {
    & $script -Disable -Elevate:$Elevate -NonInteractive:$NonInteractive
} else {
    Write-Error "Set-MediaStreamDoNotDisturb.ps1 not found in $PSScriptRoot"
}
