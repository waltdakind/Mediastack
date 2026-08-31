<#
.SYNOPSIS
    Start-VoltaireUnAiSentinel.ps1 - Fast Launcher for VoltaireUn 24/7 AI Sentinel.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)][switch]$Continuous,
    [Parameter(Mandatory = $false)][int]$IntervalSeconds = 30,
    [Parameter(Mandatory = $false)][switch]$AutoRepair = $true,
    [Parameter(Mandatory = $false)][string]$VoltaireDeuxIP = "192.168.4.30"
)

$targetScript = Join-Path $PSScriptRoot "Invoke-VoltaireUnAiSentinel.ps1"
if (Test-Path $targetScript) {
    & $targetScript -Continuous:$Continuous -IntervalSeconds $IntervalSeconds -AutoRepair:$AutoRepair -VoltaireDeuxIP $VoltaireDeuxIP
} else {
    Write-Error "Invoke-VoltaireUnAiSentinel.ps1 not found in $PSScriptRoot"
}
