# Set-DnsServers.ps1 - Configure Network DNS Nameservers to 8.8.8.8 and 1.1.1.1
param(
    [string[]]$DnsServers = @("8.8.8.8", "1.1.1.1"),
    [switch]$ResetToDhcp,
    [switch]$IncludeVirtualAdapters = $false
)

$ErrorActionPreference = "Continue"

Write-Host "`n=======================================================" -ForegroundColor Cyan
Write-Host "       W I N D O W S   D N S   M A N A G E R" -ForegroundColor Cyan
Write-Host "=======================================================" -ForegroundColor Cyan

# 1. Check Administrator Privileges
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Warning "Modifying network DNS settings requires Administrator privileges."
    Write-Host "`nTo run automatically with elevated rights, launch PowerShell as Administrator and run:" -ForegroundColor Yellow
    Write-Host "  powershell.exe -ExecutionPolicy Bypass -File .\Set-DnsServers.ps1`n" -ForegroundColor Cyan
}

# 2. Get Active Adapters
$adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }

if (-not $IncludeVirtualAdapters) {
    $adapters = $adapters | Where-Object { $_.InterfaceAlias -notlike "*WSL*" -and $_.InterfaceAlias -notlike "*Hyper-V*" }
}

if (-not $adapters) {
    Write-Warning "No active physical network adapters found."
    exit 1
}

Write-Host "Active Adapters Found:" -ForegroundColor Yellow
foreach ($adapter in $adapters) {
    Write-Host "  • $($adapter.InterfaceAlias) (Status: $($adapter.Status), Speed: $($adapter.LinkSpeed))" -ForegroundColor DarkCyan
}

# 3. Apply DNS Configuration
foreach ($adapter in $adapters) {
    $alias = $adapter.InterfaceAlias
    Write-Host "`nConfiguring Adapter: '$alias'..." -ForegroundColor Cyan

    if ($ResetToDhcp) {
        Write-Host "  Resetting DNS to automatic (DHCP)..." -ForegroundColor Yellow
        try {
            Set-DnsClientServerAddress -InterfaceAlias $alias -ResetServerAddresses -ErrorAction Stop
            Write-Host "  [OK] Reset to DHCP successfully." -ForegroundColor Green
        } catch {
            Write-Warning "  Could not reset via Set-DnsClientServerAddress: $_"
            netsh interface ipv4 set dns name="$alias" dhcp | Out-Null
        }
    } else {
        Write-Host "  Setting DNS servers to: $($DnsServers -join ', ')..." -ForegroundColor Yellow
        try {
            Set-DnsClientServerAddress -InterfaceAlias $alias -ServerAddresses $DnsServers -ErrorAction Stop
            Write-Host "  [OK] Applied DNS server addresses via Set-DnsClientServerAddress." -ForegroundColor Green
        } catch {
            Write-Warning "  Set-DnsClientServerAddress failed (requires elevation): $_"
            Write-Host "  Attempting fallback via netsh..." -ForegroundColor DarkGray
            try {
                netsh interface ipv4 set dns name="$alias" static $DnsServers[0] primary | Out-Null
                if ($DnsServers.Count -gt 1) {
                    netsh interface ipv4 add dns name="$alias" $DnsServers[1] index=2 | Out-Null
                }
                Write-Host "  [OK] Applied DNS via netsh." -ForegroundColor Green
            } catch {
                Write-Error "  Failed to apply DNS servers on '$alias': $_"
            }
        }
    }
}

# 4. Flush Local DNS Resolver Cache
Write-Host "`nFlushing local DNS resolver cache..." -ForegroundColor Yellow
try {
    Clear-DnsClientCache
    Write-Host "[OK] DNS cache cleared successfully." -ForegroundColor Green
} catch {
    ipconfig /flushdns | Out-Null
    Write-Host "[OK] DNS cache flushed via ipconfig." -ForegroundColor Green
}

# 5. Verify & Display Current Configuration
Write-Host "`n--- Active DNS Server Verification ---" -ForegroundColor Cyan
foreach ($adapter in $adapters) {
    $alias = $adapter.InterfaceAlias
    $currentDns = Get-DnsClientServerAddress -InterfaceAlias $alias -AddressFamily IPv4 -ErrorAction SilentlyContinue
    $dnsList = if ($currentDns.ServerAddresses) { $currentDns.ServerAddresses -join ", " } else { "Automatic (DHCP)" }
    Write-Host "  • Adapter '$alias': DNS = $dnsList" -ForegroundColor Green
}

Write-Host "`n=======================================================" -ForegroundColor Cyan
Write-Host "   D N S   C O N F I G U R A T I O N   C O M P L E T E" -ForegroundColor Cyan
Write-Host "=======================================================`n" -ForegroundColor Cyan
