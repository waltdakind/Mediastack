# setup-shares.ps1 - Automated Reciprocal Read-Write Media Shares Setup
[CmdletBinding()]
param(
    [string]$MediaBasePath = "",
    [switch]$CheckOnly
)

$ErrorActionPreference = "Continue"

$provisioner = Join-Path $PSScriptRoot "Set-MediaStackNetworkUsers.ps1"
if (Test-Path $provisioner) {
    if ($MediaBasePath) {
        & $provisioner -MediaBasePath $MediaBasePath -CheckOnly:$CheckOnly
    } else {
        & $provisioner -CheckOnly:$CheckOnly
    }
} else {
    Write-Error "Set-MediaStackNetworkUsers.ps1 not found in $PSScriptRoot"
}

