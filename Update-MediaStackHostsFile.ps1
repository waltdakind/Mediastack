<#
.SYNOPSIS
    Update-MediaStackHostsFile.ps1 - Master Hosts File Update Forwarder.
#>
[CmdletBinding()]
param()

$target = Join-Path $PSScriptRoot "update-files\Update-MediaStackHostsFile.ps1"
& $target @PSBoundParameters
