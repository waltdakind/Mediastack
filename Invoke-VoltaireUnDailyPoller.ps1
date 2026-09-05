# Forwarder to invoke-files/Invoke-VoltaireUnDailyPoller.ps1
param(
    [switch]$ForceSync,
    [switch]$DryRun,
    [int]$IntervalHours = 24,
    [switch]$Loop,
    [switch]$Once,
    [switch]$Force,
    [switch]$NonInteractive
)
$scriptPath = Join-Path $PSScriptRoot "invoke-files\Invoke-VoltaireUnDailyPoller.ps1"
if (Test-Path $scriptPath) {
    & $scriptPath @PSBoundParameters
} else {
    Write-Error "Target script not found: $scriptPath"
}
