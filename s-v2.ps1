<#
.SYNOPSIS
    s-v2.ps1 - Instant Shortcut Launcher for VoltaireDeux (AI Acceleration & Workstation Node).

.DESCRIPTION
    Launches VoltaireDeux Main Execution Suite with Ollama AI model verification,
    MusicBrainz secondary mirror (:5001), Picard batch tagger, sub-second LCP optimization,
    and cluster update synchronization.

.EXAMPLE
    .\s-v2.ps1
    .\s-v2.ps1 -NonInteractive
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)][string]$ExternalDomain = "waltdakind.xubi.org",
    [Parameter(Mandatory = $false)][string]$LocalIP = "192.168.4.30",
    [Parameter(Mandatory = $false)][string]$PrimaryIP = "192.168.4.21",
    [Parameter(Mandatory = $false)][switch]$NonInteractive,
    [Parameter(Mandatory = $false)][switch]$SkipAiWatcher
)

$targetScript = if (Test-Path (Join-Path $PSScriptRoot "start-files\Start-VoltaireDeuxMainExecution.ps1")) {
    Join-Path $PSScriptRoot "start-files\Start-VoltaireDeuxMainExecution.ps1"
} elseif (Test-Path (Join-Path $PSScriptRoot "Start-VoltaireDeuxMainExecution.ps1")) {
    Join-Path $PSScriptRoot "Start-VoltaireDeuxMainExecution.ps1"
} else {
    Join-Path $PSScriptRoot "start-files\Start-VoltaireDeuxMainExecution.ps1"
}

if (Test-Path $targetScript) {
    & $targetScript -ExternalDomain $ExternalDomain -LocalIP $LocalIP -PrimaryIP $PrimaryIP -NonInteractive:$NonInteractive -SkipAiWatcher:$SkipAiWatcher
} else {
    Write-Error "Start-VoltaireDeuxMainExecution.ps1 not found in $PSScriptRoot or $PSScriptRoot\start-files"
}
