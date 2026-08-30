param(
    [Parameter(Mandatory=$true)]
    [string]$BackupZip
)

$ErrorActionPreference = "Stop"

function Write-Color {
    param($text, $color)
    Write-Host $text -ForegroundColor $color
}

function Show-Banner {
    Clear-Host
    Write-Color "==============================================" "Cyan"
    Write-Color "  MediaStack Windows Deployment Wizard" "White"
    Write-Color "==============================================" "Cyan"
    Write-Host ""
}

Show-Banner

# 1. Check Docker Desktop
Write-Color "[Step 1/5] Verifying Docker Desktop..." "Yellow"
try {
    $dockerInfo = docker info 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Docker is not running."
    }
    Write-Color "  -> Docker is running natively!" "Green"
} catch {
    Write-Color "Error: Docker Desktop is not running or not installed." "Red"
    Write-Color "Please start Docker Desktop and run this script again." "Red"
    exit 1
}

# 2. Extract Backup
$InstallDir = "C:\Users\Public\MediaStack"
Write-Color "`n[Step 2/5] Deploying Backup to $InstallDir..." "Yellow"

if (-Not (Test-Path $BackupZip)) {
    Write-Color "Error: Could not find backup file '$BackupZip'." "Red"
    exit 1
}

if (Test-Path $InstallDir) {
    Write-Color "  -> Directory exists. Merging contents..." "DarkGray"
} else {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
}

Write-Color "  -> Extracting $BackupZip..." "DarkGray"
# The zip contains the MediaStack folder, so expanding to Public places it at Public\MediaStack
Expand-Archive -Path $BackupZip -DestinationPath "C:\Users\Public\" -Force

Write-Color "  -> Backup extracted successfully." "Green"

# 3. Start the Stack using start-x64.ps1
Write-Color "`n[Step 3/5] Starting the MediaStack Containers..." "Yellow"
Set-Location $InstallDir

if (-Not (Test-Path ".\start-x64.ps1")) {
    Write-Color "Error: start-x64.ps1 not found in $InstallDir. Is the backup corrupt?" "Red"
    exit 1
}

Write-Color "  -> Handing over to start-x64.ps1..." "DarkGray"
try {
    # Call start-x64.ps1 with the 'up' command
    .\start-x64.ps1 up
} catch {
    Write-Color "Error: start-x64.ps1 encountered an issue." "Red"
    exit 1
}

Write-Color "  -> Stack deployed successfully!" "Green"

# 4. Wait for databases
Write-Color "`n[Step 4/5] Waiting for databases to initialize..." "Yellow"
Start-Sleep -Seconds 15

# 5. Validate Jellyfin users
Write-Color "`n[Step 5/5] Validating restored users..." "Yellow"
$JellyfinDb = "C:\Users\Public\MediaStack\config\jellyfin\jellyfin.db"

if (-Not (Test-Path $JellyfinDb)) {
    Write-Color "Warning: $JellyfinDb not found. Skipping user validation." "Yellow"
} else {
    Write-Color "  -> Querying Jellyfin DB..." "DarkGray"
    # Execute docker run, mapping Windows path to Linux container path
    $FoundUsers = docker run --rm -v "${JellyfinDb}:/db.sqlite" nouchka/sqlite3 /db.sqlite "SELECT Username FROM Users;" | ForEach-Object { $_.ToLower() }
    
    $RequiredUsers = @("moops", "walter", "bobby", "dingos", "waltdakind")
    $Missing = @()

    foreach ($user in $RequiredUsers) {
        if ($FoundUsers -contains $user) {
            Write-Color "  -> Found user: $user" "Green"
        } else {
            Write-Color "  -> MISSING user: $user" "Red"
            $Missing += $user
        }
    }

    if ($Missing.Count -gt 0) {
        Write-Color "`n[!] WARNING: Some users were missing from the database." "Red"
    } else {
        Write-Color "`nSUCCESS: All required users were successfully restored!" "Green"
    }
}

Write-Color "`n==============================================" "Cyan"
Write-Color " Installation Complete!" "White"
Write-Color "==============================================" "Cyan"
Write-Host ""
Read-Host "Press Enter to exit..."
