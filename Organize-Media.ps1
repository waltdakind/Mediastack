param(
    [switch]$DryRun
)

$envFile = ".env.x64"
if ($env:PROCESSOR_ARCHITECTURE -match "ARM") { $envFile = ".env.arm" }

$envPath = Join-Path $PSScriptRoot $envFile
if (-not (Test-Path $envPath)) {
    Write-Error "Environment file $envFile not found! Please run setup-node.ps1 first."
    exit 1
}

# Basic parser for .env
$envVars = @{}
Get-Content $envPath | ForEach-Object {
    if ($_ -match "^(.*?)=(.*)$" -and $_ -notmatch "^#") {
        $envVars[$matches[1].Trim()] = $matches[2].Trim()
    }
}

$videoRoot = $envVars["VIDEO_ROOT"]
$musicRoot = $envVars["MUSIC_ROOT"]
$tvRoot = $envVars["TV_ROOT"]
$liveStreamRoot = $envVars["LIVESTREAM_ROOT"]

if (-not $videoRoot -or -not $musicRoot) {
    Write-Error "Media roots not fully defined in $envFile."
    exit 1
}

Write-Host "[+] Detected Video Root: $videoRoot"
Write-Host "[+] Detected Music Root: $musicRoot"
Write-Host "[+] Detected TV Root: $tvRoot"
Write-Host "[+] Detected LiveStream Root: $liveStreamRoot"

$sourceDrive = "C:\"
$excludePaths = @("C:\Windows", "C:\Program Files", "C:\Program Files (x86)", "C:\Users\waltd\OneDrive")

Write-Host "[+] Scanning $sourceDrive for media files (this may take a while)..."

# Search for Video
Get-ChildItem -Path $sourceDrive -Recurse -Include *.mp4, *.mkv, *.avi -ErrorAction SilentlyContinue | Where-Object {
    $file = $_
    $exclude = $false
    foreach ($ex in $excludePaths) {
        if ($file.FullName.StartsWith($ex)) { $exclude = $true; break }
    }
    if (-not $exclude) {
        Write-Host "[Moving Video] $($file.FullName) -> $videoRoot"
        if (-not $DryRun) { Move-Item -Path $file.FullName -Destination $videoRoot -Force }
    }
}

# Search for Music
Get-ChildItem -Path $sourceDrive -Recurse -Include *.mp3, *.flac, *.m4a -ErrorAction SilentlyContinue | Where-Object {
    $file = $_
    $exclude = $false
    foreach ($ex in $excludePaths) {
        if ($file.FullName.StartsWith($ex)) { $exclude = $true; break }
    }
    if (-not $exclude) {
        Write-Host "[Moving Music] $($file.FullName) -> $musicRoot"
        if (-not $DryRun) { Move-Item -Path $file.FullName -Destination $musicRoot -Force }
    }
}

# Search for M3U / LiveStream
Get-ChildItem -Path $sourceDrive -Recurse -Include *.m3u, *.m3u8 -ErrorAction SilentlyContinue | Where-Object {
    $file = $_
    $exclude = $false
    foreach ($ex in $excludePaths) {
        if ($file.FullName.StartsWith($ex)) { $exclude = $true; break }
    }
    if (-not $exclude) {
        Write-Host "[Moving LiveStream] $($file.FullName) -> $liveStreamRoot"
        if (-not $DryRun) { Move-Item -Path $file.FullName -Destination $liveStreamRoot -Force }
    }
}

Write-Host "[+] Organize-Media complete!"
