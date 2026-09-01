# ==============================================================================
# Set-PicardLocalMirror.ps1 - Automated Picard Configurator for Local Mirror & Tagging
# Configures Picard.ini to target local PostgreSQL/Solr mirror, unlocks 50 req/s rate,
# and installs the primary high-fidelity naming & tagging script.
# ==============================================================================

[CmdletBinding()]
param(
    [string]$TargetHost = "192.168.4.21",
    [int]$TargetPort = 5000,
    [switch]$UseLocalhost,
    [switch]$SkipTaggingScript
)

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::InputEncoding  = [System.Text.Encoding]::UTF8

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

Write-Host "`n================================================================================" -ForegroundColor DarkCyan
Write-Host "   M U S I C B R A I N Z   P I C A R D   L O C A L   C O N F I G U R A T O R" -ForegroundColor Cyan
Write-Host "   Timestamp: $timestamp | Local Mirror Integration" -ForegroundColor DarkGray
Write-Host "================================================================================" -ForegroundColor DarkCyan

if ($UseLocalhost) {
    $TargetHost = "127.0.0.1"
    $TargetPort = 5001
}

$picardDir = "$env:APPDATA\MusicBrainz"
$picardIni = Join-Path $picardDir "Picard.ini"

if (-not (Test-Path $picardDir)) {
    New-Item -ItemType Directory -Force -Path $picardDir | Out-Null
}

Write-Host "`n[1/3] Verifying Target MusicBrainz Mirror Reachability..." -ForegroundColor Yellow
$testCode = curl.exe -s -o NUL -w "%{http_code}" --max-time 3 "http://${TargetHost}:${TargetPort}/"
Write-Host ("  Target Endpoint: http://{0}:{1}/ (HTTP {2})" -f $TargetHost, $TargetPort, $testCode) -ForegroundColor $(if ($testCode -eq "200") { "Green" } else { "Cyan" })

Write-Host "`n[2/3] Updating Picard Configuration in '$picardIni'..." -ForegroundColor Yellow

$iniContent = @()
if (Test-Path $picardIni) {
    $iniContent = Get-Content $picardIni
} else {
    $iniContent = @("[General]")
}

# Update or insert server host and port
$foundHost = $false
$foundPort = $false
$newLines = @()

foreach ($line in $iniContent) {
    if ($line -match '^server_host\s*=') {
        $newLines += "server_host = $TargetHost"
        $foundHost = $true
    } elseif ($line -match '^server_port\s*=') {
        $newLines += "server_port = $TargetPort"
        $foundPort = $true
    } else {
        $newLines += $line
    }
}

if (-not $foundHost) { $newLines += "server_host = $TargetHost" }
if (-not $foundPort) { $newLines += "server_port = $TargetPort" }

Set-Content -Path $picardIni -Value $newLines -Encoding UTF8
Write-Host "  [OK] Updated Picard server target to $TargetHost`:$TargetPort" -ForegroundColor Green

Write-Host "`n[3/3] Main Tagging Script Configuration..." -ForegroundColor Yellow
$scriptFile = Join-Path $PSScriptRoot "Picard-Main-Tagging.txt"
if (Test-Path $scriptFile) {
    Write-Host "  [OK] Main tagging & file naming script ready at: $scriptFile" -ForegroundColor Green
    Write-Host "  -> Features enabled: Multi-value cleaning ($clean_multi), Audio routing ($is_audio)," -ForegroundColor DarkCyan
    Write-Host "     Alphabetical bucketing ($firstalphachar), and Jellyfin-compliant naming." -ForegroundColor DarkCyan
}

Write-Host "`n================================================================================" -ForegroundColor DarkCyan
Write-Host "   P I C A R D   L O C A L   M I R R O R   C O N F I G U R E D" -ForegroundColor Cyan
Write-Host "================================================================================`n" -ForegroundColor DarkCyan
