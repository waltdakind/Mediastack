param(
    [string]$MusicDir = "C:\Users\waltd\OneDrive\Music",
    [string]$ArtworkDir = "C:\Users\waltd\OneDrive\Pictures\Artwork"
)

function New-StylizedArtistImage {
    param(
        [string]$ArtistName,
        [string]$OutPath
    )
    Add-Type -AssemblyName System.Drawing
    $bmp = New-Object System.Drawing.Bitmap(1000, 1000)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    
    $rand = New-Object Random
    $color1 = [System.Drawing.Color]::FromArgb(255, $rand.Next(100,256), $rand.Next(100,256), $rand.Next(100,256))
    $color2 = [System.Drawing.Color]::FromArgb(255, $rand.Next(0,100), $rand.Next(0,100), $rand.Next(0,100))
    $rect = New-Object System.Drawing.Rectangle(0,0,1000,1000)
    $rectF = New-Object System.Drawing.RectangleF(0,0,1000,1000)
    
    $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, $color1, $color2, 45.0)
    $g.FillRectangle($brush, $rect)
    
    # Adjust font size based on length to prevent clipping
    $fontSize = 100
    if ($ArtistName.Length -gt 15) { $fontSize = 70 }
    if ($ArtistName.Length -gt 25) { $fontSize = 50 }
    
    $font = New-Object System.Drawing.Font('Impact', $fontSize, [System.Drawing.FontStyle]::Bold)
    $textBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
    $format = New-Object System.Drawing.StringFormat
    $format.Alignment = [System.Drawing.StringAlignment]::Center
    $format.LineAlignment = [System.Drawing.StringAlignment]::Center
    
    $g.DrawString($ArtistName, $font, $textBrush, $rectF, $format)
    $bmp.Save($OutPath, [System.Drawing.Imaging.ImageFormat]::Jpeg)
    
    $g.Dispose()
    $bmp.Dispose()
    $brush.Dispose()
    $font.Dispose()
    $textBrush.Dispose()
    $format.Dispose()
}

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host " ARTWORK DOWNLOADER (iTUNES API)" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

if (-not (Test-Path $MusicDir)) {
    Write-Host "[ERROR] Music directory not found at $MusicDir" -ForegroundColor Red
    exit
}

if (-not (Test-Path $ArtworkDir)) {
    New-Item -ItemType Directory -Path $ArtworkDir -Force | Out-Null
}

$Artists = Get-ChildItem -Path $MusicDir -Directory
$totalFound = 0
$totalMissing = 0

foreach ($Artist in $Artists) {
    $SearchTerm = $Artist.Name
    Write-Host "Searching: $SearchTerm" -NoNewline
    
    $FileName = "$($Artist.Name).jpg"
    $FileName = $FileName -replace '[\\/:*?"<>|]', ''
    $DestArtwork = Join-Path $ArtworkDir $FileName

    # 1. Find all folders (Artist Root + Decades + Shows) missing folder.jpg
    $AllDirs = @($Artist) + (Get-ChildItem -Path $Artist.FullName -Directory -Recurse)
    $MissingDirs = @()
    foreach ($Dir in $AllDirs) {
        $DestFolder = Join-Path $Dir.FullName "folder.jpg"
        if (-not (Test-Path $DestFolder)) {
            $MissingDirs += $DestFolder
        }
    }
    
    if ($MissingDirs.Count -eq 0) {
        Write-Host " -> [ALL FOLDERS COMPLETE, SKIPPING]" -ForegroundColor DarkGray
        continue
    }

    # 2. Check if we already have the generic artwork cached
    if (Test-Path $DestArtwork) {
        Write-Host " -> [USING CACHED ARTWORK]" -ForegroundColor Cyan
    } else {
        $Uri = "https://itunes.apple.com/search?term=$([uri]::EscapeDataString($SearchTerm))&entity=album&limit=1"
        try {
            $ImgUrl = ""
            $Response = Invoke-RestMethod -Uri $Uri -ErrorAction Stop
        if ($Response.resultCount -gt 0) {
            $ImgUrl = $Response.results[0].artworkUrl100 -replace '100x100bb.jpg', '1000x1000bb.jpg'
        } else {
            Write-Host " -> [iTUNES FAILED, TRYING THEAUDIODB...]" -ForegroundColor DarkYellow -NoNewline
            $UriAudioDB = "https://www.theaudiodb.com/api/v1/json/2/search.php?s=$([uri]::EscapeDataString($SearchTerm))"
            $ResponseADB = Invoke-RestMethod -Uri $UriAudioDB -ErrorAction Stop
            if ($null -ne $ResponseADB.artists -and $ResponseADB.artists.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace($ResponseADB.artists[0].strArtistThumb)) {
                $ImgUrl = $ResponseADB.artists[0].strArtistThumb
            }
        }

        if ($ImgUrl) {
            Invoke-WebRequest -Uri $ImgUrl -OutFile $DestArtwork -ErrorAction Stop
            Write-Host " -> [FOUND API]" -ForegroundColor Green
        } else {
            Write-Host " -> [ALL APIs FAILED, GENERATING...]" -ForegroundColor DarkYellow -NoNewline
            New-StylizedArtistImage -ArtistName $Artist.Name -OutPath $DestArtwork
            Write-Host " -> [GENERATED]" -ForegroundColor Green
        }
            $totalFound++
        } catch {
            Write-Host " -> [API ERROR: $_]" -ForegroundColor Red
            continue
        }
    }
    
    # 3. Copy artwork to all missing folders
    foreach ($DestFolder in $MissingDirs) {
        Copy-Item -Path $DestArtwork -Destination $DestFolder -Force
    }
}

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host " SUMMARY: Found: $totalFound | Missing: $totalMissing" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
