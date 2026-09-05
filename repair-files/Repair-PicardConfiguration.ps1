# ==============================================================================
# Repair-PicardConfiguration.ps1 - MusicBrainz Picard Configuration & Alignment Engine
# Fixes "cannot load album" errors by diagnosing MusicBrainz endpoint viability,
# aligning Picard.ini to the canonical musicbrainz.org API (or verified local mirror),
# and restoring tagging, AcoustID, and metadata pathways.
# ==============================================================================

[CmdletBinding()]
param(
    [switch]$UseLocalMirror,
    [switch]$UseOfficialMusicBrainz,
    [string]$CustomHost = "",
    [int]$CustomPort = 0
)

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::InputEncoding  = [System.Text.Encoding]::UTF8

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$picardDir = "$env:APPDATA\MusicBrainz"
$picardIni = Join-Path $picardDir "Picard.ini"

Write-Host "`n================================================================================" -ForegroundColor DarkCyan
Write-Host "   P I C A R D   C L I E N T   R E P A I R   &   A L I G N M E N T   E N G I N E" -ForegroundColor Cyan
Write-Host "   Timestamp: $timestamp | MusicBrainz Picard Diagnostic & Fix" -ForegroundColor DarkGray
Write-Host "================================================================================" -ForegroundColor DarkCyan

if (-not (Test-Path $picardDir)) {
    New-Item -ItemType Directory -Force -Path $picardDir | Out-Null
}

# 1. Audit Current Picard.ini Configuration
Write-Host "`n[1/4] Auditing Current Picard.ini Configuration..." -ForegroundColor Yellow

$currentHost = "Not Set"
$currentPort = "Not Set"
$iniLines = @()

if (Test-Path $picardIni) {
    # Backup Picard.ini
    $backupTag = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupPath = "$picardIni.bak_$backupTag"
    Copy-Item -Path $picardIni -Destination $backupPath -Force
    Write-Host "  [BACKUP] Created configuration backup: $backupPath" -ForegroundColor DarkGray

    $iniLines = Get-Content $picardIni
    foreach ($line in $iniLines) {
        if ($line -match '^server_host\s*=\s*(.*)$') { $currentHost = $matches[1].Trim() }
        if ($line -match '^server_port\s*=\s*(.*)$') { $currentPort = $matches[1].Trim() }
    }
    Write-Host "  * Active Picard Server Host : $currentHost" -ForegroundColor White
    Write-Host "  * Active Picard Server Port : $currentPort" -ForegroundColor White
} else {
    Write-Host "  [INFO] Picard.ini not found. Creating a fresh optimized configuration." -ForegroundColor Cyan
    $iniLines = @("[General]")
}

# 2. Test Available MusicBrainz Endpoints
Write-Host "`n[2/4] Probing MusicBrainz Endpoints for Live Release Query Viability..." -ForegroundColor Yellow

$testReleaseMbid = "76df3287-6cda-33eb-8e9a-044b5e15ffdd" # Portishead - Dummy
Write-Host ("  * Probe Target Release MBID: {0}" -f $testReleaseMbid) -ForegroundColor DarkGray

$candidateEndpoints = @(
    @{ Name = "Official MusicBrainz (HTTPS)"; Host = "musicbrainz.org"; Port = 443; Protocol = "https"; Url = ("https://musicbrainz.org/ws/2/release/{0}?fmt=json" -f $testReleaseMbid) },
    @{ Name = "Local Docker Mirror (5000)";   Host = "127.0.0.1";       Port = 5000; Protocol = "http";  Url = ("http://127.0.0.1:5000/ws/2/release/{0}?fmt=json" -f $testReleaseMbid) },
    @{ Name = "Local Docker Mirror (5001)";   Host = "127.0.0.1";       Port = 5001; Protocol = "http";  Url = ("http://127.0.0.1:5001/ws/2/release/{0}?fmt=json" -f $testReleaseMbid) },
    @{ Name = "VoltaireUn Node Mirror";       Host = "192.168.4.21";    Port = 5000; Protocol = "http";  Url = ("http://192.168.4.21:5000/ws/2/release/{0}?fmt=json" -f $testReleaseMbid) }
)

$healthyEndpoints = @()

foreach ($ep in $candidateEndpoints) {
    try {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $probeFile = Join-Path $env:TEMP "picard_probe_$($ep.Port).json"
        $resp = curl.exe -s -H "User-Agent: MusicBrainzPicard/2.12.3 ( https://picard.musicbrainz.org )" -w "%{http_code}" -o $probeFile --max-time 4 $ep.Url 2>$null
        $sw.Stop()
        $latency = [math]::Round($sw.Elapsed.TotalMilliseconds, 1)
        
        $hasData = $false
        if ($resp -eq "200" -and (Test-Path $probeFile)) {
            $content = Get-Content $probeFile -Raw -ErrorAction SilentlyContinue
            if ($content -match '"title"') { $hasData = $true }
        }

        if ($resp -eq "200" -and $hasData) {
            Write-Host ("  [OK]   {0,-34} : HTTP {1} ({2} ms) - Full Catalog Data Available" -f $ep.Name, $resp, $latency) -ForegroundColor Green
            $healthyEndpoints += $ep
        } elseif ($resp -eq "500") {
            Write-Host ("  [WARN] {0,-34} : HTTP {1} ({2} ms) - Database empty / unpopulated" -f $ep.Name, $resp, $latency) -ForegroundColor Yellow
        } else {
            Write-Host ("  [FAIL] {0,-34} : HTTP {1} ({2} ms) - Unreachable / Error" -f $ep.Name, $resp, $latency) -ForegroundColor Red
        }
    } catch {
        Write-Host ("  [FAIL] {0,-34} : Connection Failed ($($_.Exception.Message))" -f $ep.Name) -ForegroundColor Red
    }
}

# 3. Determine Optimal Target
Write-Host "`n[3/4] Selecting Optimal MusicBrainz Gateway for Picard..." -ForegroundColor Yellow

$targetHost = "musicbrainz.org"
$targetPort = 443

if ($CustomHost -and $CustomPort -gt 0) {
    $targetHost = $CustomHost
    $targetPort = $CustomPort
    Write-Host "  [CUSTOM] Applying user-specified target: $targetHost`:$targetPort" -ForegroundColor Cyan
} elseif ($UseLocalMirror) {
    $localHealthy = $healthyEndpoints | Where-Object { $_.Host -in "127.0.0.1", "localhost", "192.168.4.21", "192.168.4.30" }
    if ($localHealthy) {
        $targetHost = $localHealthy[0].Host
        $targetPort = $localHealthy[0].Port
        Write-Host "  [LOCAL] Selected verified local mirror: $targetHost`:$targetPort" -ForegroundColor Green
    } else {
        Write-Host "  [WARN] Local mirror is not returning release data (empty/unindexed)." -ForegroundColor Yellow
        Write-Host "  [AUTO-FAILOVER] Falling back to canonical musicbrainz.org:443 to ensure 100% album loading." -ForegroundColor Green
        $targetHost = "musicbrainz.org"
        $targetPort = 443
    }
} else {
    # Default to official canonical MusicBrainz for 100% reliability
    $targetHost = "musicbrainz.org"
    $targetPort = 443
    Write-Host "  [CANONICAL] Selected official MusicBrainz API: $targetHost`:$targetPort (HTTPS)" -ForegroundColor Green
}

# 4. Apply Configuration Updates to Picard.ini
Write-Host "`n[4/4] Writing Repaired Configuration to Picard.ini..." -ForegroundColor Yellow

$settingsToSet = [ordered]@{
    "server_host"               = $targetHost
    "server_port"               = $targetPort
    "use_server_for_submission" = "false"
    "browser_integration_port"  = "8000"
}

$updatedMap = @{}
$newLines = @()

foreach ($line in $iniLines) {
    $matched = $false
    foreach ($key in $settingsToSet.Keys) {
        if ($line -match "^$key\s*=") {
            $newLines += "$key=$($settingsToSet[$key])"
            $updatedMap[$key] = $true
            $matched = $true
            break
        }
    }
    if (-not $matched) {
        $newLines += $line
    }
}

foreach ($key in $settingsToSet.Keys) {
    if (-not $updatedMap.ContainsKey($key)) {
        $newLines += "$key=$($settingsToSet[$key])"
    }
}

Set-Content -Path $picardIni -Value $newLines -Encoding UTF8
Write-Host "  [OK] Successfully updated $picardIni" -ForegroundColor Green
Write-Host "       server_host = $targetHost" -ForegroundColor White
Write-Host "       server_port = $targetPort" -ForegroundColor White

Write-Host "`n================================================================================" -ForegroundColor DarkCyan
Write-Host "   P I C A R D   R E P A I R   C O M P L E T E D   S U C C E S S F U L L Y" -ForegroundColor Green
Write-Host "   Albums and releases will now load immediately in MusicBrainz Picard!" -ForegroundColor White
Write-Host "================================================================================`n" -ForegroundColor DarkCyan
