<#
.SYNOPSIS
    Restore-MediaStackConfig.ps1 - Master Restore Suite Forwarder.
#>
[CmdletBinding()]
param(
    [string]$FromBackup = "",
    [switch]$Force,
    [switch]$SkipDockerStart
)

$suiteScript = Join-Path $PSScriptRoot "Invoke-MediaStackRestoreSuite.ps1"
$params = @{}
if ($FromBackup) { $params["FromBackup"] = $FromBackup }
if ($Force) { $params["Force"] = $true }
if ($SkipDockerStart) { $params["SkipDockerStart"] = $true }

& $suiteScript @params
