<#
.SYNOPSIS
    Replicate-MediaStackCluster.ps1 - Master Cluster Replication Forwarder.
#>
[CmdletBinding()]
param(
    [string]$Service = "All",
    [switch]$All,
    [string]$TargetNode = "VoltaireUn",
    [string]$TargetIp = "192.168.4.21",
    [switch]$RunOnce
)

$suiteScript = Join-Path $PSScriptRoot "Invoke-MediaStackReplicationSuite.ps1"
$params = @{}
if ($All -or $Service -eq "All") { $params["All"] = $true } else { $params["Scope"] = $Service }
if ($TargetNode) { $params["TargetNode"] = $TargetNode }
if ($TargetIp) { $params["TargetIp"] = $TargetIp }
if ($RunOnce) { $params["RunOnce"] = $true }

& $suiteScript @params
