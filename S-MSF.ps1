<#
.SYNOPSIS
    Shortened Launcher for Start-MediaStackFleet.ps1 (S-MSF)
.DESCRIPTION
    Quick shortcut alias to execute the Primary MediaStack Fleet startup,
    published port enforcer, database integrity sentinel, and operational console.
#>

[CmdletBinding()]
param (
    [Parameter(ValueFromRemainingArguments = $true)]
    $PassthroughArgs
)

$script = Join-Path $PSScriptRoot "Start-MediaStackFleet.ps1"
if (Test-Path $script) {
    & $script @args
} else {
    Write-Error "Could not find Start-MediaStackFleet.ps1 in $PSScriptRoot"
}
