<#
.SYNOPSIS
    Repair-BazarrServer.ps1 - Bazarr Subtitle Automation Diagnostic & Auto-Remediation Engine.

.DESCRIPTION
    Dedicated diagnostic and self-healing engine for Bazarr:
    1. Audits container status, crash loops, and restart counts on port 6767/tcp.
    2. Purges stale SQLite database locks (*.db-journal, *.db-shm, *.db-wal) in bazarr.db.
    3. Verifies and repairs config.yaml / config.xml settings.
    4. Re-synchronizes API keys with the Primary Secrets Vault.
    5. Probes REST API (/ping, /api/system/status).

.PARAMETER AutoFix
    Automatically executes fixes. Default: $true unless -DiagOnly is specified.

.PARAMETER DiagOnly
    Executes all diagnostics in read-only / simulation mode.

.PARAMETER Port
    HTTP listening port (default: 6767).

.EXAMPLE
    .\Repair-BazarrServer.ps1 -AutoFix
    .\Repair-BazarrServer.ps1 -DiagOnly
#>

[CmdletBinding()]
param(
    [switch]$AutoFix,
    [switch]$DiagOnly,
    [int]$Port = 6767
)

$servarrScript = Join-Path $PSScriptRoot "Repair-ServarrFleet.ps1"
$params = @{
    TargetService = "Bazarr"
}
if ($AutoFix) { $params["AutoFix"] = $true }
if ($DiagOnly) { $params["DiagOnly"] = $true }

& $servarrScript @params
