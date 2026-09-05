<#
.SYNOPSIS
    Setup-Qbittorrent.ps1 - Root forwarder to setup-files/Setup-Qbittorrent.ps1
#>
[CmdletBinding()]
param(
    [int]$Port = 8085,
    [int]$TorrentPort = 6881,
    [string]$ConfigDir = ".\config\qbittorrent",
    [string]$DownloadDir = ".\data\downloads",
    [switch]$NoStart,
    [switch]$NonInteractive
)

$targetScript = Join-Path $PSScriptRoot "setup-files\Setup-Qbittorrent.ps1"
if (Test-Path $targetScript) {
    & $targetScript @PSBoundParameters
} else {
    Write-Error "Target script not found: $targetScript"
}
