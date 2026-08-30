$ErrorActionPreference = 'Stop'
$BaseDir = "$PSScriptRoot"
$bazarrYamlPath = "$BaseDir\bazarr\config\config\config.yaml"
$jseerrJsonPath = "$BaseDir\jellyseerr\config\settings.json"

Clear-Host
Write-Host "=========================================================" -ForegroundColor DarkCyan
Write-Host "  M E D I A S T A C K   F U L L   A U T O M A T I O N" -ForegroundColor Cyan
Write-Host "  Connecting Bazarr and Jellyseerr to Sonarr & Radarr" -ForegroundColor DarkGray
Write-Host "=========================================================" -ForegroundColor DarkCyan
Write-Host ""

Write-Host "1. Extracting API Keys from Configurations..." -ForegroundColor Yellow
try {
    $sonarrXml = [xml](Get-Content -Path "$BaseDir\sonarr\config\config.xml")
    $sonarrKey = $sonarrXml.Config.ApiKey
    Write-Host "   -> Sonarr API Key extracted." -ForegroundColor Green
} catch { Write-Host "   -> FAILED to extract Sonarr API key." -ForegroundColor Red; exit }

try {
    $radarrXml = [xml](Get-Content -Path "$BaseDir\radarr\config\config.xml")
    $radarrKey = $radarrXml.Config.ApiKey
    Write-Host "   -> Radarr API Key extracted." -ForegroundColor Green
} catch { Write-Host "   -> FAILED to extract Radarr API key." -ForegroundColor Red; exit }

Write-Host "`n2. Stopping Bazarr and Jellyseerr..." -ForegroundColor Yellow
Set-Location -Path $BaseDir
docker compose stop bazarr jellyseerr | Out-Null
Write-Host "   -> Containers stopped." -ForegroundColor Green

Write-Host "`n3. Modifying Jellyseerr Settings..." -ForegroundColor Yellow
if (Test-Path $jseerrJsonPath) {
    $settings = Get-Content $jseerrJsonPath -Raw | ConvertFrom-Json 

    $newRadarr = @{
        id = 0
        name = "Radarr"
        hostname = "radarr"
        port = 7878
        apiKey = $radarrKey
        useSsl = $false
        baseUrl = ""
        activeProfileId = 1
        activeProfileName = "Any"
        activeDirectory = "/movies"
        is4k = $false
        minimumAvailability = "announced"
        isDefault = $true
        externalUrl = ""
        syncEnabled = $true
        preventSearch = $false
    }

    $newSonarr = @{
        id = 0
        name = "Sonarr"
        hostname = "sonarr"
        port = 8989
        apiKey = $sonarrKey
        useSsl = $false
        baseUrl = ""
        activeProfileId = 1
        activeProfileName = "Any"
        activeDirectory = "/tv"
        is4k = $false
        enableSeasonFolders = $true
        isDefault = $true
        externalUrl = ""
        syncEnabled = $true
        preventSearch = $false
    }
    
    $settings.radarr = @($newRadarr)
    $settings.sonarr = @($newSonarr)

    $settings | ConvertTo-Json  | Set-Content $jseerrJsonPath
    Write-Host "   -> Jellyseerr integration successful!" -ForegroundColor Green
} else {
    Write-Host "   -> Jellyseerr settings not found!" -ForegroundColor Red
}

Write-Host "`n4. Modifying Bazarr Settings..." -ForegroundColor Yellow
if (Test-Path $bazarrYamlPath) {
    $lines = Get-Content $bazarrYamlPath
    $inRadarr = $false
    $inSonarr = $false
    for ($i=0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match "^\s*use_radarr:") { $lines[$i] = "  use_radarr: true" }
        if ($lines[$i] -match "^\s*use_sonarr:") { $lines[$i] = "  use_sonarr: true" }
        
        if ($lines[$i] -match "^radarr:") { $inRadarr = $true; $inSonarr = $false; continue }
        if ($lines[$i] -match "^sonarr:") { $inSonarr = $true; $inRadarr = $false; continue }
        if ($lines[$i] -match "^[a-z]") { $inRadarr = $false; $inSonarr = $false }
        
        if ($inRadarr) {
            if ($lines[$i] -match "^\s+apikey:") { $lines[$i] = "    apikey: '$radarrKey'" }
            if ($lines[$i] -match "^\s+ip:") { $lines[$i] = "    ip: radarr" }
        }
        if ($inSonarr) {
            if ($lines[$i] -match "^\s+apikey:") { $lines[$i] = "    apikey: '$sonarrKey'" }
            if ($lines[$i] -match "^\s+ip:") { $lines[$i] = "    ip: sonarr" }
        }
    }
    $lines | Set-Content $bazarrYamlPath
    Write-Host "   -> Bazarr integration successful!" -ForegroundColor Green
} else {
    Write-Host "   -> Bazarr config not found!" -ForegroundColor Red
}

Write-Host "`n5. Starting Bazarr and Jellyseerr..." -ForegroundColor Yellow
docker compose start bazarr jellyseerr | Out-Null
Write-Host "   -> Containers are back online!" -ForegroundColor Green

Write-Host "`n=========================================================" -ForegroundColor DarkCyan
Write-Host "Configuration Complete!" -ForegroundColor Green
Write-Host "Your MediaStack is now fully automated and linked." -ForegroundColor White
Write-Host "Press any key to exit..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
