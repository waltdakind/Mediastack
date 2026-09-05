<#
.SYNOPSIS
    Repair-MediaStackFleet.ps1 - Master Fleet Repair Entrypoint (Suite Forwarder).

.DESCRIPTION
    Launches the master MediaStack repair suite orchestrator (Invoke-MediaStackRepairSuite.ps1)
    and dispatches diagnostics and remediation to specialized engines in repair-files/.

.PARAMETER Service
    Target service to repair ("All", "Jellyfin", "MusicBrainz", "Servarr", "Caddy", "Syncthing", "LiveTV", "Seerr", "Jellyseerr", "Transmission", etc.). Default: "All".

.PARAMETER AutoFix
    Automatically executes remediation steps.

.PARAMETER DiagOnly
    Executes diagnostics in read-only / simulation mode.

.PARAMETER All
    Executes complete fleet repair sweep.
#>

[CmdletBinding()]
param(
    [string]$Service = "All",
    [switch]$All,
    [switch]$AutoFix,
    [switch]$DiagOnly
)

$suiteScript = Join-Path $PSScriptRoot "Invoke-MediaStackRepairSuite.ps1"
$params = @{}
if ($All -or $Service -eq "All") { $params["All"] = $true } else { $params["Service"] = $Service }
if ($AutoFix) { $params["AutoFix"] = $true }
if ($DiagOnly) { $params["DiagOnly"] = $true }

& $suiteScript @params
