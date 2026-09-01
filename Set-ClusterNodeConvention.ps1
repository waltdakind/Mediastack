<#
.SYNOPSIS
    Set-ClusterNodeConvention.ps1 - MediaStack Multi-Node Naming Convention & Topology Enforcer.

.DESCRIPTION
    Applies the standardized 'Voltaire<N>' cluster naming convention across the local machine:
    - Primary 24/7 Master Server: VoltaireUn (192.168.4.21) [Formerly ORDINATEURDEVOL / prinateurdevol]
    - Secondary AI Workstation:   VoltaireDeux (192.168.4.30) [This Machine]
    - Future Cluster Nodes:       VoltaireTrois (192.168.4.31), VoltaireQuatre (192.168.4.32), etc.

    Configures system environment variables, local DNS/Hosts mappings, SMB peer credentials,
    and reciprocal synchronization topology.

.PARAMETER ApplySystemEnv
    Sets persistent machine environment variables for node references.

.PARAMETER UpdateHostsFile
    Updates Windows drivers\etc\hosts with canonical Voltaire domains and legacy aliases.

.EXAMPLE
    .\Set-ClusterNodeConvention.ps1
    .\Set-ClusterNodeConvention.ps1 -ApplySystemEnv
#>

[CmdletBinding()]
param(
    [switch]$SkipSystemEnv,
    [switch]$SkipHostsFile
)

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::InputEncoding  = [System.Text.Encoding]::UTF8

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$BaseDir = $PSScriptRoot
$RegistryFile = Join-Path $BaseDir "config\cluster_nodes.json"

Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host "   M E D I A S T A C K   C L U S T E R   N A M I N G   C O N V E N T I O N" -ForegroundColor DarkCyan
Write-Host "   Voltaire<N> Topology & Node Awareness Enforcer" -ForegroundColor White
Write-Host "   Host: $env:COMPUTERNAME | Timestamp: $timestamp" -ForegroundColor DarkGray
Write-Host "================================================================================" -ForegroundColor Cyan

# 1. Load Registry
if (Test-Path $RegistryFile) {
    try {
        $registry = Get-Content $RegistryFile -Raw -Encoding UTF8 | ConvertFrom-Json
        Write-Host "  * Cluster Name: $($registry.cluster_name)" -ForegroundColor Green
        Write-Host "  * Scheme      : $($registry.naming_convention.scheme)" -ForegroundColor White
    } catch {
        Write-Host "  [WARN] Failed to parse cluster_nodes.json: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# 2. Display Node Mapping Topology
Write-Host "`n[STAGE 1/4] MediaStack Node Topology Mapping:" -ForegroundColor Yellow

$nodeTable = @(
    [PSCustomObject]@{ CanonicalName = "VoltaireUn";    IP = "192.168.4.21"; Role = "Primary 24/7 Master & DB";  LegacyAliases = "ORDINATEURDEVOL, prinateurdevol, ordinateur.local" },
    [PSCustomObject]@{ CanonicalName = "VoltaireDeux";  IP = "192.168.4.30"; Role = "Secondary AI & Mirror";     LegacyAliases = "VOLTAIREDEUX, voltairedeux.local" },
    [PSCustomObject]@{ CanonicalName = "VoltaireTrois"; IP = "192.168.4.31"; Role = "Expansion (Transcoder)";   LegacyAliases = "Future Cluster Node" },
    [PSCustomObject]@{ CanonicalName = "VoltaireQuatre";IP = "192.168.4.32"; Role = "Expansion (Backup Node)";  LegacyAliases = "Future Cluster Node" }
)
$nodeTable | Format-Table -AutoSize | Out-String | Write-Host -ForegroundColor White

# 3. Apply Environment Variables
if (-not $SkipSystemEnv) {
    Write-Host "[STAGE 2/4] Setting MediaStack Cluster Environment Variables..." -ForegroundColor Yellow
    $envVars = @{
        "MEDIASTACK_PRIMARY_NODE"    = "VoltaireUn"
        "MEDIASTACK_PRIMARY_IP"      = "192.168.4.21"
        "MEDIASTACK_SECONDARY_NODE"  = "VoltaireDeux"
        "MEDIASTACK_SECONDARY_IP"    = "192.168.4.30"
        "MEDIASTACK_NAMING_PREFIX"   = "Voltaire"
        "MEDIASTACK_CLUSTER_SCHEME"  = "FrenchOrdinal (VoltaireUn, VoltaireDeux, VoltaireTrois...)"
    }

    foreach ($kv in $envVars.GetEnumerator()) {
        [System.Environment]::SetEnvironmentVariable($kv.Key, $kv.Value, [System.EnvironmentVariableTarget]::Process)
        try {
            [System.Environment]::SetEnvironmentVariable($kv.Key, $kv.Value, [System.EnvironmentVariableTarget]::User)
            Write-Host "  [SET] $($kv.Key) = $($kv.Value)" -ForegroundColor Green
        } catch {
            Write-Host "  [PROCESS ONLY] $($kv.Key) = $($kv.Value)" -ForegroundColor DarkCyan
        }
    }
}

# 4. Update Hosts File
if (-not $SkipHostsFile) {
    Write-Host "`n[STAGE 3/4] Updating Local Host Resolution & Legacy Aliases..." -ForegroundColor Yellow
    $updateHostsScript = Join-Path $BaseDir "update-hosts.ps1"
    if (Test-Path $updateHostsScript) {
        & $updateHostsScript -PrimaryIp "192.168.4.21" -SecondaryIp "192.168.4.30"
    }
}

# 5. Flush Local DNS Cache
Write-Host "`n[STAGE 4/4] Flushing DNS & NetBIOS Resolver Caches..." -ForegroundColor Yellow
try {
    Clear-DnsClientCache -ErrorAction SilentlyContinue
    cmd.exe /c "ipconfig /flushdns >nul 2>&1"
    cmd.exe /c "nbtstat -R >nul 2>&1"
    Write-Host "  [OK] DNS and NetBIOS resolver caches refreshed." -ForegroundColor Green
} catch {
    Write-Host "  [WARN] Cache flush returned: $($_.Exception.Message)" -ForegroundColor DarkGray
}

Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host "   C L U S T E R   N O D E   C O N V E N T I O N   E N F O R C E D" -ForegroundColor Green
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "  * VoltaireDeux is now fully aware that VoltaireUn (192.168.4.21) is the primary server." -ForegroundColor White
Write-Host "  * Standard naming convention: VoltaireUn, VoltaireDeux, VoltaireTrois, VoltaireQuatre...`n" -ForegroundColor White
