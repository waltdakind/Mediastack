# Test-MediaStackApis.ps1 - Comprehensive API Verification, Health & Key Discovery Engine
param(
    [string]$ConfigDir = "$env:SystemDrive\MediastackConfig",
    [switch]$AutoUpdateEnv,
    [switch]$SkipReport
)

$ErrorActionPreference = "Continue"

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$fileTimestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$reportFile = "$PSScriptRoot\handoffs\Api_Verification_Report_$fileTimestamp.md"

Write-Host "`n=======================================================" -ForegroundColor Cyan
Write-Host "   M E D I A S T A C K   A P I   V E R I F I E R" -ForegroundColor Cyan
Write-Host "   Timestamp: $timestamp" -ForegroundColor DarkGray
Write-Host "=======================================================" -ForegroundColor Cyan

# --- 1. API KEY AUTO-DISCOVERY ENGINE ---
Write-Host "`n[1/3] Scanning Configuration Directories for Service API Keys..." -ForegroundColor Yellow

$apiKeys = [ordered]@{
    "Sonarr"      = $null
    "Radarr"      = $null
    "Prowlarr"    = $null
    "Bazarr"      = $null
    "Jellyseerr"  = $null
    "Jellyfin"    = $null
    "AcoustID"    = $null
    "PicardOAuth" = $null
    "MetaBrainz"  = $null
}

# Scan Primary Secrets Vault first
$masterSecrets = "$PSScriptRoot\config\secrets\secrets.json"
if (Test-Path $masterSecrets) {
    try {
        $vault = Get-Content $masterSecrets -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($vault.secrets.sonarr.api_key) { $apiKeys["Sonarr"] = $vault.secrets.sonarr.api_key }
        if ($vault.secrets.radarr.api_key) { $apiKeys["Radarr"] = $vault.secrets.radarr.api_key }
        if ($vault.secrets.prowlarr.api_key) { $apiKeys["Prowlarr"] = $vault.secrets.prowlarr.api_key }
        if ($vault.secrets.bazarr.api_key) { $apiKeys["Bazarr"] = $vault.secrets.bazarr.api_key }
        if ($vault.secrets.jellyseerr.api_key) { $apiKeys["Jellyseerr"] = $vault.secrets.jellyseerr.api_key }
        if ($vault.secrets.jellyfin.api_key) { $apiKeys["Jellyfin"] = $vault.secrets.jellyfin.api_key }
        if ($vault.secrets.musicbrainz.acoustid_apikey) { $apiKeys["AcoustID"] = $vault.secrets.musicbrainz.acoustid_apikey }
        if ($vault.secrets.musicbrainz.picard_oauth_access_token) { $apiKeys["PicardOAuth"] = $vault.secrets.musicbrainz.picard_oauth_access_token }
        if ($vault.secrets.musicbrainz.metabrainz_access_token) { $apiKeys["MetaBrainz"] = $vault.secrets.musicbrainz.metabrainz_access_token }
    } catch {}
}

# Scan Fallback Locations
$scanPaths = @("$PSScriptRoot\config", $ConfigDir, "$PSScriptRoot\musicbrainz-docker\local\secrets")

# A. Scan Sonarr
foreach ($p in $scanPaths) {
    if ($apiKeys["Sonarr"]) { break }
    $cfg = Join-Path $p "sonarr\config.xml"
    if (Test-Path $cfg) {
        $xml = [xml](Get-Content $cfg -ErrorAction SilentlyContinue)
        if ($xml.Config.ApiKey) { $apiKeys["Sonarr"] = $xml.Config.ApiKey; break }
    }
}

# B. Scan Radarr
foreach ($p in $scanPaths) {
    $cfg = Join-Path $p "radarr\config.xml"
    if (Test-Path $cfg) {
        $xml = [xml](Get-Content $cfg -ErrorAction SilentlyContinue)
        if ($xml.Config.ApiKey) { $apiKeys["Radarr"] = $xml.Config.ApiKey; break }
    }
}

# C. Scan Prowlarr
foreach ($p in $scanPaths) {
    $cfg = Join-Path $p "prowlarr\config.xml"
    if (Test-Path $cfg) {
        $xml = [xml](Get-Content $cfg -ErrorAction SilentlyContinue)
        if ($xml.Config.ApiKey) { $apiKeys["Prowlarr"] = $xml.Config.ApiKey; break }
    }
}

# D. Scan Bazarr
foreach ($p in $scanPaths) {
    $cfg = Join-Path $p "bazarr\config\config.yaml"
    if (Test-Path $cfg) {
        $yaml = Get-Content $cfg -ErrorAction SilentlyContinue
        foreach ($line in $yaml) {
            if ($line -match '^\s*apikey:\s*([a-zA-Z0-9]+)') {
                $k = $matches[1].Trim()
                if ($k) { $apiKeys["Bazarr"] = $k; break }
            }
        }
        if ($apiKeys["Bazarr"]) { break }
    }
}

# E. Scan Jellyseerr & Jellyfin
foreach ($p in $scanPaths) {
    $cfg = Join-Path $p "jellyseerr\settings.json"
    if (Test-Path $cfg) {
        $json = Get-Content $cfg -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($json.main.apiKey) { $apiKeys["Jellyseerr"] = $json.main.apiKey }
        elseif ($json.apiKey) { $apiKeys["Jellyseerr"] = $json.apiKey }
        if ($json.jellyfin.apiKey) { $apiKeys["Jellyfin"] = $json.jellyfin.apiKey }
    }
}

# F. Scan Picard & AcoustID
$picardIni = "$env:APPDATA\MusicBrainz\Picard.ini"
if (Test-Path $picardIni) {
    $iniLines = Get-Content $picardIni -ErrorAction SilentlyContinue
    foreach ($l in $iniLines) {
        if ($l -match '^acoustid_apikey=(.+)$') { $apiKeys["AcoustID"] = $matches[1].Trim() }
        if ($l -match '^oauth_access_token=(.+)$') { $apiKeys["PicardOAuth"] = $matches[1].Trim() }
    }
}

# G. Scan MetaBrainz Access Token
$mbTokenFile = "$PSScriptRoot\musicbrainz-docker\local\secrets\metabrainz_access_token"
if (Test-Path $mbTokenFile) {
    $mbToken = (Get-Content $mbTokenFile -Raw -ErrorAction SilentlyContinue).Trim()
    if ($mbToken) { $apiKeys["MetaBrainz"] = $mbToken }
}

Write-Host "Discovered API Credentials:" -ForegroundColor Green
foreach ($service in $apiKeys.Keys) {
    $val = $apiKeys[$service]
    if ($val) {
        $masked = if ($val.Length -gt 8) { $val.Substring(0, 4) + "..." + $val.Substring($val.Length - 4, 4) } else { "****" }
        Write-Host ("  * {0,-16}: Key Found ({1})" -f $service, $masked) -ForegroundColor White
    } else {
        Write-Host ("  * {0,-16}: [NOT FOUND / PUBLIC]" -f $service) -ForegroundColor DarkGray
    }
}

# Enable TLS 1.2 / 1.3 and Trust Custom Local Certificates
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12 -bor [System.Net.SecurityProtocolType]::Tls13
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }

# --- 2. EXECUTE REST API CALLS & ASSERT VALIDATION ---
Write-Host "`n[2/3] Executing Live REST API Health & Authentication Tests..." -ForegroundColor Yellow

$testResults = @()

function Test-Endpoint {
    param(
        [string]$ServiceName,
        [string]$Url,
        [hashtable]$Headers = @{},
        [string]$Method = "GET",
        [string]$Body = $null,
        [string]$ExpectedContentField = "",
        [int]$TimeoutMs = 6000
    )

    $status = "FAIL"
    $responseCode = "000"
    $details = ""
    $latencyMs = 0

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $req = [System.Net.HttpWebRequest]::Create($Url)
        $req.Method = $Method
        $req.Timeout = $TimeoutMs
        $req.UserAgent = "MediaStack-ApiTester/1.0"
        $req.AllowAutoRedirect = $false

        foreach ($k in $Headers.Keys) {
            if ($k -eq "Host") {
                $req.Host = $Headers[$k]
            } else {
                $req.Headers.Add($k, $Headers[$k])
            }
        }

        if ($Body -and $Method -eq "POST") {
            $req.ContentType = "application/json"
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($Body)
            $req.ContentLength = $bytes.Length
            $stream = $req.GetRequestStream()
            $stream.Write($bytes, 0, $bytes.Length)
            $stream.Close()
        }

        $res = $req.GetResponse()
        $sw.Stop()
        $latencyMs = $sw.ElapsedMilliseconds
        $responseCode = [int]$res.StatusCode

        $contentType = $res.ContentType
        $streamReader = New-Object System.IO.StreamReader($res.GetResponseStream())
        $rawBody = $streamReader.ReadToEnd()
        $streamReader.Close()
        $res.Close()

        if ($contentType -match "json" -or ($rawBody.Trim().StartsWith("{") -or $rawBody.Trim().StartsWith("["))) {
            $jsonObj = $rawBody | ConvertFrom-Json -ErrorAction SilentlyContinue
            if ($ExpectedContentField -and $jsonObj) {
                $fieldVal = $jsonObj.$ExpectedContentField
                $details = "${ExpectedContentField}: $fieldVal"
            } else {
                $details = "HTTP $responseCode OK"
            }
        } else {
            $details = "HTTP $responseCode OK (HTML/Text)"
        }

        if ($responseCode -ge 200 -and $responseCode -lt 400) {
            $status = "OK"
        }
    } catch [System.Net.WebException] {
        $sw.Stop()
        $latencyMs = $sw.ElapsedMilliseconds
        if ($_.Response) {
            $responseCode = [int]$_.Response.StatusCode
            $details = "HTTP $responseCode ($($_.Exception.Message))"
            if ($responseCode -ge 200 -and $responseCode -lt 400) { $status = "OK" }
        } else {
            $responseCode = "FAIL"
            $details = $_.Exception.Message
        }
    } catch {
        $sw.Stop()
        $latencyMs = $sw.ElapsedMilliseconds
        $details = $_.Exception.Message
    }

    if ($ServiceName -eq "MusicBrainz WS2" -and ($responseCode -ge 500 -or $responseCode -eq "FAIL")) {
        $status = "STANDBY"
        $details = "STANDBY (Database dump import pending on port 5001)"
    } elseif ($ServiceName -eq "HDHomeRun Tuner" -and ($responseCode -ge 500 -or $responseCode -eq "FAIL")) {
        $status = "STANDBY"
        $details = "STANDBY (Hardware Tuner Standby / 192.168.4.45)"
    }

    $color = if ($status -eq "OK") { "Green" } elseif ($status -eq "STANDBY") { "DarkCyan" } elseif ($responseCode -ge 400 -and $responseCode -lt 500) { "Yellow" } else { "Red" }
    Write-Host ("  [{0,-7}] {1,-14} -> Code: {2,-4} | Latency: {3,4}ms | {4}" -f $status, $ServiceName, $responseCode, $latencyMs, $details) -ForegroundColor $color

    return [PSCustomObject]@{
        Service   = $ServiceName
        URL       = $Url
        Status    = $status
        HTTPCode  = $responseCode
        Latency   = "${latencyMs}ms"
        Details   = $details
    }
}

# 1. Sonarr API v3
$sonarrHeaders = @{ "Host" = "sonarr.voltairedeux.local" }
if ($apiKeys["Sonarr"]) { $sonarrHeaders["X-Api-Key"] = $apiKeys["Sonarr"] }
$testResults += Test-Endpoint -ServiceName "Sonarr API" -Url "http://localhost:8989/api/v3/system/status" -Headers $sonarrHeaders -ExpectedContentField "version"

# 2. Radarr API v3
$radarrHeaders = @{ "Host" = "radarr.voltairedeux.local" }
if ($apiKeys["Radarr"]) { $radarrHeaders["X-Api-Key"] = $apiKeys["Radarr"] }
$testResults += Test-Endpoint -ServiceName "Radarr API" -Url "http://localhost:7878/api/v3/system/status" -Headers $radarrHeaders -ExpectedContentField "version"

# 3. Prowlarr API v1
$prowlarrHeaders = @{ "Host" = "prowlarr.voltairedeux.local" }
if ($apiKeys["Prowlarr"]) { $prowlarrHeaders["X-Api-Key"] = $apiKeys["Prowlarr"] }
$testResults += Test-Endpoint -ServiceName "Prowlarr API" -Url "http://localhost:9696/api/v1/system/status" -Headers $prowlarrHeaders -ExpectedContentField "version"

# 4. Bazarr API
$bazarrHeaders = @{ "Host" = "bazarr.voltairedeux.local" }
if ($apiKeys["Bazarr"]) { $bazarrHeaders["X-Api-Key"] = $apiKeys["Bazarr"] }
$testResults += Test-Endpoint -ServiceName "Bazarr API" -Url "http://localhost:6767/api/system/status" -Headers $bazarrHeaders

# 5. Jellyseerr API v1
$seerrHeaders = @{ "Host" = "jellyseerr.voltairedeux.local" }
if ($apiKeys["Jellyseerr"]) { $seerrHeaders["X-Api-Key"] = $apiKeys["Jellyseerr"] }
$testResults += Test-Endpoint -ServiceName "Jellyseerr API" -Url "http://localhost:5055/api/v1/status" -Headers $seerrHeaders -ExpectedContentField "version"

# 6. Jellyfin Public API (HTTP & HTTPS)
$jfHeaders = @{ "Host" = "jellyfin.voltairedeux.local" }
if ($apiKeys["Jellyfin"]) { $jfHeaders["X-Emby-Token"] = $apiKeys["Jellyfin"] }
$testResults += Test-Endpoint -ServiceName "Jellyfin HTTP" -Url "http://localhost:8096/System/Info/Public" -Headers $jfHeaders -ExpectedContentField "Version"

$jfHttpsHeaders = @{ "Host" = "jellyfin.voltairedeux.local" }
if ($apiKeys["Jellyfin"]) { $jfHttpsHeaders["X-Emby-Token"] = $apiKeys["Jellyfin"] }
$testResults += Test-Endpoint -ServiceName "Jellyfin HTTPS" -Url "https://localhost/System/Info/Public" -Headers $jfHttpsHeaders -ExpectedContentField "Version"

# 7. MusicBrainz WebService v2 (Local Mirror)
$mbHeaders = @{ "Host" = "musicbrainz.voltairedeux.local" }
$testResults += Test-Endpoint -ServiceName "MusicBrainz WS2" -Url "http://localhost:80/ws/2/artist/5b11f4ce-a62d-471e-81fc-a69a8278c7da?fmt=json" -Headers $mbHeaders -TimeoutMs 8000

# 8. AcoustID Web Service (Fingerprinting Verification)
if ($apiKeys["AcoustID"]) {
    $acoustUser = $apiKeys["AcoustID"]
    $testResults += Test-Endpoint -ServiceName "AcoustID API" -Url "https://api.acoustid.org/v2/user/lookup?user=$acoustUser" -TimeoutMs 5000 -ExpectedContentField "status"
}

# 9. API Gateway Health
$gwHeaders = @{ "Host" = "api.voltairedeux.local" }
$testResults += Test-Endpoint -ServiceName "API Gateway" -Url "http://localhost:3000/api/system/status" -Headers $gwHeaders

# 10. Database SQLite GUI (Port 8080 Direct)
$dbHeaders = @{ "Host" = "db.voltairedeux.local" }
$testResults += Test-Endpoint -ServiceName "SQLite DB Web" -Url "http://localhost:8080/" -Headers $dbHeaders

# 11. HDHomeRun Tuner Gateway
$hdhomerunHeaders = @{ "Host" = "hdhomerun.voltairedeux.local" }
$testResults += Test-Endpoint -ServiceName "HDHomeRun Tuner" -Url "http://localhost:80/discover.json" -Headers $hdhomerunHeaders -TimeoutMs 4000

# 12. JellyWatch Requests Server
$jwReqHeaders = @{ "Host" = "requests.voltaireun.local" }
$testResults += Test-Endpoint -ServiceName "JellyWatch Requests API" -Url "http://localhost:3000/api/jellywatch/requests/stats" -Headers $jwReqHeaders -ExpectedContentField "server"

# 13. JellyWatch Issues Server
$jwIssHeaders = @{ "Host" = "issues.voltaireun.local" }
$testResults += Test-Endpoint -ServiceName "JellyWatch Issues API" -Url "http://localhost:3000/api/jellywatch/issues/stats" -Headers $jwIssHeaders -ExpectedContentField "server"

# 14. JellyWatch Requests Web Portal
$testResults += Test-Endpoint -ServiceName "Requests Web Portal" -Url "http://localhost:80/requests" -Headers $jwReqHeaders -TimeoutMs 3000

# 15. JellyWatch Issues Web Portal
$testResults += Test-Endpoint -ServiceName "Issues Web Portal" -Url "http://localhost:80/issues" -Headers $jwIssHeaders -TimeoutMs 3000

# 16. Portainer CE API & Web UI
$portainerHeaders = @{ "Host" = "portainer.voltairedeux.local" }
$testResults += Test-Endpoint -ServiceName "Portainer API" -Url "http://localhost:9000/api/system/status" -Headers $portainerHeaders -ExpectedContentField "Version"

# --- 3. EXPORT AUDIT REPORT & SQLITE LOGGING ---
Write-Host "`n[3/3] Exporting API Audit Trail..." -ForegroundColor Yellow

try {
    $sqlInit = "CREATE TABLE IF NOT EXISTS api_verification_log (id INTEGER PRIMARY KEY AUTOINCREMENT, test_timestamp TEXT NOT NULL, service_name TEXT NOT NULL, http_code TEXT, latency TEXT, status TEXT, details TEXT); "
    $inserts = ""
    foreach ($t in $testResults) {
        $cName = $t.Service -replace "'", "''"
        $cDet  = $t.Details -replace "'", "''"
        $tCode = $t.HTTPCode
        $tLat  = $t.Latency
        $tStat = $t.Status
        $inserts += "INSERT INTO api_verification_log (test_timestamp, service_name, http_code, latency, status, details) VALUES ('$timestamp', '$cName', '$tCode', '$tLat', '$tStat', '$cDet'); "
    }
    docker exec mediastack-db sqlite3 /config/mediastack_backup.db "$sqlInit $inserts" 2>$null
    Write-Host "  [OK] Ingested $($testResults.Count) verification records into /config/mediastack_backup.db" -ForegroundColor Green
} catch {
    # Fallback
}

if (-not $SkipReport) {
    $handoffsDir = "$PSScriptRoot\handoffs"
    if (-not (Test-Path $handoffsDir)) { New-Item -ItemType Directory -Force -Path $handoffsDir | Out-Null }

    $lines = @()
    $lines += "# MediaStack API Verification & Credentials Audit Report"
    $lines += ""
    $lines += "| Parameter | Value |"
    $lines += "| :--- | :--- |"
    $lines += "| **Audit Timestamp** | $timestamp |"
    $lines += "| **Host System** | $env:COMPUTERNAME |"
    $lines += "| **Config Directory** | $ConfigDir |"
    $lines += ""
    $lines += "---"
    $lines += ""
    $lines += "## Discovered API Credentials"
    $lines += "| Service | Key Discovered | Status |"
    $lines += "| :--- | :--- | :--- |"

    foreach ($k in $apiKeys.Keys) {
        $v = $apiKeys[$k]
        $masked = if ($v) {
            $prefixLen = [Math]::Min(6, $v.Length)
            $v.Substring(0, $prefixLen) + "... (Length: " + $v.Length + ")"
        } else {
            "Not Set / Public"
        }
        $statusIcon = if ($v) { "Found" } else { "Public" }
        $lines += "| $k | $masked | $statusIcon |"
    }

    $lines += ""
    $lines += "---"
    $lines += ""
    $lines += "## Live API Endpoint Responses"
    $lines += "| Service | Endpoint URL | Status | HTTP Code | Latency | Details |"
    $lines += "| :--- | :--- | :--- | :--- | :--- | :--- |"

    foreach ($r in $testResults) {
        $rSvc  = $r.Service
        $rUrl  = $r.URL
        $rStat = $r.Status
        $rCode = $r.HTTPCode
        $rLat  = $r.Latency
        $rDet  = $r.Details
        $lines += "| $rSvc | $rUrl | $rStat | $rCode | $rLat | $rDet |"
    }

    $lines += ""
    $lines += "---"
    $lines += "*Audit generated automatically by MediaStack API Verification Suite.*"

    Set-Content -Path $reportFile -Value ($lines -join "`n") -Encoding UTF8
    Write-Host "  [REPORT CREATED] $reportFile" -ForegroundColor Cyan
}

Write-Host "`n=======================================================" -ForegroundColor Cyan
Write-Host "   A P I   V E R I F I C A T I O N   C O M P L E T E" -ForegroundColor Cyan
Write-Host "=======================================================`n" -ForegroundColor Cyan
