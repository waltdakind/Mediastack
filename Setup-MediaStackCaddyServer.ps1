<#
.SYNOPSIS
    Setup-MediaStackCaddyServer.ps1 - Master Caddy Server Setup Forwarder.
#>
[CmdletBinding()]
param(
    [string]$PrimaryServerIP = "192.168.4.21",
    [string]$SecondaryServerIP = "192.168.4.30",
    [string]$ExternalDomain = "waltdakind.xubi.org",
    [switch]$ForceRecreateCerts,
    [switch]$InstallRootCA,
    [switch]$NonInteractive
)

$targetScript = Join-Path $PSScriptRoot "setup-files\Setup-MediaStackCaddyServer.ps1"
$params = @{}
if ($PrimaryServerIP) { $params["PrimaryServerIP"] = $PrimaryServerIP }
if ($SecondaryServerIP) { $params["SecondaryServerIP"] = $SecondaryServerIP }
if ($ExternalDomain) { $params["ExternalDomain"] = $ExternalDomain }
if ($ForceRecreateCerts) { $params["ForceRecreateCerts"] = $true }
if ($InstallRootCA) { $params["InstallRootCA"] = $true }
if ($NonInteractive) { $params["NonInteractive"] = $true }

& $targetScript @params
