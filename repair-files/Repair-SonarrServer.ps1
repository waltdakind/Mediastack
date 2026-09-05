<#
.SYNOPSIS
    Repair-SonarrServer.ps1 - Sonarr TV Series Automation Diagnostic & Auto-Remediation Engine.

.DESCRIPTION
    Dedicated diagnostic and self-healing engine for Sonarr:
    1. Audits container status, crash loops, and restart counts on port 8989/tcp.
    2. Purges stale SQLite database locks (*.db-journal, *.db-shm, *.db-wal) in sonarr.db.
    3. Verifies and repairs config.xml (Port, UrlBase, AuthenticationMethod).
    4. Re-synchronizes API keys with the Primary Secrets Vault.
    5. Probes REST API (/ping, /api/v3/system/status).

.PARAMETER AutoFix
    Automatically executes fixes. Default: $true unless -DiagOnly is specified.

.PARAMETER DiagOnly
    Executes all diagnostics in read-only / simulation mode.

.PARAMETER Port
    HTTP listening port (default: 8989).

.EXAMPLE
    .\Repair-SonarrServer.ps1 -AutoFix
    .\Repair-SonarrServer.ps1 -DiagOnly
#>

[CmdletBinding()]
param(
    [switch]$AutoFix,
    [switch]$DiagOnly,
    [int]$Port = 8989
)

$servarrScript = Join-Path $PSScriptRoot "Repair-ServarrFleet.ps1"
$params = @{
    TargetService = "Sonarr"
}
if ($AutoFix) { $params["AutoFix"] = $true }
if ($DiagOnly) { $params["DiagOnly"] = $true }

& $servarrScript @params
