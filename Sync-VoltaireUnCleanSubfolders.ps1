# Forwarder to sync-files/Sync-VoltaireUnCleanSubfolders.ps1
param(
    [switch]$DryRun,
    [switch]$Force
)
$scriptPath = Join-Path $PSScriptRoot "sync-files\Sync-VoltaireUnCleanSubfolders.ps1"
if (Test-Path $scriptPath) {
    & $scriptPath @PSBoundParameters
} else {
    Write-Error "Target script not found: $scriptPath"
}
