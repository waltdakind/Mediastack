# =============================================================================
# login-player.ps1 — MediaStack Admin Magic Login Link Generator
# =============================================================================
# Logs in as Jellyfin user "walter" and generates passwordless magic login URLs.
# =============================================================================

[CmdletBinding()]
param (
    [Parameter(Mandatory=$false)][SecureString]$Password
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::InputEncoding  = [System.Text.Encoding]::UTF8

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "         MEDIASTACK ADMIN LOGIN GENERATOR           " -ForegroundColor Cyan
Write-Host "====================================================`n" -ForegroundColor Cyan

# 1. Prompt for password if not provided
$plainPassword = ""
if (-not $Password) {
    $securePw = Read-Host -Prompt "Enter password for Jellyfin user 'walter'" -AsSecureString
    if (-not $securePw) {
        Write-Host "Password cannot be empty. Exiting." -ForegroundColor Red
        Exit
    }
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePw)
    $plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
} else {
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
    $plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
}

# 2. Authenticate against local Jellyfin API
Write-Host "`nAuthenticating against Jellyfin on port 8096..." -ForegroundColor Yellow

$jellyfinUrl = "http://localhost:8096/Users/AuthenticateByName"
$authHeader = 'MediaBrowser Client="MediaStackPlayer", Device="WebBrowser", DeviceId="MediaStackPlayerDevice", Version="1.0.0"'

$body = @{
    Username = "walter"
    Pw = $plainPassword
} | ConvertTo-Json

try {
    $response = Invoke-RestMethod -Uri $jellyfinUrl -Method Post -Body $body -Headers @{
        "X-Emby-Authorization" = $authHeader
        "Content-Type" = "application/json"
    } -UseBasicParsing -TimeoutSec 5
    
    $token = $response.AccessToken
    $userId = $response.User.Id
    $username = $response.User.Name
    
    Write-Host "[OK] Authentication Successful!" -ForegroundColor Green
    Write-Host "  User Name : $username"
    Write-Host "  User ID   : $userId"
    Write-Host "  Token     : $token" -ForegroundColor DarkGray
    Write-Host ""
    
    # 3. Generate Magic Login Links
    Write-Host "====================================================" -ForegroundColor Cyan
    Write-Host "              MAGIC LOGIN LINKS                     " -ForegroundColor Cyan
    Write-Host "====================================================`n" -ForegroundColor Cyan
    
    $localLink1 = "http://voltaireun.local/player/?token=$token" + "&userId=$userId" + "&username=$username"
    $localLink2 = "http://voltairedeux.local/player/?token=$token" + "&userId=$userId" + "&username=$username"
    $externalLink = "https://waltdakind.xubi.org/?token=$token" + "&userId=$userId" + "&username=$username"
    
    Write-Host "Local Link (VoltaireUn Main):" -ForegroundColor Yellow
    Write-Host "  $localLink1" -ForegroundColor Green
    Write-Host ""
    
    Write-Host "Local Link (VoltaireDeux AI Node):" -ForegroundColor Yellow
    Write-Host "  $localLink2" -ForegroundColor Green
    Write-Host ""
    
    Write-Host "Secure External Link (WAN):" -ForegroundColor Yellow
    Write-Host "  $externalLink" -ForegroundColor Green
    Write-Host ""
    
    # 4. Provide API command template
    Write-Host "====================================================" -ForegroundColor Cyan
    Write-Host "              SAMPLE ADMIN API COMMAND              " -ForegroundColor Cyan
    Write-Host "====================================================`n" -ForegroundColor Cyan
    Write-Host "Query player settings from backend API using the token:"
    Write-Host "  Invoke-RestMethod -Uri 'http://localhost:3000/api/player/settings' -Headers @{'X-Emby-Token'='$token'}" -ForegroundColor Green
    Write-Host ""
    
    # 5. Launch default browser
    Write-Host "Launching local player dashboard..." -ForegroundColor Yellow
    Start-Process $localLink1
    
} catch {
    Write-Host "[FAIL] Authentication Failed!" -ForegroundColor Red
    if ($_.Exception.Response) {
        $stream = $_.Exception.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($stream)
        $errText = $reader.ReadToEnd()
        Write-Host "  Response: $errText" -ForegroundColor Red
    } else {
        Write-Host "  Error: $_" -ForegroundColor Red
    }
}
