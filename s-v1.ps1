<#
.SYNOPSIS
    s-v1.ps1 - Instant Shortcut Launcher for VoltaireUn (Main 24/7 Media Server Node).

.DESCRIPTION
    Launches VoltaireUn Main Execution Suite with full error remediation,
    Kestrel socket deadlock clearance, SQLite WAL performance tuning,
    primary Caddy edge caching, and service liveness verification.

.EXAMPLE
    .\s-v1.ps1
    .\s-v1.ps1 -NonInteractive
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

$targetScript = if (Test-Path (Join-Path $PSScriptRoot "start-files\Start-VoltaireUnMainExecution.ps1")) {
    Join-Path $PSScriptRoot "start-files\Start-VoltaireUnMainExecution.ps1"
} elseif (Test-Path (Join-Path $PSScriptRoot "Start-VoltaireUnMainExecution.ps1")) {
    Join-Path $PSScriptRoot "Start-VoltaireUnMainExecution.ps1"
} else {
    Join-Path $PSScriptRoot "start-files\Start-VoltaireUnMainExecution.ps1"
}

if (Test-Path $targetScript) {
    & $targetScript -ExternalDomain $ExternalDomain -PrimaryIP $PrimaryIP -SecondaryIP $SecondaryIP -NonInteractive:$NonInteractive -SkipSentinel:$SkipSentinel -BenchmarkOnly:$BenchmarkOnly
} else {
    Write-Error "Start-VoltaireUnMainExecution.ps1 not found in $PSScriptRoot or $PSScriptRoot\start-files"
}
