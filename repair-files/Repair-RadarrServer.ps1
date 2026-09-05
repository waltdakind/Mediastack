<#
.SYNOPSIS
    Repair-RadarrServer.ps1 - Radarr Movie Automation Diagnostic & Auto-Remediation Engine.

.DESCRIPTION
    Dedicated diagnostic and self-healing engine for Radarr:
    1. Audits container status, crash loops, and restart counts on port 7878/tcp.
    2. Automatically executes deep crash loop remediation if container restart loop is detected.
    3. Purges stale SQLite database locks (*.db-journal, *.db-shm, *.db-wal) in radarr.db.
    4. Re-synchronizes API keys with the Primary Secrets Vault.
    5. Probes REST API (/ping, /api/v3/system/status).

.PARAMETER AutoFix
    Automatically executes fixes. Default: $true unless -DiagOnly is specified.

.PARAMETER DiagOnly
    Executes all diagnostics in read-only / simulation mode.

.PARAMETER Port
    HTTP listening port (default: 7878).

.EXAMPLE
    .\Repair-RadarrServer.ps1 -AutoFix
    .\Repair-RadarrServer.ps1 -DiagOnly
#>

[CmdletBinding()]
param(
    [switch]$AutoFix,
    [switch]$DiagOnly,
    [int]$Port = 7878
)

$inspect = docker inspect radarr 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
$restartCount = if ($inspect) { $inspect[0].RestartCount } else { 0 }

if ($restartCount -gt 5 -and ($AutoFix -or -not $DiagOnly)) {
    $crashScript = Join-Path $PSScriptRoot "Repair-RadarrCrashLoop.ps1"
    if (Test-Path $crashScript) {
        Write-Host "`n[ALERT] Elevated restart count ($restartCount) detected for Radarr." -ForegroundColor Yellow
        Write-Host "        Executing deep crash-loop remediation engine..." -ForegroundColor DarkYellow
        & $crashScript
    }
}

$servarrScript = Join-Path $PSScriptRoot "Repair-ServarrFleet.ps1"
$params = @{
    TargetService = "Radarr"
}
if ($AutoFix) { $params["AutoFix"] = $true }
if ($DiagOnly) { $params["DiagOnly"] = $true }

& $servarrScript @params
