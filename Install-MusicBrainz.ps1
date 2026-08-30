<#
.SYNOPSIS
    Installs a local version of MusicBrainz Server using Docker Compose.
.DESCRIPTION
    Clones the official metabrainz/musicbrainz-docker repository and configures it.
    Can be run in Sample mode (lightweight, ~6GB) or Full Mirror mode (heavyweight, ~250-300GB).
#>

[CmdletBinding()]
param (
    [Parameter()]
    [ValidateSet('Sample', 'Full')]
    [string]$Mode = 'Sample',

    [Parameter()]
    [int]$Port = 5000,

    [Parameter()]
    [string]$InstallDir = "C:\Users\waltd\OneDrive\Mediastack\musicbrainz-docker",

    [Parameter()]
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

Clear-Host
Write-Host "=========================================================" -ForegroundColor DarkCyan
Write-Host "   M U S I C B R A I N Z   S E R V E R   I N S T A L L E R" -ForegroundColor Cyan
Write-Host "   Setting up local mirror/standalone server via Docker" -ForegroundColor DarkGray
Write-Host "=========================================================" -ForegroundColor DarkCyan
Write-Host ""

# 1. Verify Prerequisites
Write-Host "1. Verifying Prerequisites..." -ForegroundColor Yellow

# Check Git
$gitCmd = Get-Command git -ErrorAction SilentlyContinue
if (-not $gitCmd) {
    Write-Host "   [ERROR] Git is not installed or not in PATH. Please install Git first." -ForegroundColor Red
    exit 1
}
Write-Host "   -> Git is installed." -ForegroundColor Green

# Check Docker
$dockerCmd = Get-Command docker -ErrorAction SilentlyContinue
if (-not $dockerCmd) {
    Write-Host "   [ERROR] Docker CLI is not installed. Please install Docker Desktop." -ForegroundColor Red
    exit 1
}
try {
    $dockerInfo = docker info --format '{{.ServerVersion}}' 2>$null
    if ($null -eq $dockerInfo -or $dockerInfo -eq "") {
        throw "Docker daemon not running"
    }
    Write-Host "   -> Docker is running (Version: $dockerInfo)." -ForegroundColor Green
} catch {
    Write-Host "   [ERROR] Docker daemon is not running. Please start Docker Desktop." -ForegroundColor Red
    exit 1
}

# Check Port Availability
Write-Host "   -> Checking if Port $Port is available..." -ForegroundColor DarkGray
$portActive = Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue | Where-Object { $_.State -eq 'Listen' }
if ($portActive) {
    Write-Host "   [WARNING] Port $Port is already in use by another service." -ForegroundColor Yellow
    if (-not $Force) {
        $userInputPort = Read-Host "      Please enter an alternative port (default is 5050)"
        if ($userInputPort) {
            $Port = [int]$userInputPort
        } else {
            $Port = 5050
        }
    } else {
        Write-Host "   [ERROR] Port $Port is in use. Cannot proceed in non-interactive/Force mode." -ForegroundColor Red
        exit 1
    }
}
Write-Host "   -> Server will run on port $Port." -ForegroundColor Green

# Check Disk Space
$drive = Split-Path -Path $InstallDir -Qualifier
if ($drive -and $drive.EndsWith(":")) {
    $disk = Get-PSDrive -Name $drive.Replace(":", "") -ErrorAction SilentlyContinue
    if ($disk) {
        $freeGB = [math]::Round($disk.Free / 1GB, 2)
        Write-Host "   -> Free disk space on $drive : $freeGB GB" -ForegroundColor DarkGray
        if ($Mode -eq 'Full' -and $freeGB -lt 250) {
            Write-Host "   [WARNING] Full Mirror mode requires at least 250 GB - 300 GB of free space." -ForegroundColor Yellow
            Write-Host "             You currently have only $freeGB GB available." -ForegroundColor Yellow
            if (-not $Force) {
                $confirm = Read-Host "      Do you want to continue anyway? (y/N)"
                if ($confirm -notmatch '^[yY]') {
                    Write-Host "   [INFO] Installation cancelled by user due to disk space limits." -ForegroundColor Red
                    exit 1
                }
            }
        }
    }
}

# 2. Clone Repository
Write-Host "`n2. Preparing musicbrainz-docker..." -ForegroundColor Yellow
if (Test-Path -Path $InstallDir) {
    Write-Host "   -> Directory already exists at $InstallDir" -ForegroundColor DarkGray
    if ($Force) {
        Write-Host "   -> Force flag set, deleting and re-cloning..." -ForegroundColor DarkGray
        Remove-Item -Path $InstallDir -Recurse -Force
        git clone https://github.com/metabrainz/musicbrainz-docker.git $InstallDir
    } else {
        Write-Host "   -> Updating existing repository..." -ForegroundColor DarkGray
        Push-Location $InstallDir
        try {
            git pull
        } catch {
            Write-Host "   [WARNING] Failed to pull latest git changes. Proceeding with local repository files." -ForegroundColor Yellow
        }
        Pop-Location
    }
} else {
    Write-Host "   -> Cloning repository..." -ForegroundColor DarkGray
    git clone https://github.com/metabrainz/musicbrainz-docker.git $InstallDir
}
Write-Host "   -> Repository is ready." -ForegroundColor Green

# 3. Configure Settings
Write-Host "`n3. Applying Configurations..." -ForegroundColor Yellow
Push-Location $InstallDir

# Create/Overwrite .env file
$envFilePath = Join-Path $InstallDir ".env"
$envContent = @"
# Local MusicBrainz Configuration
COMPOSE_PATH_SEPARATOR=:
MUSICBRAINZ_WEB_SERVER_PORT=$Port
"@

if ($Mode -eq 'Sample') {
    Write-Host "   -> Configuration Mode: Sample (Lightweight Standalone)" -ForegroundColor Cyan
    $envContent += "`nCOMPOSE_FILE=docker-compose.yml:compose/musicbrainz-standalone.yml"
} else {
    Write-Host "   -> Configuration Mode: Full Mirror (Solr Search + Replication)" -ForegroundColor Cyan
    $envContent += "`nCOMPOSE_FILE=docker-compose.yml:compose/live-indexing-search.yml:compose/replication-cron.yml"
    
    # Prompt for replication token (optional)
    if (-not $Force) {
        Write-Host "      Note: To sync database changes automatically, you need a MetaBrainz replication token." -ForegroundColor DarkGray
        Write-Host "            Get it for free at: https://metabrainz.org/account/replication-token" -ForegroundColor DarkGray
        $token = Read-Host "      Enter Replication Token (press Enter to skip)"
        if ($token) {
            $envContent += "`nMUSICBRAINZ_REPLICATION_TOKEN=$token"
        }
    }
}

Set-Content -Path $envFilePath -Value $envContent -Force
Write-Host "   -> Saved configuration to .env" -ForegroundColor Green

# 4. Build Containers
Write-Host "`n4. Building Docker Containers (this may take a few minutes)..." -ForegroundColor Yellow
docker compose build
Write-Host "   -> Build complete." -ForegroundColor Green

# 5. Initialize Database
Write-Host "`n5. Initializing Database..." -ForegroundColor Yellow
if ($Mode -eq 'Sample') {
    Write-Host "   -> Fetching and importing sample data (takes ~5-15 minutes)..." -ForegroundColor Cyan
    docker compose run --rm musicbrainz createdb.sh -sample -fetch
} else {
    Write-Host "   [WARNING] Fetching and importing full MusicBrainz database (takes several hours!)..." -ForegroundColor Yellow
    Write-Host "             Please ensure your computer remains powered on and connected to the internet." -ForegroundColor Yellow
    docker compose run --rm musicbrainz createdb.sh -fetch
    
    # Fetching pre-built search indexes to speed up Solr setup
    Write-Host "   -> Downloading pre-built Solr search indexes (faster than rebuilding)..." -ForegroundColor Cyan
    docker compose up -d musicbrainz search
    docker compose exec search fetch-backup-archives
    docker compose exec search load-backup-archives
}
Write-Host "   -> Database initialized." -ForegroundColor Green

# 6. Start Server
Write-Host "`n6. Starting Services..." -ForegroundColor Yellow
docker compose up -d
Write-Host "   -> MusicBrainz Server is running!" -ForegroundColor Green

# Output Information
Write-Host "`n=========================================================" -ForegroundColor Cyan
Write-Host "                   SETUP COMPLETE!" -ForegroundColor Green
Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host "Local MusicBrainz Server is available at: http://localhost:$Port" -ForegroundColor Green
Write-Host "To shut down the server, go to $InstallDir and run: docker compose down" -ForegroundColor DarkGray
Write-Host ""
Write-Host "HOW TO CONNECT MUSICBRAINZ PICARD APP:" -ForegroundColor Yellow
Write-Host "1. Open Picard on Windows." -ForegroundColor DarkGray
Write-Host "2. Go to Options -> Options... -> Connection." -ForegroundColor DarkGray
Write-Host "3. Change Server address to: localhost" -ForegroundColor DarkGray
Write-Host "4. Change Port to: $Port" -ForegroundColor DarkGray
Write-Host "5. Make sure 'Use SSL' is UNCHECKED." -ForegroundColor DarkGray
Write-Host "6. Click 'Make default' or 'OK' and restart Picard." -ForegroundColor DarkGray
Write-Host ""
Write-Host "OPTIMIZATION CHECKLIST FOR PICARD (in Options):" -ForegroundColor Yellow
Write-Host "* Cover Art: Enable both 'Embed cover images' and 'Save cover images as folder.jpg'." -ForegroundColor DarkGray
Write-Host "* Metadata: Enable 'Standardize artist names' and tune release group preferences." -ForegroundColor DarkGray
Write-Host "* File Naming: Check 'Rename files' and 'Move files', then use this clean naming script:" -ForegroundColor DarkGray
Write-Host '  $if2(%albumartist%,%artist%)/($if2(%originalyear%,%date%,0000)) %album%/$num(%tracknumber%,2) - %title%' -ForegroundColor DarkCyan
Write-Host "=========================================================" -ForegroundColor Cyan

Pop-Location
