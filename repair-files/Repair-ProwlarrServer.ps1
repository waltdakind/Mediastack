<#
.SYNOPSIS
    Repair-ProwlarrServer.ps1 - Prowlarr Indexer Automation Diagnostic & Auto-Remediation Engine.

.DESCRIPTION
    Dedicated diagnostic and self-healing engine for Prowlarr:
    1. Audits container status, crash loops, and restart counts on port 9696/tcp.
    2. Purges stale SQLite database locks (*.db-journal, *.db-shm, *.db-wal) in prowlarr.db.
    3. Verifies and repairs config.xml (Port, UrlBase, AuthenticationMethod).
    4. Re-synchronizes API keys with the Primary Secrets Vault.
    5. Probes REST API (/ping, /api/v1/system/status).

.PARAMETER AutoFix
    Automatically executes fixes. Default: $true unless -DiagOnly is specified.

.PARAMETER DiagOnly
    Executes all diagnostics in read-only / simulation mode.

.PARAMETER Port
    HTTP listening port (default: 9696).

.EXAMPLE
    .\Repair-ProwlarrServer.ps1 -AutoFix
    .\Repair-ProwlarrServer.ps1 -DiagOnly
#>

[CmdletBinding()]
param(
    [switch]$AutoFix,
    [switch]$DiagOnly,
    [int]$Port = 9696
)

$servarrScript = Join-Path $PSScriptRoot "Repair-ServarrFleet.ps1"
$params = @{
    TargetService = "Prowlarr"
}
if ($AutoFix) { $params["AutoFix"] = $true }
if ($DiagOnly) { $params["DiagOnly"] = $true }

& $servarrScript @params
