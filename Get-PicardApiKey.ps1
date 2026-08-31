<#
.SYNOPSIS
    Get-PicardApiKey.ps1 - Retrieves, Audits & Manages MusicBrainz Picard & AcoustID API Keys.

.DESCRIPTION
    Extracts the active AcoustID API key, MusicBrainz OAuth credentials, and server
    configuration from Picard.ini and the persistent MediaStack secrets store.
#>
[CmdletBinding()]
param(
    [string]$AcoustIdKey,
    [string]$OAuthToken,
    [string]$Username,
    [switch]$Save
)

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::InputEncoding  = [System.Text.Encoding]::UTF8

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host "   M U S I C B R A I N Z   P I C A R D   A P I   K E Y   M A N A G E R" -ForegroundColor DarkCyan
Write-Host "   Timestamp: $timestamp" -ForegroundColor DarkGray
Write-Host "================================================================================" -ForegroundColor Cyan

$picardIniPath = "$env:APPDATA\MusicBrainz\Picard.ini"
$secretsJsonPath = "$PSScriptRoot\config\picard\picard_api_keys.json"

$currentAcoustId = "4wzgif6hwM"
$currentOAuth = ""
$currentUser = "waltdakind"
$currentServer = "192.168.4.21:5000"

if (Test-Path $picardIniPath) {
    $iniLines = Get-Content $picardIniPath
    foreach ($l in $iniLines) {
        if ($l -match '^acoustid_apikey=(.+)$') { $currentAcoustId = $matches[1].Trim() }
        if ($l -match '^oauth_access_token=(.+)$') { $currentOAuth = $matches[1].Trim() }
        if ($l -match '^oauth_username=(.+)$') { $currentUser = $matches[1].Trim() }
        if ($l -match '^server_host=(.+)$') { $hostPart = $matches[1].Trim() }
        if ($l -match '^server_port=(.+)$') { $portPart = $matches[1].Trim(); $currentServer = "${hostPart}:${portPart}" }
    }
}

if ($AcoustIdKey) { $currentAcoustId = $AcoustIdKey; $Save = $true }
if ($OAuthToken) { $currentOAuth = $OAuthToken; $Save = $true }
if ($Username) { $currentUser = $Username; $Save = $true }

Write-Host "`n[1/2] Active MusicBrainz Picard Credentials & Endpoints:" -ForegroundColor Yellow
Write-Host ("  • AcoustID API Key (Fingerprinting) : {0}" -f $currentAcoustId) -ForegroundColor Green
Write-Host ("  • MusicBrainz OAuth Username        : {0}" -f $currentUser) -ForegroundColor Green
Write-Host ("  • MusicBrainz OAuth Access Token    : {0}" -f $(if ($currentOAuth) { $currentOAuth } else { "[Public / Local Mirror Mode (No Token Required)]" })) -ForegroundColor $(if ($currentOAuth) { "Green" } else { "DarkGray" })
Write-Host ("  • Active MusicBrainz Target Mirror  : http://{0}/" -f $currentServer) -ForegroundColor Cyan
Write-Host ("  • Picard Configuration File         : {0}" -f $picardIniPath) -ForegroundColor DarkGray

if ($Save) {
    Write-Host "`n[2/2] Persisting Keys to Picard.ini and Secrets Store..." -ForegroundColor Yellow
    
    $secretObj = [ordered]@{
        service                = "MusicBrainz Picard"
        username               = $currentUser
        acoustid_apikey        = $currentAcoustId
        oauth_access_token     = $currentOAuth
        local_mirror_primary   = "http://192.168.4.21:5000"
        local_mirror_secondary = "http://127.0.0.1:5001"
        public_endpoint        = "https://musicbrainz.org"
        updated_at             = $timestamp
    }
    
    $parentDir = Split-Path $secretsJsonPath -Parent
    if (-not (Test-Path $parentDir)) { New-Item -ItemType Directory -Force -Path $parentDir | Out-Null }
    $secretObj | ConvertTo-Json -Depth 5 | Set-Content -Path $secretsJsonPath -Encoding UTF8
    Write-Host ("  [OK] Saved to: {0}" -f $secretsJsonPath) -ForegroundColor Green
    
    # Update Picard.ini if exists
    if (Test-Path $picardIniPath) {
        $lines = Get-Content $picardIniPath
        $hasAcoust = $false
        $outLines = @()
        foreach ($line in $lines) {
            if ($line -match '^acoustid_apikey=') {
                $outLines += "acoustid_apikey=$currentAcoustId"
                $hasAcoust = $true
            } elseif ($line -match '^oauth_username=') {
                $outLines += "oauth_username=$currentUser"
            } elseif ($line -match '^oauth_access_token=') {
                if ($currentOAuth) { $outLines += "oauth_access_token=$currentOAuth" }
            } else {
                $outLines += $line
            }
        }
        if (-not $hasAcoust) {
            $outLines += "acoustid_apikey=$currentAcoustId"
        }
        $outLines | Set-Content -Path $picardIniPath -Encoding UTF8
        Write-Host ("  [OK] Updated Picard.ini with AcoustID API Key.") -ForegroundColor Green
    }
}

Write-Host "`n================================================================================`n" -ForegroundColor Cyan
