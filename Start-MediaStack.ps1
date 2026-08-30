<#
.SYNOPSIS
    MediaStack Primary Entry Point
.DESCRIPTION
    Launches the Primary Stack Orchestrator with Database Integrity, Caddy Routing, Image Cleanup, and Self-Healing.
#>

[CmdletBinding()]
param (
    [Parameter()]
    [switch]$Once,

    [Parameter()]
    [switch]$Monitor = $true,

    [Parameter()]
    [int]$IntervalSec = 30,

    [Parameter()]
    [switch]$SkipCleanup
)

$primaryScript = Join-Path $PSScriptRoot "Start-PrimaryStack.ps1"
if (Test-Path $primaryScript) {
    & $primaryScript @PSBoundParameters
} else {
    Write-Host "[ERROR] Start-PrimaryStack.ps1 not found in $PSScriptRoot" -ForegroundColor Red
}
