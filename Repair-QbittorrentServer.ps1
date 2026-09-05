# Forwarder to repair-files/Repair-QbittorrentServer.ps1
param(
    [switch]$AutoFix,
    [switch]$DiagOnly,
    [int]$Port = 8085,
    [string]$ConfigDir = ".\config\qbittorrent"
)
$scriptPath = Join-Path $PSScriptRoot "repair-files\Repair-QbittorrentServer.ps1"
if (Test-Path $scriptPath) {
    & $scriptPath @PSBoundParameters
} else {
    Write-Error "Target script not found: $scriptPath"
}
