<#
.SYNOPSIS
    Repair-VoltaireUnContainers.ps1 - Master Forwarder for VoltaireUn Container Reconciliation.
#>

[CmdletBinding()]
param(
    [switch]$Force
)

$targetScript = Join-Path $PSScriptRoot "repair-files\Repair-VoltaireUnContainers.ps1"
if (Test-Path $targetScript) {
    & $targetScript @PSBoundParameters
} else {
    Write-Error "Target script not found: $targetScript"
}
