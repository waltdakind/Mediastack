param([switch]$DryRun)

Clear-Host
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "   MediaStack Node Setup Wizard"
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

$arch = $env:PROCESSOR_ARCHITECTURE
Write-Host "[+] Detected Architecture: $arch" -ForegroundColor Green

$envFile = ".env.x64"
$isSatellite = $false

if ($arch -match "ARM") {
    $envFile = ".env.arm"
    $isSatellite = $true
    Write-Host "[+] This node will be configured as an ARM Satellite." -ForegroundColor Yellow
} else {
    $choice = Read-Host "Is this machine the Main Server? (Y/N)"
    if ($choice -match "^n") {
        $isSatellite = $true
        Write-Host "[+] This node will be configured as an x64 Satellite." -ForegroundColor Yellow
    } else {
        Write-Host "[+] This node will be configured as the Main Server." -ForegroundColor Green
    }
}

Write-Host ""
$puid = Read-Host "Enter PUID [1000]"
if ([string]::IsNullOrWhiteSpace($puid)) { $puid = "1000" }

$pgid = Read-Host "Enter PGID [1000]"
if ([string]::IsNullOrWhiteSpace($pgid)) { $pgid = "1000" }

$tz = Read-Host "Enter Timezone [America/New_York]"
if ([string]::IsNullOrWhiteSpace($tz)) { $tz = "America/New_York" }

$mainServer = ""
if ($isSatellite) {
    $mainServer = Read-Host "Enter Main Server IP (e.g. 192.168.4.21)"
}

$content = @(
    "PUID=$puid"
    "PGID=$pgid"
    "TZ=$tz", "PUBLIC_DOMAIN=waldakind.xubi.org", "MEDIA_DIR=C:\Users\waltd\OneDrive", "MUSIC_ROOT=C:\Users\waltd\OneDrive\Music", "VIDEO_ROOT=C:\Users\waltd\OneDrive\Video", "LIVESTREAM_ROOT=C:\Users\waltd\OneDrive\LiveStream", "TV_ROOT=C:\Users\waltd\OneDrive\TV"
)

if ($isSatellite) {
    $content += "MAIN_SERVER_HOST=$mainServer"
    $content += "ARM_DEVICE_NAME=$env:COMPUTERNAME"
}

Set-Content -Path (Join-Path $PSScriptRoot $envFile) -Value $content -Encoding UTF8

Write-Host ""
Write-Host "[OK] Successfully created $envFile !" -ForegroundColor Green
Write-Host "You can now run your architecture-specific start script (e.g. .\start-$($arch.ToLower()).ps1)"


