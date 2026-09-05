<#
.SYNOPSIS
    Repair-JellyseerrServer.ps1 - Deprecated Wrapper for Seerr Repair Engine.

.DESCRIPTION
    Jellyseerr is deprecated upstream and has been succeeded by Seerr (ghcr.io/seerr-team/seerr).
    This script forwards all calls and parameters directly to Repair-SeerrServer.ps1.

.PARAMETER AutoFix
    Automatically executes fixes.

.PARAMETER DiagOnly
    Executes all diagnostics in read-only / simulation mode.

.PARAMETER Port
    HTTP listening port (default: 5055).

.PARAMETER ConfigDir
    Host directory for configuration.
#>

[CmdletBinding()]
param(
    [switch]$AutoFix,
    [switch]$DiagOnly,
    [int]$Port = 5055,
    [string]$ConfigDir = ""
)

Write-Host "`n[NOTICE] Jellyseerr is succeeded by Seerr (ghcr.io/seerr-team/seerr)." -ForegroundColor Yellow
Write-Host "         Forwarding diagnostics and repair directly to Repair-SeerrServer.ps1..." -ForegroundColor DarkGray

$seerrScript = Join-Path $PSScriptRoot "Repair-SeerrServer.ps1"
$params = @{}
if ($AutoFix) { $params["AutoFix"] = $true }
if ($DiagOnly) { $params["DiagOnly"] = $true }
if ($Port) { $params["Port"] = $Port }
if ($ConfigDir) { $params["ConfigDir"] = $ConfigDir }

& $seerrScript @params
