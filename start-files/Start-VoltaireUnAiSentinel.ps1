<#
.SYNOPSIS
    Start-VoltaireUnAiSentinel.ps1 - Fast Launcher for VoltaireUn 24/7 AI Sentinel.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)][switch]$Continuous,
    [Parameter(Mandatory = $false)][int]$IntervalSeconds = 30,
    [Parameter(Mandatory = $false)][switch]$AutoRepair = $true,
    [Parameter(Mandatory = $false)][string]$VoltaireDeuxIP = "192.168.4.30"
)

# ==============================================================================
# CLUSTER MACHINE VERIFICATION
# ==============================================================================
function Assert-ClusterNodeTarget {
    param(
        [Parameter(Mandatory=$true)][string]$ExpectedNode,
        [switch]$Force,
        [switch]$NonInteractive
    )
    $currentHost = $env:COMPUTERNAME
    $isMatch = $false
    if ($ExpectedNode -match "VoltaireDeux") {
        $isMatch = ($currentHost -match "VoltaireDeux" -or $currentHost -match "Laptop" -or $env:NODE_ROLE -eq "VoltaireDeux")
    } elseif ($ExpectedNode -match "VoltaireUn") {
        $isMatch = ($currentHost -match "VoltaireUn" -or $currentHost -match "Ordinateur" -or $currentHost -match "Server" -or $env:NODE_ROLE -eq "VoltaireUn")
    } else {
        $isMatch = ($currentHost -like "*$ExpectedNode*")
    }

    if ($Force -or $env:MEDIASTACK_FORCE_NODE -or $isMatch) { return }

    Write-Host ""
    Write-Host "================================================================================" -ForegroundColor Red
    Write-Host " [WARNING] CLUSTER MACHINE MISMATCH DETECTED" -ForegroundColor Yellow
    Write-Host "================================================================================" -ForegroundColor Red
    Write-Host (" Target Machine Requirement : [{0}]" -f $ExpectedNode) -ForegroundColor Cyan
    Write-Host (" Current Local Hostname      : [{0}]" -f $currentHost) -ForegroundColor Yellow
    Write-Host " You are running a script designed specifically for another node in the cluster." -ForegroundColor Red
    Write-Host " Proceeding on the wrong machine may disrupt cluster synchronization or services." -ForegroundColor DarkYellow
    Write-Host "--------------------------------------------------------------------------------" -ForegroundColor DarkGray

    $isNonInteractive = $NonInteractive -or ($PSBoundParameters.ContainsKey('NonInteractive') -and $PSBoundParameters['NonInteractive']) -or ($MyInvocation.Line -match '-NonInteractive')

    if ($isNonInteractive) {
        Write-Host " [ABORT] Non-interactive run on incorrect cluster machine. Exiting." -ForegroundColor Red
        Write-Host " Use -Force or set $env:MEDIASTACK_FORCE_NODE=1 to bypass.
" -ForegroundColor DarkGray
        exit 1
    }

    Write-Host " Options:" -ForegroundColor White
    Write-Host "  [C] Cancel and exit immediately (Recommended to protect cluster state)" -ForegroundColor Green
    Write-Host "  [P] Proceed anyway (Override machine check on current host)" -ForegroundColor DarkYellow
    Write-Host ""
    $choice = Read-Host " Enter choice [C/P] (Default: C)"
    if ($choice -ne "P" -and $choice -ne "p") {
        Write-Host "
 [EXITED] Operation cancelled by user.
" -ForegroundColor DarkGray
        exit 0
    }
    Write-Host "
 [OVERRIDE] Proceeding on current machine ($currentHost) as requested.
" -ForegroundColor Yellow
}
Assert-ClusterNodeTarget -ExpectedNode "VoltaireUn" -Force:$Force -NonInteractive:$NonInteractive

$targetScript = Join-Path $PSScriptRoot "Invoke-VoltaireUnAiSentinel.ps1"
if (Test-Path $targetScript) {
    & $targetScript -Continuous:$Continuous -IntervalSeconds $IntervalSeconds -AutoRepair:$AutoRepair -VoltaireDeuxIP $VoltaireDeuxIP
} else {
    Write-Error "Invoke-VoltaireUnAiSentinel.ps1 not found in $PSScriptRoot"
}




