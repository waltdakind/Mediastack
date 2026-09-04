$ErrorActionPreference = 'Stop'
$BaseDir = $PSScriptRoot
$BackupDir = Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath "MediaStackBackups"

function Show-Header {
    Clear-Host
    Write-Host "=========================================================" -ForegroundColor DarkCyan
    Write-Host "  M E D I A S T A C K   D O C T O R   &   R E P A I R" -ForegroundColor Cyan
    Write-Host "  Comprehensive Health, Update, and Restoration Tool" -ForegroundColor DarkGray
    Write-Host "=========================================================" -ForegroundColor DarkCyan
    Write-Host ""
}

function Test-FileStructure {
    Show-Header
    Write-Host "[+] Verifying File Structure & Configurations..." -ForegroundColor Yellow
    
    $RequiredDirs = @(
        "$BaseDir",
        "$BaseDir\config",
        "$BaseDir\data",
        "$BaseDir\downloads",
        "$BackupDir"
    )

    $MissingDirs = 0
    foreach ($dir in $RequiredDirs) {
        if (Test-Path $dir) {
            Write-Host "    [OK] Directory exists: $dir" -ForegroundColor Green
        } else {
            Write-Host "  [FAIL] Directory missing: $dir" -ForegroundColor Red
            $MissingDirs++
        }
    }

    $RequiredFiles = @(
        "$BaseDir\docker-compose.yml"
    )

    $MissingFiles = 0
    foreach ($file in $RequiredFiles) {
        if (Test-Path $file) {
            Write-Host "    [OK] File exists: $file" -ForegroundColor Green
        } else {
            Write-Host "  [FAIL] File missing: $file" -ForegroundColor Red
            $MissingFiles++
        }
    }

    if ($MissingDirs -eq 0 -and $MissingFiles -eq 0) {
        Write-Host "`nAll essential files and directories are present." -ForegroundColor Green
    } else {
        Write-Host "`nWarning: Some files or directories are missing. A restore might be required." -ForegroundColor Yellow
    }

    Write-Host "`n[+] Verifying Windows SMB Shares..." -ForegroundColor Yellow
    $RequiredShares = @("MediaStack-Movies", "MediaStack-Shows", "MediaStack-Music", "MediaStack-TV", "MediaStack-Videos", "MediaStack-Radio", "MediaStack-Podcasts", "MediaStack-Downloads", "MediaStack-Documents")
    $MissingShares = 0
    foreach ($share in $RequiredShares) {
        $shareObj = Get-SmbShare -Name $share -ErrorAction SilentlyContinue
        if ($shareObj) {
            Write-Host "    [OK] Share online: $($shareObj.Name) -> $($shareObj.Path)" -ForegroundColor Green
        } else {
            Write-Host "  [FAIL] Share missing or offline: $share" -ForegroundColor Red
            $MissingShares++
        }
    }

    Write-Host "`nPress any key to return..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Test-DatabaseIntegrity {
    Show-Header
    Write-Host "[+] Verifying SQLite Database Integrity..." -ForegroundColor Yellow
    
    $Containers = @(
        @{ Name="sonarr"; DbPath="/config/sonarr.db" },
        @{ Name="radarr"; DbPath="/config/radarr.db" }
    )

    Set-Location -Path $BaseDir

    foreach ($app in $Containers) {
        $cName = $app.Name
        $dbPath = $app.DbPath
        Write-Host "`nTesting $cName Database ($dbPath)..." -NoNewline
        
        try {
            $check = docker exec $cName sqlite3 $dbPath "PRAGMA integrity_check;" 2>&1
            if ($check -match "ok") { 
                Write-Host " [OK] INTEGRITY VERIFIED" -ForegroundColor Green
            } else { 
                Write-Host " [ERROR] CORRUPTION DETECTED!" -ForegroundColor Red 
                Write-Host "    Details: $check" -ForegroundColor Red
            }
        } catch { 
            Write-Host " [WARN] Container Offline or SQLite Missing" -ForegroundColor DarkGray
        }
    }

    Write-Host "`nPress any key to return..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Update-DockerImages {
    Show-Header
    Write-Host "[+] Initiating Docker Image Update Process..." -ForegroundColor Yellow
    
    Set-Location -Path $BaseDir
    Write-Host "`n1. Pulling latest images..." -ForegroundColor Cyan
    docker compose pull

    Write-Host "`n2. Recreating containers with new images..." -ForegroundColor Cyan
    docker compose up -d

    Write-Host "`n3. Pruning old unused images..." -ForegroundColor Cyan
    docker image prune -f

    Write-Host "`nUpdate complete! Stack is running." -ForegroundColor Green
    Write-Host "Press any key to return..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Restore-MediaStackSafe {
    Show-Header
    Write-Host "[!] INITIATING SAFE RESTORE PROCEDURE [!]" -ForegroundColor Red
    Write-Host "This will OVERWRITE your current configuration." -ForegroundColor Yellow

    if (-not (Test-Path $BackupDir)) {
        Write-Host "`nNo backup directory found at $BackupDir" -ForegroundColor Red
        Write-Host "Press any key to return..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return
    }

    $RawBackups = Get-ChildItem -Path $BackupDir -Filter "*.zip"
    if (-not $RawBackups) {
        Write-Host "`nNo .zip backups found in $BackupDir" -ForegroundColor Red
        Write-Host "Press any key to return..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return
    }

    $Backups = Sort-Object -InputObject $RawBackups -Property CreationTime -Descending

    Write-Host "`nAvailable Backups:" -ForegroundColor Cyan
    $Index = 0
    $Backups.ForEach({
        $File = $_
        $sizeInMB = $File.Length / 1MB
        $formattedSize = "{0:N2}" -f $sizeInMB
        $backupName = $File.Name
        Write-Host "  [$Index] $backupName ($formattedSize MB)"
        $Index++
    })

    Write-Host ""
    $Selection = Read-Host "Enter the number of the backup to restore (or press Enter to cancel)"
    if ([string]::IsNullOrWhiteSpace($Selection)) { return }
    $TargetZip = $Backups[[int]$Selection]

    Write-Host "`nYou selected: $($TargetZip.Name)" -ForegroundColor Yellow
    $confirm1 = Read-Host "Are you sure you want to restore this backup? (Y/N)"
    if ($confirm1 -notmatch "^[Yy]$") { Write-Host "Aborted."; Start-Sleep -Seconds 2; return }

    Write-Host "`nWARNING: This process cannot be undone. All current configs will be deleted." -ForegroundColor Red
    $confirm2 = Read-Host "Type 'RESTORE' to confirm"
    if ($confirm2 -cne "RESTORE") { Write-Host "Aborted. You must type RESTORE exactly."; Start-Sleep -Seconds 2; return }

    Write-Host "`n1. Stopping current containers..." -ForegroundColor Yellow
    Set-Location -Path $BaseDir
    docker compose down

    Write-Host "2. Deleting corrupted configs..." -ForegroundColor Yellow
    $ConfigPath = Join-Path -Path $BaseDir -ChildPath "config"
    if (Test-Path $ConfigPath) {
        Remove-Item -Path $ConfigPath -Recurse -Force
    }

    Write-Host "3. Extracting Archive..." -ForegroundColor Yellow
    Expand-Archive -Path $TargetZip.FullName -DestinationPath $BaseDir -Force

    Write-Host "4. Booting restored stack..." -ForegroundColor Green
    docker compose up -d

    Write-Host "`nRestore complete! Operations should be back to normal." -ForegroundColor Green
    Write-Host "Press any key to return..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

$DoctorRunning = $true
while ($DoctorRunning) {
    Show-Header
    Write-Host "  [ 1 ] Check File Structure & Config States" -ForegroundColor Yellow
    Write-Host "  [ 2 ] Check Database Integrity (SQLite PRAGMA)" -ForegroundColor Magenta
    Write-Host "  [ 3 ] Update Docker Images & Recreate Stack" -ForegroundColor Cyan
    Write-Host "  [ 4 ] Safe Restore (Rollback to Previous State)" -ForegroundColor Red
    Write-Host ""
    Write-Host "  [ 5 ] Exit Doctor" -ForegroundColor Gray
    Write-Host ""

    $choice = Read-Host "  Select a diagnostic option"
    
    switch ($choice) {
        '1' { Test-FileStructure }
        '2' { Test-DatabaseIntegrity }
        '3' { Update-DockerImages }
        '4' { Restore-MediaStackSafe }
        '5' { 
            Write-Host "`n  Exiting MediaStack Doctor..." -ForegroundColor DarkCyan
            $DoctorRunning = $false 
        }
        default { Write-Host "  Invalid option." -ForegroundColor Red; Start-Sleep -Seconds 1 }
    }
}

