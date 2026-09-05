<#
.SYNOPSIS
    Invoke-MediaStackClusterHandoff.ps1 - Cross-Node Update Checker & System Status Handoff Generator.

.DESCRIPTION
    1. Generates an exhaustive system status and architecture handoff Markdown report and JSON manifest.
    2. Details container statuses, port probes, SQLite database health, and discovered errors.
    3. Formulates peer AI suggestions for stability, self-healing, and error handling for databases
       and services running on the other computer in the network (VoltaireUn vs VoltaireDeux).
    4. Inspects incoming peer handoff files and checks for pending updates on GitHub and OneDrive.
    5. Optionally triggers immediate updates and database synchronization.

.PARAMETER Interactive
    Prompts the user interactively to apply updates and return to caller. Default is $true.

.PARAMETER NonInteractive
    Runs quietly without pausing for key presses, suitable for automated background triggers.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)][bool]$Interactive = $true,
    [Parameter(Mandatory=$false)][switch]$NonInteractive
)

$BaseDir = $PSScriptRoot
$opsModule = Join-Path $BaseDir "MediaStackOps.psm1"
if (Test-Path $opsModule) {
    Import-Module $opsModule -Force
} else {
    . (Join-Path $BaseDir "MediaStackOps.ps1")
}

$isInteractive = if ($NonInteractive) { $false } else { $Interactive }
Invoke-MediaStackClusterUpdateCheck -Interactive $isInteractive
