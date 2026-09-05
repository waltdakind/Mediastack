<#
.SYNOPSIS
    Start-MediaStack.ps1 - Master Control Panel Startup Forwarder.
#>
[CmdletBinding()]
param()

$target = Join-Path $PSScriptRoot "start-files\Start-MediaStack.ps1"
& $target @PSBoundParameters
