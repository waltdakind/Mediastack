param(
    [switch]$CleanStart,
    [switch]$CleanShutdown,
    [switch]$FreshDeploy,
    [switch]$QuickStart,
    [switch]$AuditOnly
)

if ($CleanStart) {
    & "$PSScriptRoot\Invoke-MediaStackCleanStart.ps1" -FreshDeploy:$FreshDeploy
    exit $LASTEXITCODE
}

if ($CleanShutdown) {
    & "$PSScriptRoot\Invoke-MediaStackCleanShutdown.ps1"
    exit $LASTEXITCODE
}

& "$PSScriptRoot\Start-MediaStackFleet.ps1" @args
