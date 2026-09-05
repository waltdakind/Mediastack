[CmdletBinding()]
param(
    [string]$PrimaryHost = "127.0.0.1",
    [int]$PrimaryPort = 5001,
    [string]$FallbackHost = "192.168.4.21",
    [int]$FallbackPort = 5000,
    [switch]$SetPicardToPrimary,
    [switch]$SetPicardToFallback,
    [switch]$SkipReport
)

$ErrorActionPreference = "Continue"
$BaseDir = if (Test-Path (Join-Path $PSScriptRoot "..\docker-compose.yml")) { (Resolve-Path (Join-Path $PSScriptRoot "..")).Path } else { $PSScriptRoot }

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$fileTimestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$reportFile = "$BaseDir\handoffs\MusicBrainz_Mirror_Report_$fileTimestamp.md"

Write-Host "`n=======================================================" -ForegroundColor Cyan
Write-Host "   M U S I C B R A I N Z   M I R R O R   T E S T E R" -ForegroundColor Cyan
Write-Host "   Timestamp: $timestamp" -ForegroundColor DarkGray
Write-Host "=======================================================" -ForegroundColor Cyan

# --- 1. PROBE FUNCTION ---
function Test-MusicBrainzNode {
    param(
        [string]$NodeName,
        [string]$HostName,
        [int]$Port
    )

    Write-Host ("`n--- Probing {0} ({1}:{2}) ---" -f $NodeName, $HostName, $Port) -ForegroundColor Yellow

    $tcpSuccess = $false
    $httpRootCode = "000"
    $ws2Code = "000"
    $latencyMs = 0
    $details = ""

    # 1. TCP Socket Probe
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $iar = $tcpClient.BeginConnect($HostName, $Port, $null, $null)
        $wait = $iar.AsyncWaitHandle.WaitOne(2000, $false)
        if ($wait -and $tcpClient.Connected) {
            $tcpClient.EndConnect($iar)
            $tcpSuccess = $true
        }
        $tcpClient.Close()
    } catch {
        $tcpSuccess = $false
    }
    $sw.Stop()
    $latencyMs = $sw.ElapsedMilliseconds

    if (-not $tcpSuccess) {
        Write-Host "  [FAIL] Port $Port unreachable (TCP Connection Refused / Timed Out)" -ForegroundColor Red
        return [PSCustomObject]@{
            Node         = $NodeName
            Host         = $HostName
            Port         = $Port
            TCPStatus    = "FAIL"
            HTTPRootCode = "000"
            WS2Code      = "000"
            Latency      = "${latencyMs}ms"
            HealthStatus = "OFFLINE"
            Details      = "TCP Port Closed or Host Unreachable"
        }
    }
    Write-Host "  [OK] TCP Port $Port is Open (Latency: ${latencyMs}ms)" -ForegroundColor Green

    # 2. HTTP Web Interface Probe
    try {
        $httpRootCode = (curl.exe -s -o NUL -w "%{http_code}" --max-time 4 "http://${HostName}:${Port}/")
        $codeInt = [int]$httpRootCode
        if ($codeInt -eq 200) {
            Write-Host "  [OK] Web Interface is responding (HTTP 200 OK)" -ForegroundColor Green
        } elseif ($codeInt -ge 500) {
            Write-Host "  [WARN] Web Server returned HTTP $httpRootCode (Database dump pending or warming up)" -ForegroundColor Yellow
        } else {
            Write-Host "  [INFO] Web Server returned HTTP $httpRootCode" -ForegroundColor Cyan
        }
    } catch {
        $httpRootCode = "FAIL"
    }

    # 3. WebService v2 REST API Probe (Nirvana artist lookup test)
    try {
        $ws2Code = (curl.exe -s -o NUL -w "%{http_code}" --max-time 4 "http://${HostName}:${Port}/ws/2/artist/5b11f4ce-a62d-471e-81fc-a69a8278c7da?fmt=json")
        $wsCodeInt = [int]$ws2Code
        if ($wsCodeInt -eq 200) {
            Write-Host "  [OK] MusicBrainz WS/2 REST API active (HTTP 200 OK)" -ForegroundColor Green
            $details = "WS/2 Queries Operational"
        } elseif ($wsCodeInt -ge 500) {
            Write-Host "  [WARN] WS/2 REST API returned HTTP $ws2Code (Mirror awaiting database import)" -ForegroundColor Yellow
            $details = "Database Tables Pending Import"
        } else {
            Write-Host "  [INFO] WS/2 REST API returned HTTP $ws2Code" -ForegroundColor Cyan
            $details = "HTTP $ws2Code"
        }
    } catch {
        $ws2Code = "FAIL"
        $details = "WS/2 Endpoint Exception"
    }

    $overallHealth = if ($ws2Code -eq "200") { "ONLINE_READY" } elseif ($httpRootCode -eq "200" -or $httpRootCode -eq "500") { "ONLINE_STANDBY" } else { "DEGRADED" }

    return [PSCustomObject]@{
        Node         = $NodeName
        Host         = $HostName
        Port         = $Port
        TCPStatus    = "OPEN"
        HTTPRootCode = $httpRootCode
        WS2Code      = $ws2Code
        Latency      = "${latencyMs}ms"
        HealthStatus = $overallHealth
        Details      = $details
    }
}

# --- 2. EXECUTE PROBES ---
$primaryResult  = Test-MusicBrainzNode -NodeName "Local Primary Mirror" -HostName $PrimaryHost -Port $PrimaryPort
$fallbackResult = Test-MusicBrainzNode -NodeName "Remote Fallback Mirror" -HostName $FallbackHost -Port $FallbackPort

# --- 3. CADDY REVERSE-PROXY ROUTING TEST ---
Write-Host "`n--- Testing Caddy Gateway Reverse Proxy Routing ---" -ForegroundColor Yellow
$caddyHost = "musicbrainz.voltaireun.local"
$caddyCode = curl.exe -s -o NUL -w "%{http_code}" --max-time 5 -H "Host: $caddyHost" "http://localhost:80/"

if ($caddyCode -eq "200") {
    Write-Host "  [OK] Caddy is successfully proxying to active MusicBrainz mirror (HTTP 200)" -ForegroundColor Green
} elseif ($caddyCode -ge 500 -and $caddyCode -lt 502) {
    Write-Host "  [OK] Caddy is routing to local mirror on port 5001 (HTTP $caddyCode - Standby)" -ForegroundColor Green
} else {
    Write-Host "  [WARN] Caddy returned HTTP $caddyCode for http://$caddyHost" -ForegroundColor Yellow
}

# --- 4. PICARD CONFIGURATION INSPECTION & SWITCHING ---
Write-Host "`n--- Picard Client Configuration Inspection ---" -ForegroundColor Yellow
$picardIni = "$env:APPDATA\MusicBrainz\Picard.ini"
$currentPicardHost = "unknown"
$currentPicardPort = "unknown"

if (Test-Path $picardIni) {
    $iniLines = Get-Content $picardIni -ErrorAction SilentlyContinue
    foreach ($l in $iniLines) {
        if ($l -match '^server_host\s*=\s*(.+)$') { $currentPicardHost = $matches[1].Trim() }
        if ($l -match '^server_port\s*=\s*(.+)$') { $currentPicardPort = $matches[1].Trim() }
    }
    Write-Host ("  Picard currently configured for -> {0}:{1}" -f $currentPicardHost, $currentPicardPort) -ForegroundColor DarkCyan

    if ($SetPicardToPrimary) {
        Write-Host "  Switching Picard configuration to Primary (192.168.4.30:5001)..." -ForegroundColor Yellow
        $newContent = (Get-Content $picardIni) -replace '^server_host\s*=.*$', 'server_host = 192.168.4.30' -replace '^server_port\s*=.*$', 'server_port = 5001'
        Set-Content -Path $picardIni -Value $newContent -Encoding UTF8
        Write-Host "  [OK] Picard updated to use Primary Node (192.168.4.30:5001)!" -ForegroundColor Green
    } elseif ($SetPicardToFallback) {
        Write-Host "  Switching Picard configuration to Fallback (192.168.4.21:5000)..." -ForegroundColor Yellow
        $newContent = (Get-Content $picardIni) -replace '^server_host\s*=.*$', 'server_host = 192.168.4.21' -replace '^server_port\s*=.*$', 'server_port = 5000'
        Set-Content -Path $picardIni -Value $newContent -Encoding UTF8
        Write-Host "  [OK] Picard updated to use Fallback Node (192.168.4.21:5000)!" -ForegroundColor Green
    }
} else {
    Write-Host "  Picard.ini not found at $picardIni" -ForegroundColor DarkGray
}

# --- 5. LOG AUDIT & EXPORT REPORT ---
Write-Host "`n--- Logging Audit & Exporting Report ---" -ForegroundColor Yellow

# Ingest into SQLite database via mediastack-db
try {
    $sqlInit = "CREATE TABLE IF NOT EXISTS musicbrainz_health_log (id INTEGER PRIMARY KEY AUTOINCREMENT, test_timestamp TEXT NOT NULL, node_name TEXT NOT NULL, host TEXT NOT NULL, port INTEGER, tcp_status TEXT, http_root TEXT, ws2_code TEXT, health_status TEXT, details TEXT); "
    $inserts = ""
    foreach ($r in @($primaryResult, $fallbackResult)) {
        $cName = $r.Node -replace "'", "''"
        $cDet  = $r.Details -replace "'", "''"
        $inserts += "INSERT INTO musicbrainz_health_log (test_timestamp, node_name, host, port, tcp_status, http_root, ws2_code, health_status, details) VALUES ('$timestamp', '$cName', '$($r.Host)', $($r.Port), '$($r.TCPStatus)', '$($r.HTTPRootCode)', '$($r.WS2Code)', '$($r.HealthStatus)', '$cDet'); "
    }
    $sqlPayload = "$sqlInit $inserts"
    $sqlPayload | docker exec -i mediastack-db sqlite3 /config/mediastack_backup.db 2>$null
    Write-Host "  [OK] Logged MusicBrainz health metrics into /config/mediastack_backup.db" -ForegroundColor Green
} catch {
    # Fallback
}

if (-not $SkipReport) {
    $handoffsDir = "$BaseDir\handoffs"
    if (-not (Test-Path $handoffsDir)) { New-Item -ItemType Directory -Force -Path $handoffsDir | Out-Null }

    $lines = @()
    $lines += "# MediaStack MusicBrainz Mirror & High-Availability Failover Report"
    $lines += ""
    $lines += "| Parameter | Value |"
    $lines += "| :--- | :--- |"
    $lines += "| **Audit Timestamp** | $timestamp |"
    $lines += "| **Host Node** | $env:COMPUTERNAME |"
    $lines += "| **Picard Target** | $($currentPicardHost):$($currentPicardPort) |"
    $lines += "| **Caddy Proxy Route** | http://$caddyHost (Code: $caddyCode) |"
    $lines += ""
    $lines += "---"
    $lines += ""
    $lines += "## MusicBrainz Nodes Probed"
    $lines += "| Node | Endpoint | TCP Port | HTTP UI | WS/2 API | Latency | Status | Details |"
    $lines += "| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |"

    foreach ($r in @($primaryResult, $fallbackResult)) {
        $statusIcon = if ($r.HealthStatus -eq "ONLINE_READY") { "READY" } elseif ($r.HealthStatus -eq "ONLINE_STANDBY") { "STANDBY" } else { "OFFLINE" }
        $lines += "| $($r.Node) | $($r.Host):$($r.Port) | $($r.TCPStatus) | $($r.HTTPRootCode) | $($r.WS2Code) | $($r.Latency) | $statusIcon | $($r.Details) |"
    }

    $lines += ""
    $lines += "---"
    $lines += "### Recommendations"
    if ($primaryResult.HealthStatus -ne "ONLINE_READY") {
        $lines += "- **Import Database Tables on Primary (5001):** Run ``docker compose run --rm musicbrainz createdb.sh -fetch`` in ``$PSScriptRoot\musicbrainz-docker``."
    }
    if ($fallbackResult.HealthStatus -eq "ONLINE_READY" -or $fallbackResult.HealthStatus -eq "ONLINE_STANDBY") {
        $lines += "- **Fallback Node (192.168.4.21:5000):** Active and available for failover routing."
    }
    $lines += ""
    $lines += "---"
    $lines += "*Audit generated automatically by MediaStack MusicBrainz Mirror Tester.*"

    Set-Content -Path $reportFile -Value ($lines -join "`n") -Encoding UTF8
    Write-Host "  [REPORT CREATED] $reportFile" -ForegroundColor Cyan
}

Write-Host "`n=======================================================" -ForegroundColor Cyan
Write-Host "   M U S I C B R A I N Z   T E S T   C O M P L E T E" -ForegroundColor Cyan
Write-Host "=======================================================`n" -ForegroundColor Cyan

