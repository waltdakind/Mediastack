<#
.SYNOPSIS
    Test-MediaStackApis.ps1 - Master API Verification Forwarder.
#>
[CmdletBinding()]
param(
    [string]$ConfigDir = "$env:SystemDrive\MediastackConfig",
    [switch]$AutoUpdateEnv,
    [switch]$SkipReport
)

$target = Join-Path $PSScriptRoot "test-files\Test-MediaStackApis.ps1"
& $target @PSBoundParameters
