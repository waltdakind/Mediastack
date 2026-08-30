# System-Health.ps1
# Comprehensive Health, Optimization, and Validation Script (Multi-Arch Aware)
$env:PSScriptRoot = $PSScriptRoot.Replace('\', '/')
$ComposeDir = $PSScriptRoot
$RequiredUsers = @("moops", "walter", "bobby", "dingos", "waltdakind")

$arch = $env:PROCESSOR_ARCHITECTURE
$isARM = $arch -match "ARM"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host " MEDIA STACK SYSTEM HEALTH & OPTIMIZATION"
Write-Host " Architecture Profile: $arch"
Write-Host "=========================================`n" -ForegroundColor Cyan

Set-Location $ComposeDir

# --- 1. System Report & Analysis ---
Write-Host "[1/4] Generating System Report..." -ForegroundColor Yellow
$DiskSpace = Get-Volume -DriveLetter C
Write-Host "  -> Drive C: Space Available: $([math]::Round($DiskSpace.SizeRemaining / 1GB, 2)) GB"
$DockerInfo = docker info | Select-String "Containers:", "Images:"
Write-Host "  -> Docker Status: $($DockerInfo -join ', ')"

# --- 2. Trimming Unused Containers ---
Write-Host "`n[2/4] Trimming Unused Docker Resources..." -ForegroundColor Yellow
docker container prune -f | Out-Null
docker image prune -f | Out-Null
Write-Host "  -> Unused containers and dangling images removed." -ForegroundColor Green

# --- 3. Database Compression (VACUUM) ---
Write-Host "`n[3/4] Optimizing Databases (This may take a moment)..." -ForegroundColor Yellow
if ($isARM) {
    Write-Host "  -> ARM Satellite detected. Skipping x64 database optimization (Radarr/Sonarr) to avoid corruption." -ForegroundColor DarkGray
    # Optionally vacuum jellyfin local cache if present, but since it's just a bind mount cache, we can skip for safety.
    Write-Host "  -> Skipping database vacuuming on satellite node." -ForegroundColor DarkGray
} else {
    Write-Host "  -> Stopping Radarr, Sonarr, and Jellyfin for safe optimization..."
    docker compose stop radarr sonarr jellyfin | Out-Null
    $Databases = @(
        @{ Name = "Radarr"; Path = "/mediastack/config/radarr/radarr.db" },
        @{ Name = "Sonarr"; Path = "/mediastack/config/sonarr/sonarr.db" },
        @{ Name = "Jellyfin"; Path = "/mediastack/config/jellyfin/data/data/jellyfin.db" }
    )
    foreach ($DB in $Databases) {
        Write-Host "  -> Vacuuming and Compressing $($DB.Name) Database..."
        docker exec mediastack-db sqlite3 $($DB.Path) "VACUUM;" 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "     Done." -ForegroundColor Green
        } else {
            Write-Host "  -> Failed to optimize $($DB.Name) database." -ForegroundColor Yellow
        }
    }
}

# --- 4. User Validation ---
Write-Host "`n[4/4] Validating Stack Users in Jellyfin..." -ForegroundColor Yellow
if ($isARM) {
    Write-Host "  -> ARM Satellite detected. Skipping user validation as main DB lives on x64 node." -ForegroundColor DarkGray
} else {
    $JellyfinDB = "/mediastack/config/jellyfin/data/data/jellyfin.db"
    $FoundUsersStr = docker exec mediastack-db sqlite3 $JellyfinDB "SELECT Username FROM Users;" 2>$null
    if ($FoundUsersStr) {
        $FoundUsers = $FoundUsersStr -split "`n" | ForEach-Object { $_.Trim().ToLower() }
        
        $AllPresent = $true
        foreach ($User in $RequiredUsers) {
            if ($FoundUsers -contains $User.ToLower()) {
                Write-Host "  -> User [$User] is PRESENT." -ForegroundColor Green
            } else {
                Write-Host "  -> ERROR: User [$User] is MISSING!" -ForegroundColor Red
                $AllPresent = $false
            }
        }
        
        if (-not $AllPresent) {
            Write-Host "  -> CRITICAL: One or more required users are missing. Please verify in Jellyfin." -ForegroundColor Red
        } else {
            Write-Host "  -> All 5 required users are validated and present!" -ForegroundColor Green
        }
    } else {
        Write-Host "  -> Unable to query Jellyfin database (container offline or path missing). Skipping user validation." -ForegroundColor DarkGray
    }
}

Write-Host "`n=========================================" -ForegroundColor Cyan
Write-Host " HEALTH CHECK COMPLETE. STARTING STACK..." -ForegroundColor Cyan
Write-Host "=========================================`n" -ForegroundColor Cyan

if ($isARM) {
    & .\start-arm.ps1 up -NoWait
} else {
    & .\start-x64.ps1 up -NoWait
}

Write-Host "Done!" -ForegroundColor Green
