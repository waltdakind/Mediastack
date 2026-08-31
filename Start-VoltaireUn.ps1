<#
.SYNOPSIS
    Start-VoltaireUn.ps1 - Fast Launcher for VoltaireUn Master Execution Suite.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)][string]$ExternalDomain = "waltdakind.xubi.org",
    [Parameter(Mandatory = $false)][string]$PrimaryIP = "192.168.4.21",
    [Parameter(Mandatory = $false)][string]$SecondaryIP = "192.168.4.30",
    [Parameter(Mandatory = $false)][switch]$NonInteractive,
    [Parameter(Mandatory = $false)][switch]$SkipSentinel,
    [Parameter(Mandatory = $false)][switch]$BenchmarkOnly
)

$targetScript = Join-Path $PSScriptRoot "Start-VoltaireUnMasterExecution.ps1"
if (Test-Path $targetScript) {
    & $targetScript -ExternalDomain $ExternalDomain -PrimaryIP $PrimaryIP -SecondaryIP $SecondaryIP -NonInteractive:$NonInteractive -SkipSentinel:$SkipSentinel -BenchmarkOnly:$BenchmarkOnly
} else {
    Write-Error "Start-VoltaireUnMasterExecution.ps1 not found in $PSScriptRoot"
}
