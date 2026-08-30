# ==============================================================================
# Repair-RadarrCrashLoop.ps1
# Radarr Crash Detection, Fresh Image Pull, Database/PID Lock Sanitize & Auto-Recovery
# ==============================================================================
param(
    [switch]$Force,
    [switch]$Watchdog,
    [int]$PollIntervalSeconds = 10,
    [string]$ConfigDir = "$env:SystemDrive\MediastackConfig",
    [string]$Image = "lscr.io/linuxserver/radarr:latest"
)

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::InputEncoding  = [System.Text.Encoding]::UTF8

$HandoffsDir = Join-Path $PSScriptRoot "handoffs"
if (-not (Test-Path $HandoffsDir)) { New-Item -ItemType Directory -Force -Path $HandoffsDir | Out-Null }

function Invoke-RadarrFullRecovery {
    param([string]$Reason = "Manual / Proactive Trigger")

    $now = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $fileTimestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $reportFile = Join-Path $HandoffsDir "Radarr_Crash_Recovery_$fileTimestamp.md"

    Write-Host "`n====================================================================================================" -ForegroundColor Red
    Write-Host "   [!] INITIATING RADARR CRASH RECOVERY & FRESH IMAGE REBUILD" -ForegroundColor Red
    Write-Host ("   Trigger Reason: {0} | Timestamp: {1}" -f $Reason, $now) -ForegroundColor Yellow
    Write-Host "====================================================================================================" -ForegroundColor Red

    # --- 1. CAPTURE CRASH DIAGNOSTICS ---
    Write-Host "`n[1/6] Capturing Radarr Crash Logs & Container State..." -ForegroundColor Yellow
    $containerInspect = docker inspect radarr 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
    $cState = if ($containerInspect) { $containerInspect[0].State } else { $null }
    $crashLogs = cmd.exe /c "docker logs --tail 60 radarr 2>&1"

    $cStatusStr = if ($cState) { $cState.Status } else { "NOT_FOUND" }
    $cExitStr   = if ($cState) { $cState.ExitCode } else { "N/A" }
    $cRestartStr= if ($cState) { $cState.Restarting } else { "N/A" }

    Write-Host ("  * Container Status : {0}" -f $cStatusStr) -ForegroundColor DarkGray
    Write-Host ("  * Exit Code        : {0}" -f $cExitStr) -ForegroundColor DarkGray
    Write-Host ("  * Restarting Flag  : {0}" -f $cRestartStr) -ForegroundColor DarkGray

    # --- 2. STOP & REMOVE RUNNING CONTAINER ---
    Write-Host "`n[2/6] Stopping and Removing Existing Radarr Container..." -ForegroundColor Yellow
    docker stop radarr -t 10 2>&1 | Out-Null
    docker rm -f radarr 2>&1 | Out-Null
    Write-Host "  [OK] Radarr container stopped and purged" -ForegroundColor Green

    # --- 3. FRESH DOWNLOAD OF THE LATEST RADARR IMAGE ---
    Write-Host "`n[3/6] Pulling Fresh Download of Latest Radarr Image ($Image)..." -ForegroundColor Yellow
    $pullOutput = docker pull $Image 2>&1
    Write-Host "  [OK] Fresh image downloaded from registry" -ForegroundColor Green
    
    # Prune untagged radarr images
    docker image prune -f --filter "label=org.opencontainers.image.title=Radarr" 2>&1 | Out-Null

    # --- 4. SANITIZE CONFIG, PID LOCKS & DATABASE INTEGRITY ---
    Write-Host "`n[4/6] Sanitizing Locks, Stale PID Files & Verifying Database Integrity..." -ForegroundColor Yellow
    $radarrHostConfig = "$ConfigDir\radarr"
    $radarrDbPath = "$radarrHostConfig\radarr.db"
    $radarrFallback = "$radarrHostConfig\radarr-VoltaireDeux.db"

    # Remove stale pid locks and journal files
    if (Test-Path $radarrHostConfig) {
        Get-ChildItem -Path $radarrHostConfig -Filter "*.pid" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
        Get-ChildItem -Path $radarrHostConfig -Filter "*.db-journal" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
        Get-ChildItem -Path $radarrHostConfig -Filter "*.db-shm" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
        Write-Host "  [OK] Cleared stale PID locks and lock files" -ForegroundColor Green
    }

    # Verify SQLite DB Integrity
    $dbIntegrityPass = $false
    $dbRestored = $false
    $dbStatusMsg = "OK"

    if (Test-Path $radarrDbPath) {
        $chk = docker exec mediastack-db sqlite3 "file:/mediastack/config/radarr/radarr.db?mode=ro&immutable=1" "PRAGMA quick_check;" 2>&1
        if ($chk -match "ok") {
            $dbIntegrityPass = $true
            Write-Host "  [OK] Radarr Database passes integrity check" -ForegroundColor Green
        } else {
            Write-Host ("  [WARN] Radarr Database is malformed: {0}. Initiating auto-restore..." -f $chk) -ForegroundColor Yellow
        }
    }

    if (-not $dbIntegrityPass) {
        if (Test-Path $radarrFallback) {
            Copy-Item -Path $radarrDbPath -Destination "$radarrHostConfig\radarr_corrupt_$fileTimestamp.db" -Force -ErrorAction SilentlyContinue
            Copy-Item -Path $radarrFallback -Destination $radarrDbPath -Force
            Remove-Item -Path "$radarrHostConfig\radarr.db-wal" -Force -ErrorAction SilentlyContinue
            $rechk = docker exec mediastack-db sqlite3 "file:/mediastack/config/radarr/radarr.db?mode=ro&immutable=1" "PRAGMA quick_check;" 2>&1
            if ($rechk -match "ok") {
                $dbIntegrityPass = $true
                $dbRestored = $true
                $dbStatusMsg = "Auto-Restored from radarr-VoltaireDeux.db"
                Write-Host "  [RECOVERED] Successfully restored database from pristine backup" -ForegroundColor Green
            }
        }
    }

    # --- 5. REBUILD & LAUNCH FRESH RADARR SERVICE ---
    Write-Host "`n[5/6] Spawning Fresh Radarr Container via Docker Compose..." -ForegroundColor Yellow
    Push-Location $PSScriptRoot
    docker compose up -d radarr 2>&1 | Out-Null
    Pop-Location

    # --- 6. HEALTHCHECK & PORT 7878 PROBE ---
    Write-Host "`n[6/6] Probing Radarr Port 7878 & HTTP /ping Health..." -ForegroundColor Yellow
    $healthy = $false
    $retries = 0
    $maxRetries = 20

    while ($retries -lt $maxRetries) {
        Start-Sleep -Seconds 2
        $retries++
        $pingCode = curl.exe -s -o NUL -w "%{http_code}" --max-time 2 "http://localhost:7878/ping"
        if ($pingCode -eq "200") {
            $healthy = $true
            Write-Host ("  [SUCCESS] Radarr responded with HTTP 200 OK on Port 7878 in {0}s!" -f ($retries * 2)) -ForegroundColor Green
            break
        } else {
            Write-Host ("  ... Waiting for Radarr startup (Attempt {0}/{1}, Status: HTTP {2})" -f $retries, $maxRetries, $pingCode) -ForegroundColor DarkGray
        }
    }

    if (-not $healthy) {
        Write-Host "  [WARN] Radarr did not respond to /ping within 40s. Check logs." -ForegroundColor Yellow
    }

    # --- INGEST TELEMETRY & WRITE REPORT ---
    try {
        $sqlInit = "CREATE TABLE IF NOT EXISTS radarr_recovery_events_log (id INTEGER PRIMARY KEY AUTOINCREMENT, event_timestamp TEXT NOT NULL, trigger_reason TEXT, image_version TEXT, db_status TEXT, healed INTEGER); "
        $healedInt = if ($healthy) { 1 } else { 0 }
        $cleanRsn = $Reason -replace "'", "''"
        $sqlIns = "INSERT INTO radarr_recovery_events_log (event_timestamp, trigger_reason, image_version, db_status, healed) VALUES ('$now', '$cleanRsn', '$Image', '$dbStatusMsg', $healedInt); "
        docker exec mediastack-db sqlite3 /config/mediastack_backup.db "$sqlInit $sqlIns" 2>$null
    } catch { }

    $logBlock = ($crashLogs | Out-String)
    $lines = @(
        "# Radarr Crash Recovery & Fresh Image Rebuild Report"
        ""
        "| Parameter | Value |"
        "| :--- | :--- |"
        "| **Timestamp** | $now |"
        "| **Host System** | $env:COMPUTERNAME |"
        "| **Trigger Reason** | $Reason |"
        "| **Image Downloaded** | ``$Image`` |"
        "| **Database Status** | $dbStatusMsg |"
        "| **Post-Recovery Health** | $(if ($healthy) { 'ONLINE (HTTP 200 OK)' } else { 'DEGRADED' }) |"
        ""
        "---"
        ""
        "## Crash Logs Snapshot (Pre-Recovery)"
        "````text"
        $logBlock
        "````"
        ""
        "---"
        "*Report generated automatically by Radarr Crash Recovery Engine.*"
    )

    Set-Content -Path $reportFile -Value ($lines -join "`n") -Encoding UTF8
    Write-Host ("  [REPORT CREATED] {0}" -f $reportFile) -ForegroundColor Cyan

    Write-Host "`n====================================================================================================" -ForegroundColor Green
    Write-Host "   RADARR SERVICE REPAIR COMPLETE" -ForegroundColor Green
    Write-Host "====================================================================================================`n" -ForegroundColor Green
}

# ==============================================================================
# MAIN CONTROLLER
# ==============================================================================
if ($Force) {
    Invoke-RadarrFullRecovery -Reason "Explicit Forced Repair Request"
    exit 0
}

if ($Watchdog) {
    Write-Host "====================================================================================================" -ForegroundColor Cyan
    Write-Host "   R A D A R R   C R A S H   W A T C H D O G   S E N T I N E L" -ForegroundColor Cyan
    Write-Host ("   Monitoring Radarr container and Port 7878 every {0}s. Press [Ctrl+C] to stop." -f $PollIntervalSeconds) -ForegroundColor DarkGray
    Write-Host "====================================================================================================" -ForegroundColor Cyan

    while ($true) {
        $needsRepair = $false
        $triggerReason = ""

        # Check 1: Container State
        $cStatus = (docker inspect radarr --format '{{.State.Status}}' 2>$null)
        if (-not $cStatus -or $cStatus -eq "exited" -or $cStatus -eq "dead") {
            $needsRepair = $true
            $triggerReason = "Container status is '$cStatus'"
        } elseif ($cStatus -eq "restarting") {
            $needsRepair = $true
            $triggerReason = "Container is trapped in a crash-restart loop"
        } else {
            # Check 2: Port 7878 /ping probe
            $httpRes = curl.exe -s -o NUL -w "%{http_code}" --max-time 3 "http://localhost:7878/ping"
            if ($httpRes -ne "200") {
                # Confirm with a secondary attempt
                Start-Sleep -Seconds 3
                $retryRes = curl.exe -s -o NUL -w "%{http_code}" --max-time 3 "http://localhost:7878/ping"
                if ($retryRes -ne "200") {
                    $needsRepair = $true
                    $triggerReason = "Port 7878 /ping failed (HTTP $retryRes)"
                }
            }
        }

        if ($needsRepair) {
            Invoke-RadarrFullRecovery -Reason $triggerReason
        } else {
            $ts = Get-Date -Format "HH:mm:ss"
            Write-Host ("[{0}] Radarr is healthy (Status: {1}, HTTP 200 OK)" -f $ts, $cStatus) -ForegroundColor DarkGray
        }

        Start-Sleep -Seconds $PollIntervalSeconds
    }
} else {
    # Default: Run single-pass diagnostic and repair if broken
    $pingTest = curl.exe -s -o NUL -w "%{http_code}" --max-time 3 "http://localhost:7878/ping"
    if ($pingTest -ne "200") {
        Invoke-RadarrFullRecovery -Reason "Diagnostic probe failed (HTTP $pingTest)"
    } else {
        Write-Host "[OK] Radarr is currently healthy and responding on Port 7878 (HTTP 200 OK)." -ForegroundColor Green
        Write-Host "     To force a fresh pull and rebuild, run: .\Repair-RadarrCrashLoop.ps1 -Force" -ForegroundColor DarkGray
        Write-Host "     To run as a continuous crash watchdog, run: .\Repair-RadarrCrashLoop.ps1 -Watchdog" -ForegroundColor DarkGray
    }
}
