<#
.SYNOPSIS
    mediastack-ops.ps1 - Legacy Compatibility Wrapper for MediaStackOps.ps1 / MediaStackOps.psm1
#>
$opsModule = Join-Path $PSScriptRoot "MediaStackOps.psm1"
if (Test-Path $opsModule) {
    Import-Module $opsModule -Force
} else {
    . (Join-Path $PSScriptRoot "MediaStackOps.ps1")
}
