# Update-MusicBrainz.ps1 - Automated Replication & Packet Updater for MusicBrainz Server
param(
    [string]$AccessToken = "",
    [string]$PicardId = "",
    [int]$PacketNumber = 0,
    [switch]$ApplyReplication,
    [switch]$DownloadPacketOnly,
    [string]$DownloadDir = ""
)

$BaseDir = if (Test-Path (Join-Path $PSScriptRoot "..\docker-compose.yml")) { (Resolve-Path (Join-Path $PSScriptRoot "..")).Path } else { $PSScriptRoot }
if (-not $DownloadDir) { $DownloadDir = "$BaseDir\musicbrainz-docker\data\dbdump" }
$ErrorActionPreference = "Continue"

$mbDir = Join-Path -Path $BaseDir -ChildPath "musicbrainz-docker"
$secretsDir = Join-Path -Path $mbDir -ChildPath "local\secrets"
$tokenFile = Join-Path -Path $secretsDir -ChildPath "metabrainz_access_token"
$configEnv = Join-Path -Path $mbDir -ChildPath ".env"

Write-Host "`n=======================================================" -ForegroundColor Cyan
Write-Host "       M U S I C B R A I N Z   U P D A T E R" -ForegroundColor Cyan
Write-Host "=======================================================" -ForegroundColor Cyan

# 1. Check existing saved token if not explicitly passed
if ([string]::IsNullOrWhiteSpace($AccessToken)) {
    if (Test-Path $tokenFile) {
        $storedToken = (Get-Content $tokenFile -Raw -ErrorAction SilentlyContinue)
        if ($storedToken) {
            $storedToken = $storedToken.Trim()
            if ($storedToken.Length -ge 10) {
                $AccessToken = $storedToken
                Write-Host "[INFO] Using existing MetaBrainz access token from secrets." -ForegroundColor Green
            }
        }
    }
}

# 2. If still empty, prompt the user interactively
if ([string]::IsNullOrWhiteSpace($AccessToken)) {
    Write-Host "`n[MetaBrainz Access Token Setup]" -ForegroundColor Yellow
    Write-Host "Get your free personal replication token at: https://metabrainz.org/profile" -ForegroundColor DarkCyan
    $inputToken = Read-Host "Enter your 40-character MetaBrainz Access Token"
    if (-not [string]::IsNullOrWhiteSpace($inputToken)) {
        $AccessToken = $inputToken.Trim()
    } else {
        Write-Warning "No Access Token provided. Replication downloads will require an access token."
    }
}

# 3. Store and persist token if provided
if (-not [string]::IsNullOrWhiteSpace($AccessToken)) {
    if (-not (Test-Path $secretsDir)) {
        New-Item -ItemType Directory -Force -Path $secretsDir | Out-Null
    }
    Set-Content -Path $tokenFile -Value $AccessToken -Encoding ASCII -NoNewline
    Write-Host "[SUCCESS] MetaBrainz token saved to $tokenFile" -ForegroundColor Green
}

# 4. Save Picard Client ID if provided
if (-not [string]::IsNullOrWhiteSpace($PicardId)) {
    Write-Host "[INFO] Picard Client / User ID registered: $PicardId" -ForegroundColor Green
    if (Test-Path $configEnv) {
        $envLines = Get-Content $configEnv
        $filtered = $envLines | Where-Object { $_ -notmatch '^PICARD_CLIENT_ID=' -and $_ -notmatch '^METABRAINZ_ACCESS_TOKEN=' }
        $filtered += "PICARD_CLIENT_ID=$PicardId"
        if ($AccessToken) { $filtered += "METABRAINZ_ACCESS_TOKEN=$AccessToken" }
        Set-Content -Path $configEnv -Value $filtered -Encoding UTF8
    }
}

# 5. Handle Specific Replication Packet Download
if ($PacketNumber -gt 0) {
    if ([string]::IsNullOrWhiteSpace($AccessToken)) {
        Write-Error "Cannot download replication packet without an Access Token. Please provide -AccessToken or set it above."
        return
    }

    if (-not (Test-Path $DownloadDir)) {
        New-Item -ItemType Directory -Force -Path $DownloadDir | Out-Null
    }

    $packetUrl = "https://metabrainz.org/api/musicbrainz/replication-$PacketNumber-v2.tar.bz2?token=$AccessToken"
    $outputFile = Join-Path -Path $DownloadDir -ChildPath "replication-$PacketNumber-v2.tar.bz2"

    Write-Host "`n[DOWNLOADING] Replication Packet #$PacketNumber..." -ForegroundColor Cyan
    Write-Host "URL: https://metabrainz.org/api/musicbrainz/replication-$PacketNumber-v2.tar.bz2?token=***" -ForegroundColor DarkGray

    try {
        $webClient = New-Object System.Net.WebClient
        if ($PicardId) {
            $webClient.Headers.Add("User-Agent", "MusicBrainz-Picard/$PicardId (Mediastack Mirror)")
        } else {
            $webClient.Headers.Add("User-Agent", "MusicBrainz-Mirror/1.0 (Mediastack Updater)")
        }

        $webClient.DownloadFile($packetUrl, $outputFile)
        $fileSize = (Get-Item $outputFile).Length / 1MB
        Write-Host ("[SUCCESS] Downloaded replication packet #${PacketNumber} ({0:N2} MB) to $outputFile" -f $fileSize) -ForegroundColor Green

        if ($ApplyReplication -and (-not $DownloadPacketOnly)) {
            Write-Host "`n[APPLYING] Applying replication packet to local database..." -ForegroundColor Yellow
            Push-Location $mbDir
            docker compose exec -T musicbrainz LoadReplicationChanges $outputFile
            Pop-Location
            Write-Host "[SUCCESS] Replication packet #${PacketNumber} applied successfully!" -ForegroundColor Green
        }
    } catch {
        Write-Error "Failed to download replication packet #${PacketNumber}: $_"
    }
}

# 6. Trigger Automated Container Replication Runner if Requested
if ($ApplyReplication -and ($PacketNumber -le 0)) {
    Write-Host "`n[RUNNING] Triggering MusicBrainz replication worker inside Docker container..." -ForegroundColor Cyan
    Push-Location $mbDir
    try {
        Write-Host "Checking current replication status from database..." -ForegroundColor DarkGray
        docker exec musicbrainz-docker-db-1 psql -U musicbrainz -d musicbrainz -t -A -F " | " -c "SELECT current_schema_sequence, last_replication_date FROM replication_control;" 2>$null
        
        Write-Host "`nExecuting replication.sh..." -ForegroundColor Yellow
        docker compose exec -T musicbrainz /usr/local/bin/replication.sh
        Write-Host "[SUCCESS] Replication run completed!" -ForegroundColor Green
    } catch {
        Write-Warning "Replication script exited with message: $_"
    } finally {
        Pop-Location
    }
}

Write-Host "`n-------------------------------------------------------" -ForegroundColor DarkGray
Write-Host "Usage Examples:" -ForegroundColor Yellow
Write-Host "  1. Set Token & Picard ID:"
Write-Host "     .\Update-MusicBrainz.ps1 -AccessToken '<YOUR_TOKEN>' -PicardId '<YOUR_PICARD_ID>'"
Write-Host "  2. Download Specific Replication Packet:"
Write-Host "     .\Update-MusicBrainz.ps1 -PacketNumber 150000"
Write-Host "  3. Download and Apply Replication to Database:"
Write-Host "     .\Update-MusicBrainz.ps1 -ApplyReplication"
Write-Host "-------------------------------------------------------`n" -ForegroundColor DarkGray

