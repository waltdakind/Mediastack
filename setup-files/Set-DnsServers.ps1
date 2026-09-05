<#
.SYNOPSIS
    Configures preferred DNS nameservers (1.1.1.1 and 8.8.8.8) on active network adapters.
.DESCRIPTION
    Sets Cloudflare (1.1.1.1) as Primary and Google (8.8.8.8) as Secondary DNS.
    Includes IPv6 addresses by default and flushes the DNS resolver cache.
.PARAMETER ResetToDHCP
    Reverts DNS configuration back to automatic DHCP.
.PARAMETER InterfaceAlias
    Specifies a specific adapter (e.g. 'Wi-Fi' or 'Ethernet'). If omitted, all active adapters are configured.
#>

[CmdletBinding()]
param (
    [Parameter()]
    [string]$InterfaceAlias,

    [Parameter()]
    [switch]$ResetToDHCP,

    [Parameter()]
    [switch]$IPv4Only
)

$ErrorActionPreference = 'Stop'

# Ensure script is running with Administrator privileges
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "[WARNING] This script requires Administrator privileges to modify network adapter settings." -ForegroundColor Yellow
    Write-Host "          Attempting to elevate privileges..." -ForegroundColor Yellow
    Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

Clear-Host
Write-Host "=========================================================" -ForegroundColor DarkCyan
Write-Host "      D N S   N A M E S E R V E R   C O N F I G U R E R" -ForegroundColor Cyan
Write-Host "=========================================================" -ForegroundColor DarkCyan
Write-Host ""

# Get active network adapters (filtering out virtual/loopback adapters)
$adapters = Get-NetAdapter | Where-Object { 
    $_.Status -eq 'Up' -and 
    $_.Virtual -eq $false -and 
    $_.InterfaceAlias -notmatch 'Loopback|vEthernet|Virtual|Bluetooth' 
}

if ($InterfaceAlias) {
    $adapters = $adapters | Where-Object { $_.InterfaceAlias -eq $InterfaceAlias }
}

if (-not $adapters -or $adapters.Count -eq 0) {
    Write-Host "[ERROR] No active physical network adapters found to configure." -ForegroundColor Red
    exit 1
}

if ($ResetToDHCP) {
    Write-Host "Resetting DNS settings to Automatic (DHCP)..." -ForegroundColor Yellow
    foreach ($adapter in $adapters) {
        Write-Host " -> Resetting DNS on adapter: $($adapter.InterfaceAlias) ($($adapter.InterfaceDescription))" -ForegroundColor Cyan
        Set-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -ResetServerAddresses
    }
} else {
    $dnsServers = if ($IPv4Only) {
        @('1.1.1.1', '8.8.8.8', '1.0.0.1', '8.8.4.4')
    } else {
        @('1.1.1.1', '8.8.8.8', '2606:4700:4700::1111', '2001:4860:4860::8888')
    }

    Write-Host "Applying Preferred DNS Servers:" -ForegroundColor Yellow
    Write-Host " -> Primary DNS   : 1.1.1.1 (Cloudflare)" -ForegroundColor Green
    Write-Host " -> Secondary DNS : 8.8.8.8 (Google)" -ForegroundColor Green
    if (-not $IPv4Only) {
        Write-Host " -> Primary IPv6  : 2606:4700:4700::1111 (Cloudflare)" -ForegroundColor DarkGray
        Write-Host " -> Secondary IPv6: 2001:4860:4860::8888 (Google)" -ForegroundColor DarkGray
    }
    Write-Host ""

    foreach ($adapter in $adapters) {
        Write-Host " -> Configuring adapter: $($adapter.InterfaceAlias) ($($adapter.InterfaceDescription))..." -ForegroundColor Cyan
        try {
            Set-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -ServerAddresses $dnsServers
            Write-Host "    [SUCCESS] Updated DNS for $($adapter.InterfaceAlias)" -ForegroundColor Green
        } catch {
            Write-Host "    [FAILED] Could not update $($adapter.InterfaceAlias): $_" -ForegroundColor Red
        }
    }
}

# Flush DNS cache to ensure immediate activation
Write-Host "`nFlushing local DNS resolver cache..." -ForegroundColor Yellow
Clear-DnsClientCache
Write-Host " -> DNS Cache flushed." -ForegroundColor Green

# Display current configuration
Write-Host "`n=========================================================" -ForegroundColor Cyan
Write-Host "             CURRENT DNS CONFIGURATION" -ForegroundColor Green
Write-Host "=========================================================" -ForegroundColor Cyan

foreach ($adapter in $adapters) {
    $currentDns = Get-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex
    $ipv4Dns = ($currentDns | Where-Object { $_.AddressFamily -eq 2 }).ServerAddresses -join ', '
    $ipv6Dns = ($currentDns | Where-Object { $_.AddressFamily -eq 23 }).ServerAddresses -join ', '
    
    Write-Host "Adapter: $($adapter.InterfaceAlias)" -ForegroundColor Cyan
    Write-Host " - IPv4 DNS: $(if ($ipv4Dns) { $ipv4Dns } else { 'Automatic (DHCP)' })" -ForegroundColor White
    Write-Host " - IPv6 DNS: $(if ($ipv6Dns) { $ipv6Dns } else { 'Automatic (DHCP)' })" -ForegroundColor White
    Write-Host ""
}

Write-Host "Testing connectivity with new DNS servers..." -ForegroundColor Yellow
try {
    $testResult = Resolve-DnsName -Name "waltdakind.xubi.org" -ErrorAction Stop
    Write-Host " -> DNS resolution test for 'waltdakind.xubi.org': SUCCESS" -ForegroundColor Green
    $testResult | Select-Object Name, Type, IPAddress | Format-Table -AutoSize
} catch {
    Write-Host " -> DNS resolution test warning: $_" -ForegroundColor Yellow
}
