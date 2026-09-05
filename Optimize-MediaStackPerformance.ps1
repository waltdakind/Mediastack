<#
.SYNOPSIS
    Optimize-MediaStackPerformance.ps1 - Master Optimization Suite Forwarder.

.DESCRIPTION
    Forwards calls to Invoke-MediaStackOptimizationSuite.ps1, referencing engines in optimize-files/.

.PARAMETER BenchmarkOnly
    Runs benchmark mode only.
#>

[CmdletBinding()]
param(
    [switch]$BenchmarkOnly
)

$suiteScript = Join-Path $PSScriptRoot "Invoke-MediaStackOptimizationSuite.ps1"
$params = @{}
if ($BenchmarkOnly) { $params["BenchmarkOnly"] = $true }
& $suiteScript @params
