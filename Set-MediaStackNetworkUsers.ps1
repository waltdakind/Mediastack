<#
.SYNOPSIS
    Set-MediaStackNetworkUsers.ps1 - Master Network Users Forwarder.
#>
[CmdletBinding()]
param(
    [switch]$CheckOnly,
    [string]$MediaBasePath = ""
)

$target = Join-Path $PSScriptRoot "setup-files\Set-MediaStackNetworkUsers.ps1"
& $target @PSBoundParameters
