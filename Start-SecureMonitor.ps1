# =============================================================================
# Start-SecureMonitor.ps1 — MediaStack Auth-Bound Health Monitor
# =============================================================================
# Dynamically queries Jellyfin users, displays a profile selection menu,
# prompts for admin password, and auto-logs in read-only users.
# =============================================================================

$ErrorActionPreference = "Stop"

# --- CONFIGURATION: Read-Only User Passwords ---
# Define default passwords here for passwordless auto-login of read-only users:
$ReadOnlyPasswords = @{
    "moops"      = "goosepoop4u"
    "bobby"      = "weir"
    "jellyseerr" = "goosepoop4u"
    "waltdakind" = "goosepoop4u"
    "dingos"     = "atemybaby"
}

# Clear console
Clear-Host

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "         MEDIASTACK SECURE SYSTEM MONITOR           " -ForegroundColor Cyan
Write-Host "====================================================`n" -ForegroundColor Cyan

# 1. Fetch Users Dynamically from Jellyfin DB
Write-Host "Loading user profiles from Jellyfin database..." -ForegroundColor Yellow
$users = @()
try {
    # Attempt to query the database using the running DB container
    $dbPath = "/mediastack/config/jellyfin/data/data/jellyfin.db"
    $queryRes = docker exec mediastack-db sqlite3 $dbPath "SELECT Username FROM Users" 2>$null
    if ($queryRes) {
        foreach ($line in $queryRes) {
            $cleaned = $line.Trim()
            if (-not [string]::IsNullOrEmpty($cleaned)) {
                $users += $cleaned
            }
        }
    }
}
catch {
    # Fallback to default list if container query fails
    $users = @("walter", "moops", "bobby", "waltdakind")
}

if ($users.Count -eq 0) {
    $users = @("walter", "moops", "bobby", "waltdakind")
}

# 2. Display Numbered User Menu
Write-Host "`nSelect a profile to authenticate:" -ForegroundColor Yellow
for ($i = 0; $i -lt $users.Count; $i++) {
    $usr = $users[$i]
    $role = "Read-Only"
    if ($usr.ToLower() -eq "walter") {
        $role = "Full CRUD (Admin)"
    }
    Write-Host "  $($i + 1). $usr ($role)"
}
Write-Host ""

$choice = Read-Host -Prompt "Enter selection (1-$($users.Count))"
$idx = [int]$choice - 1
if ($idx -lt 0 -or $idx -ge $users.Count) {
    Write-Host "Invalid selection. Exiting." -ForegroundColor Red
    Exit
}

$selectedUser = $users[$idx]

# 3. Prompt for Admin Password / Auto-feed Read-only Password
$passwordInput = ""
if ($selectedUser.ToLower() -eq "walter") {
    # Prompt for admin password
    $securePw = Read-Host -Prompt "Enter Password for admin '$selectedUser'" -AsSecureString
    if (-not $securePw) {
        Write-Host "Password cannot be empty. Exiting." -ForegroundColor Red
        Exit
    }
    # Decrypt password for API payload
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePw)
    $passwordInput = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
}
else {
    # Feed password directly for read-only user auto-login
    $passwordInput = $ReadOnlyPasswords[$selectedUser]
    if ($null -eq $passwordInput) {
        $passwordInput = ""
    }
    Write-Host "Auto-feeding password for read-only user '$selectedUser'..." -ForegroundColor Yellow
}

# 4. Authenticate against Jellyfin API
Write-Host "`nAuthenticating against Jellyfin server..." -ForegroundColor Yellow

$jellyfinUrl = "http://localhost:8096/Users/AuthenticateByName"
$authHeader = 'MediaBrowser Client="MediaStackMonitor", Device="PowerShell", DeviceId="MediaStackPowerShellMonitor", Version="1.0.0"'

$body = @{
    Username = $selectedUser
    Pw       = $passwordInput
} | ConvertTo-Json

try {
    $response = Invoke-RestMethod -Uri $jellyfinUrl -Method Post -Body $body -Headers @{
        "X-Emby-Authorization" = $authHeader
        "Content-Type"         = "application/json"
    } -UseBasicParsing -TimeoutSec 4
    $profileName = $response.User.Name
    
    $roleDescription = "RESTRICTED (Read-Only)"
    $roleColor = "Yellow"
    if ($profileName.ToLower() -eq "walter") {
        $roleDescription = "ADMINISTRATOR (Full CRUD)"
        $roleColor = "Green"
    }
    
    Write-Host "[OK] Authentication Successful!" -ForegroundColor Green
    Write-Host "  Profile: $profileName" -ForegroundColor Green
    Write-Host "  Role   : $roleDescription" -ForegroundColor $roleColor
    Write-Host ""
    
}
catch {
    Write-Host "[ERR] Authentication Failed! Invalid credentials or server is offline." -ForegroundColor Red
    Write-Host "  Details: $_" -ForegroundColor Red
    Exit
}

# 5. Loading Stage with Custom Progress Bar Display
Write-Host "Initializing system monitor modules..." -ForegroundColor Yellow
$stages = @(
    "Loading container profiles"
    "Scanning host port mappings"
    "Querying Caddy proxy routes"
    "Establishing secure API link"
    "Launching Live Dashboard"
)

for ($i = 0; $i -lt $stages.Count; $i++) {
    $pct = [int](($i + 1) / $stages.Count * 100)
    $barLength = [int]($pct / 5)
    $bar = ("#" * $barLength) + ("-" * (20 - $barLength))
    
    Write-Host "`r  [$bar] $pct% : $($stages[$i])..." -NoNewline -ForegroundColor Cyan
    Start-Sleep -Milliseconds 450
}
Write-Host "`n"

# 6. Live Healthcheck Monitor Loop
$monitoring = $true
while ($monitoring) {
    Clear-Host
    
    $timeStr = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    # Header display
    Write-Host "=====================================================================" -ForegroundColor DarkCyan
    Write-Host "              M E D I A S T A C K   L I V E   M O N I T O R          " -ForegroundColor Cyan
    Write-Host "   Profile: $profileName ($roleDescription)  |  Last Update: $timeStr" -ForegroundColor DarkGray
    Write-Host "   Press 'Q' to quit and return to PowerShell console" -ForegroundColor DarkGray
    Write-Host "=====================================================================" -ForegroundColor DarkCyan
    
    # 6a. Container Fleet Status
    Write-Host "`n--- CONTAINER FLEET STATUS ---" -ForegroundColor Cyan
    $containers = docker ps -a --format "table {{.Names}}`t{{.Status}}`t{{.State}}"
    if ($containers) {
        $containers | Write-Host
    }
    else {
        Write-Host "No containers found. Docker engine might be offline." -ForegroundColor Red
    }
    
    # 6b. Host TCP Port Exposures
    Write-Host "`n--- DIRECT PORT ROUTING STATUS ---" -ForegroundColor Cyan
    $ports = @{
        80   = "Caddy HTTP"
        443  = "Caddy HTTPS"
        3000 = "API Gateway"
        5055 = "Jellyseerr"
        6767 = "Bazarr"
        7878 = "Radarr"
        8096 = "Jellyfin"
        8989 = "Sonarr"
        9091 = "Transmission"
        9696 = "Prowlarr"
        9981 = "TVHeadend Web"
        9982 = "TVHeadend Stream"
    }
    
    # Parallelize TCP checks for snappier UI load
    foreach ($port in $ports.Keys | Sort-Object) {
        $t = Test-NetConnection -ComputerName localhost -Port $port -WarningAction SilentlyContinue
        if ($t.TcpTestSucceeded) {
            Write-Host "  [OK]   Port $port ($($ports[$port])) is responding" -ForegroundColor Green
        }
        else {
            Write-Host "  [FAIL] Port $port ($($ports[$port])) is BLOCKED" -ForegroundColor Red
        }
    }
    
    # 6c. Caddy Web Routing Verification (Local & External)
    Write-Host "`n--- WEB ROUTING PATHWAYS (CADDY) ---" -ForegroundColor Cyan
    
    # Scan standard routing pathways
    $routes = @(
        "ordinateur.local"
        "mediaserver.local"
        "jellyfin.ordinateur.local"
        "jellyfin.mediaserver.local"
        "radarr.ordinateur.local"
        "radarr.mediaserver.local"
        "sonarr.ordinateur.local"
        "sonarr.mediaserver.local"
        "waltdakind.xubi.org"
    )
    
    foreach ($route in $routes) {
        try {
            if ($route -eq "waltdakind.xubi.org") {
                $code = curl.exe -s -o NUL -w "%{http_code}" --max-time 3 "https://$route/"
            }
            else {
                $code = curl.exe -s -o NUL -w "%{http_code}" --max-time 2 -H "Host: $route" "http://localhost:80/"
            }
            $statusCode = [int]$code
            if ($statusCode -eq 000 -or $statusCode -eq 0) {
                Write-Host "  [FAIL] http://$route/ is UNREACHABLE" -ForegroundColor Red
            }
            elseif ($statusCode -ge 500) {
                Write-Host "  [WARN] http://$route/ proxy backend down ($statusCode)" -ForegroundColor Yellow
            }
            else {
                Write-Host "  [OK]   http://$route/ is routing correctly ($statusCode)" -ForegroundColor Green
            }
        }
        catch {
            Write-Host "  [FAIL] http://$route/ encountered exception" -ForegroundColor Red
        }
    }
    
    # Handle Keyboard Quitting (non-blocking sleep)
    for ($sec = 0; $sec -lt 60; $sec++) {
        if ($Host.UI.RawUI.KeyAvailable) {
            $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            if ($key.Character -match 'q|Q') {
                $monitoring = $false
                break
            }
        }
        Start-Sleep -Seconds 1
    }
}

Write-Host "`nMonitor terminated. Exiting." -ForegroundColor Yellow
