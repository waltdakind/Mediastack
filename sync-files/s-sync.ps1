<#
.SYNOPSIS
    s-sync.ps1 - Fast Launcher for Priority Cluster Sync (VoltaireDeux First, then VoltaireUn).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)][string]$PrimaryIP = "192.168.4.21",
    [Parameter(Mandatory = $false)][string]$SecondaryIP = "192.168.4.30",
    [Parameter(Mandatory = $false)][string]$ExternalDomain = "waltdakind.xubi.org",
    [Parameter(Mandatory = $false)][switch]$NonInteractive
)

$targetScript = Join-Path $PSScriptRoot "Sync-MediaStackPriorityHandoffs.ps1"
if (Test-Path $targetScript) {
    & $targetScript -PrimaryIP $PrimaryIP -SecondaryIP $SecondaryIP -ExternalDomain $ExternalDomain -NonInteractive:$NonInteractive
} else {
    Write-Error "Sync-MediaStackPriorityHandoffs.ps1 not found in $PSScriptRoot"
}
