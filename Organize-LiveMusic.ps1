param(
    [string]$SourceDir = "C:\Users\waltd\OneDrive\Mediastack\music",
    [switch]$DryRun,
    [switch]$Restore,
    [string]$Timestamp
)

$ErrorActionPreference = 'Stop'
$dbPath = Join-Path $SourceDir "restore_database.json"

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host " LIVE MUSIC ORGANIZER (FOLDER MODE)" -ForegroundColor Cyan
if ($DryRun) { Write-Host " [DRY RUN MODE - No files will be moved]" -ForegroundColor Yellow }
Write-Host "=============================================`n" -ForegroundColor Cyan

if (-not (Test-Path $SourceDir)) {
    Write-Error "Source directory '$SourceDir' does not exist."
}

# --- RESTORE MODE ---
if ($Restore) {
    if (-not (Test-Path $dbPath)) {
        Write-Error "Restore database not found at '$dbPath'."
    }
    $db = Get-Content $dbPath | ConvertFrom-Json
    if (-not $db -or $db.Count -eq 0) {
        Write-Host "Restore database is empty." -ForegroundColor Yellow
        exit
    }
    
    # Handle case where ConvertFrom-Json returns a single object instead of array
    if ($db.GetType().Name -ne "Object[]") { $db = @($db) }

    # Identify batches
    $batches = $db | Group-Object Timestamp | Sort-Object Name -Descending
    if ($batches.Count -eq 0) {
        Write-Host "No batches found to restore." -ForegroundColor Yellow
        exit
    }

    $targetBatch = $null
    if ($Timestamp) {
        $targetBatch = $batches | Where-Object { $_.Name -eq $Timestamp }
        if (-not $targetBatch) {
            Write-Error "No batch found with timestamp '$Timestamp'. Available: $($batches.Name -join ', ')"
        }
    } else {
        $targetBatch = $batches[0]
        Write-Host "No timestamp specified. Defaulting to most recent batch: $($targetBatch.Name)" -ForegroundColor Magenta
    }

    $itemsToRestore = $targetBatch.Group | Sort-Object OriginalPath -Descending
    Write-Host "Restoring $($itemsToRestore.Count) items from batch $($targetBatch.Name)..." -ForegroundColor Yellow

    $restoredCount = 0
    foreach ($item in $itemsToRestore) {
        Write-Host "[RESTORE] '$($item.NewPath)' -> '$($item.OriginalPath)'" -ForegroundColor Green
        if (-not $DryRun) {
            # Ensure target parent exists
            $parent = Split-Path $item.OriginalPath
            if (-not (Test-Path $parent)) {
                New-Item -ItemType Directory -Path $parent -Force | Out-Null
            }
            if (Test-Path $item.NewPath) {
                Move-Item -Path $item.NewPath -Destination $item.OriginalPath -Force
                
                # Cleanup newly empty folders
                $newParent = Split-Path $item.NewPath
                if ((Get-ChildItem -Path $newParent -Force).Count -eq 0) {
                    Remove-Item -Path $newParent -Force
                }
            } else {
                Write-Host "[WARN] Source missing: $($item.NewPath)" -ForegroundColor Red
            }
        }
        $restoredCount++
    }

    if (-not $DryRun) {
        # Remove restored items from DB
        $db = $db | Where-Object { $_.Timestamp -ne $targetBatch.Name }
        if ($db -and $db.Count -gt 0) {
            $db | ConvertTo-Json -Depth 10 | Set-Content $dbPath
        } else {
            Remove-Item $dbPath -Force
        }
    }

    Write-Host "`n=============================================" -ForegroundColor Cyan
    Write-Host " SUMMARY: Restored $restoredCount items" -ForegroundColor Cyan
    Write-Host "=============================================" -ForegroundColor Cyan
    exit
}


# --- ORGANIZE MODE ---

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
if (-not $scriptDir) { $scriptDir = (Get-Location).Path }

$mappingPath = Join-Path $scriptDir "artist_mapping.json"
$global:artistMapping = @{}
if (Test-Path $mappingPath) {
    $jsonContent = Get-Content $mappingPath -Raw | ConvertFrom-Json
    foreach ($prop in $jsonContent.psobject.properties) {
        $global:artistMapping[$prop.Name] = $prop.Value
    }
} else {
    Write-Warning "artist_mapping.json not found at $mappingPath. Using hardcoded rules."
}

$pattern = '^([A-Za-z0-9\s&]+?)[\s_-]*((?:19|20)?\d{2}[-.]\d{1,2}[-.]\d{1,2})[\s_-]*(.*)$'

$changelogPath = Join-Path $SourceDir "music_changelog.md"
$errorPath = Join-Path $SourceDir "music_errors_handoff.md"
$currentBatchTimestamp = (Get-Date).ToString("yyyyMMdd_HHmmss")

$changelog = @("# Music Organizer Changelog - $currentBatchTimestamp`n")
$errorLog = @("# Music Organizer Unmatched Files - $currentBatchTimestamp`n")

function Get-MusicInfo ($itemName) {
    if ($itemName -match $pattern) {
        $rawArtist = $matches[1].Trim().ToLower()
        $rawDate = $matches[2]
        $restOfName = $matches[3]
        
        $rawDate = $rawDate -replace '\.', '-'
        $parts = $rawDate.Split('-')
        $yearStr = $parts[0]
        $monthStr = $parts[1].PadLeft(2, '0')
        $dayStr = $parts[2].PadLeft(2, '0')

        if ($yearStr.Length -eq 2) {
            if ([int]$yearStr -le 29) {
                $yearStr = "20$yearStr"
            } else {
                $yearStr = "19$yearStr"
            }
        }

        $fullDate = "$yearStr-$monthStr-$dayStr"
        $decade = "$($yearStr.Substring(2,1))0s"

        $artist = ""
        if ($global:artistMapping.ContainsKey($rawArtist)) {
            $artist = $global:artistMapping[$rawArtist]
        } else {
            if ($DryRun) {
                if ($rawArtist.Length -le 5 -and $rawArtist -notmatch "\s") {
                    $artist = $rawArtist.ToUpper()
                } else {
                    $textInfo = (Get-Culture).TextInfo
                    $artist = $textInfo.ToTitleCase($rawArtist)
                }
            } else {
                Write-Host "`n[?] Unknown artist abbreviation found: '$rawArtist'" -ForegroundColor Yellow
                $uniqueArtists = $global:artistMapping.Values | Select-Object -Unique | Sort-Object
                $i = 1
                foreach ($ua in $uniqueArtists) {
                    Write-Host "  $i. $ua"
                    $i++
                }
                Write-Host "  $i. Other (Type manually)"
                
                $choice = ""
                while ($true) {
                    $choice = Read-Host "Select an option (1-$i) to map '$rawArtist'"
                    if ([int]::TryParse($choice, [ref]$null) -and [int]$choice -ge 1 -and [int]$choice -le $i) {
                        break
                    }
                }
                
                if ([int]$choice -eq $i) {
                    $artist = Read-Host "Enter the new Artist Name"
                } else {
                    $artist = $uniqueArtists[[int]$choice - 1]
                }
                
                $global:artistMapping[$rawArtist] = $artist
                $global:artistMapping | ConvertTo-Json -Depth 5 | Set-Content $script:mappingPath
                Write-Host "[+] Mapped '$rawArtist' -> '$artist' and saved to mapping file!`n" -ForegroundColor Green
            }
        }

        $disc = ""
        if ($restOfName -match "(?i)(?:^|\b|_|-)(?:disc|cd|d)\s*(\d+)") {
            $numString = $matches[1]
            if ($restOfName -match "(?i)(?:^|\b|_|-)(?:disc|cd|d)\s*\d+t\d+") {
                $disc = "d" + ([int]$numString)
            } elseif ($numString.Length -eq 4) {
                $disc = "d" + ([int]$numString.Substring(0,2))
            } elseif ($numString.Length -eq 3) {
                $disc = "d" + ([int]$numString.Substring(0,1))
            } else {
                $disc = "d" + ([int]$numString)
            }
        }

        return @{
            IsMatch = $true
            Artist = $artist
            Decade = $decade
            Date = $fullDate
            Disc = $disc
        }
    }
    return @{ IsMatch = $false }
}

$movedDirs = 0
$movedFiles = 0
$createdDirs = 0
$skippedCount = 0
$currentBatchTimestamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
$dbLogs = @()

if (Test-Path $dbPath) {
    $existing = Get-Content $dbPath -Raw | ConvertFrom-Json
    if ($existing) {
        if ($existing.GetType().Name -ne "Object[]") { $dbLogs += @($existing) } else { $dbLogs += $existing }
    }
}

Write-Host "--- PASS 1: PROCESSING FOLDERS ---" -ForegroundColor Yellow

$knownArtists = @($global:artistMapping.psobject.properties.value) + @("JGB", "Jerry Garcia Band", "Pink Floyd", "Phil and Friends")
$knownDecades = @("60s", "70s", "80s", "90s", "00s", "10s", "20s")

$dirs = Get-ChildItem -Path $SourceDir -Directory -Recurse | Where-Object {
    $_.FullName -notmatch "\\(?:60s|70s|80s|90s|00s|10s|20s)\\\d{4}-\d{2}-\d{2}" -and
    $knownDecades -notcontains $_.Name -and
    $knownArtists -notcontains $_.Name
}

foreach ($dir in $dirs) {
    $info = Get-MusicInfo -itemName $dir.Name
    if ($info.IsMatch) {
        $targetFolder = Join-Path $SourceDir "$($info.Artist)\$($info.Decade)\$($info.Date)"
        if ($info.Disc) {
            $targetFolder = Join-Path $targetFolder $info.Disc
        }
        
        if ($dir.FullName -eq $targetFolder) {
            Write-Host "[SKIP] Folder already in correct location: $($dir.Name)" -ForegroundColor DarkGray
            $skippedCount++
            continue
        }

        Write-Host "[MOVE FOLDER] '$($dir.Name)' -> '$targetFolder'" -ForegroundColor Green
        
        if (-not $DryRun) {
            if (-not (Test-Path $targetFolder)) {
                New-Item -ItemType Directory -Path $targetFolder -Force | Out-Null
                $createdDirs++
            }
            # Move all contents
            $contents = Get-ChildItem -Path $dir.FullName
            if ($contents.Count -gt 0) {
                foreach ($child in $contents) {
                    $destItem = Join-Path $targetFolder $child.Name
                    try {
                        Move-Item -Path $child.FullName -Destination $destItem -Force -ErrorAction Stop
                        $dbLogs += [PSCustomObject]@{
                            Timestamp = $currentBatchTimestamp
                            OriginalPath = $child.FullName
                            NewPath = $destItem
                            Type = "FileFromFolder"
                        }
                    } catch {
                        Write-Host "[ERROR] Failed to move $($child.Name): $_" -ForegroundColor Red
                        $errorCount++
                    }
                }
            }
            # Remove original folder if empty
            if (-not (Get-ChildItem -Path $dir.FullName)) {
                Remove-Item -Path $dir.FullName -Force -Recurse
            }
        }
        $changelog += "- [FOLDER] ``$($dir.Name)`` -> ``$targetFolder``"
        $movedDirs++
    } else {
        $errorLog += "- [UNMATCHED FOLDER] ``$($dir.Name)`` (Failed regex pattern)"
    }
}

Write-Host "`n--- PASS 2: PROCESSING LOOSE FILES ---" -ForegroundColor Yellow

$files = Get-ChildItem -Path $SourceDir -File -Recurse | Where-Object { 
    $_.Extension -match "\.(flac|mp3|wav|m4a|ogg|alac|txt|jpg|png|nfo)$" -and
    $_.FullName -notmatch "\\(?:60s|70s|80s|90s|00s|10s|20s)\\\d{4}-\d{2}-\d{2}\\"
}

foreach ($file in $files) {
    $info = Get-MusicInfo -itemName $file.BaseName
    if ($info.IsMatch) {
        $targetFolder = Join-Path $SourceDir "$($info.Artist)\$($info.Decade)\$($info.Date)"
        if ($info.Disc) {
            $targetFolder = Join-Path $targetFolder $info.Disc
        }
        $targetPath = Join-Path $targetFolder $file.Name

        if ($file.FullName -eq $targetPath) {
            continue
        }

        Write-Host "[MOVE FILE] '$($file.Name)' -> '$targetFolder\'" -ForegroundColor Cyan
        
        if (-not $DryRun) {
            if (-not (Test-Path $targetFolder)) {
                New-Item -ItemType Directory -Path $targetFolder -Force | Out-Null
                $createdDirs++
            }
            
            $destItem = Join-Path $targetFolder $file.Name
            try {
                Move-Item -Path $file.FullName -Destination $destItem -Force -ErrorAction Stop
                
                $dbLogs += [PSCustomObject]@{
                    Timestamp = $currentBatchTimestamp
                    OriginalPath = $file.FullName
                    NewPath = $destItem
                    Type = "LooseFile"
                }
            } catch {
                Write-Host "[ERROR] Failed to move loose file $($file.Name): $_" -ForegroundColor Red
                $errorCount++
            }
        }
        $changelog += "- [FILE] ``$($file.Name)`` -> ``$destItem``"
        $movedFiles++
    } else {
        $errorLog += "- [UNMATCHED FILE] ``$($file.Name)`` (Failed regex pattern)"
    }
}

$errorCount = if ($errorLog.Count -gt 1) { $errorLog.Count - 1 } else { 0 }

if (-not $DryRun -and ($movedDirs -gt 0 -or $movedFiles -gt 0)) {
    $dbLogs | ConvertTo-Json -Depth 10 | Set-Content $dbPath
    Write-Host "`n[LOG] Saved $($dbLogs.Count) states to restore database." -ForegroundColor Magenta
    if ($changelog.Count -gt 1) {
        $changelog | Out-File -FilePath $changelogPath -Encoding utf8 -Append
    }
}
if ($errorCount -gt 0) {
    $errorLog | Out-File -FilePath $errorPath -Encoding utf8 -Append
}

Write-Host "`n=============================================" -ForegroundColor Cyan
Write-Host " SUMMARY: Folders Moved: $movedDirs | Files Moved: $movedFiles | Folders Created: $createdDirs | Errors Thrown: $errorCount" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
