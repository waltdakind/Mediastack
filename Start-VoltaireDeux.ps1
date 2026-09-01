<#
.SYNOPSIS
    Start-VoltaireDeux.ps1 - Fast Launcher for VoltaireDeux Main Execution Suite.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)][string]$ExternalDomain = "waltdakind.xubi.org",
    [Parameter(Mandatory = $false)][string]$LocalIP = "192.168.4.30",
    [Parameter(Mandatory = $false)][string]$PrimaryIP = "192.168.4.21",
    [Parameter(Mandatory = $false)][switch]$NonInteractive,
    [Parameter(Mandatory = $false)][switch]$SkipAiWatcher
)

$targetScript = Join-Path $PSScriptRoot "Start-VoltaireDeuxMainExecution.ps1"
if (Test-Path $targetScript) {
    & $targetScript -ExternalDomain $ExternalDomain -LocalIP $LocalIP -PrimaryIP $PrimaryIP -NonInteractive:$NonInteractive -SkipAiWatcher:$SkipAiWatcher
} else {
    Write-Error "Start-VoltaireDeuxMainExecution.ps1 not found in $PSScriptRoot"
}
