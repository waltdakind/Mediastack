$ErrorActionPreference = 'Stop'
$BaseDir = "$PSScriptRoot"

Clear-Host
Write-Host "=========================================================" -ForegroundColor DarkCyan
Write-Host "  M E D I A S T A C K   A U T O - C O N F I G" -ForegroundColor Cyan
Write-Host "  Connecting Jackett and Transmission to Sonarr & Radarr" -ForegroundColor DarkGray
Write-Host "=========================================================" -ForegroundColor DarkCyan
Write-Host ""

Write-Host "1. Checking if containers are accessible..." -ForegroundColor Yellow
try {
    $null = Invoke-RestMethod -Uri "http://localhost:8989" -Method Get -ErrorAction Stop
    $null = Invoke-RestMethod -Uri "http://localhost:7878" -Method Get -ErrorAction Stop
    Write-Host "   -> Containers are online!" -ForegroundColor Green
} catch {
    Write-Host "   -> ERROR: Unable to reach Sonarr or Radarr on localhost. Please ensure Docker is running and your MediaStack is started (Option 2 in Control Room)." -ForegroundColor Red
    exit
}

Write-Host "`n2. Extracting API Keys from Configurations..." -ForegroundColor Yellow
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

try {
    $jackettJson = Get-Content -Raw "$BaseDir\config\jackett\Jackett\ServerConfig.json" | ConvertFrom-Json
    $jackettKey = $jackettJson.APIKey
    Write-Host "   -> Jackett API Key extracted." -ForegroundColor Green
} catch { Write-Host "   -> FAILED to extract Jackett API key." -ForegroundColor Red; exit }

$Headers = @{
    "Content-Type" = "application/json"
    "Accept" = "application/json"
}

Write-Host "`n3. Configuring Radarr..." -ForegroundColor Yellow

$radarrTransBody = @{
    name = "Transmission"
    enable = $true
    protocol = "torrent"
    priority = 1
    removeCompletedDownloads = $true
    removeFailedDownloads = $true
    implementation = "Transmission"
    configContract = "TransmissionSettings"
    fields = @(
        @{ name = "host"; value = "transmission" },
        @{ name = "port"; value = 9091 },
        @{ name = "urlBase"; value = "/transmission/" },
        @{ name = "username"; value = "" },
        @{ name = "password"; value = "" },
        @{ name = "category"; value = "" },
        @{ name = "useSsl"; value = $false }
    )
} | ConvertTo-Json -Depth 5

$Headers["X-Api-Key"] = $radarrKey
try {
    Invoke-RestMethod -Uri "http://localhost:7878/api/v3/downloadclient" -Method Post -Headers $Headers -Body $radarrTransBody | Out-Null
    Write-Host "   -> Transmission added to Radarr." -ForegroundColor Green
} catch { Write-Host "   -> Note: Transmission might already exist in Radarr or the API request failed." -ForegroundColor DarkGray }

$radarrJackettBody = @{
    name = "Jackett All"
    enableRss = $true
    enableAutomaticSearch = $true
    enableInteractiveSearch = $true
    supportsRss = $true
    supportsSearch = $true
    protocol = "torrent"
    priority = 25
    implementation = "Torznab"
    configContract = "TorznabSettings"
    fields = @(
        @{ name = "baseUrl"; value = "http://jackett:9117/api/v2.0/indexers/all/results/torznab/" },
        @{ name = "apiPath"; value = "/api" },
        @{ name = "apiKey"; value = $jackettKey },
        @{ name = "categories"; value = @(2000, 2010, 2020, 2030, 2040, 2045, 2050, 2060) }
    )
} | ConvertTo-Json -Depth 5

try {
    Invoke-RestMethod -Uri "http://localhost:7878/api/v3/indexer" -Method Post -Headers $Headers -Body $radarrJackettBody | Out-Null
    Write-Host "   -> Jackett Torznab Indexer added to Radarr." -ForegroundColor Green
} catch { Write-Host "   -> Note: Jackett indexer might already exist in Radarr." -ForegroundColor DarkGray }


Write-Host "`n4. Configuring Sonarr..." -ForegroundColor Yellow

$Headers["X-Api-Key"] = $sonarrKey

try {
    Invoke-RestMethod -Uri "http://localhost:8989/api/v3/downloadclient" -Method Post -Headers $Headers -Body $radarrTransBody | Out-Null
    Write-Host "   -> Transmission added to Sonarr." -ForegroundColor Green
} catch { Write-Host "   -> Note: Transmission might already exist in Sonarr." -ForegroundColor DarkGray }

$sonarrJackettBody = @{
    name = "Jackett All"
    enableRss = $true
    enableAutomaticSearch = $true
    enableInteractiveSearch = $true
    supportsRss = $true
    supportsSearch = $true
    protocol = "torrent"
    priority = 25
    implementation = "Torznab"
    configContract = "TorznabSettings"
    fields = @(
        @{ name = "baseUrl"; value = "http://jackett:9117/api/v2.0/indexers/all/results/torznab/" },
        @{ name = "apiPath"; value = "/api" },
        @{ name = "apiKey"; value = $jackettKey },
        @{ name = "categories"; value = @(5000, 5010, 5020, 5030, 5040, 5050, 5080) }
    )
} | ConvertTo-Json -Depth 5

try {
    Invoke-RestMethod -Uri "http://localhost:8989/api/v3/indexer" -Method Post -Headers $Headers -Body $sonarrJackettBody | Out-Null
    Write-Host "   -> Jackett Torznab Indexer added to Sonarr." -ForegroundColor Green
} catch { Write-Host "   -> Note: Jackett indexer might already exist in Sonarr." -ForegroundColor DarkGray }


Write-Host "`n=========================================================" -ForegroundColor DarkCyan
Write-Host "Configuration Complete!" -ForegroundColor Green
Write-Host "Jackett and Transmission are now fully integrated into the Arrs." -ForegroundColor White
Write-Host "Press any key to exit..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
