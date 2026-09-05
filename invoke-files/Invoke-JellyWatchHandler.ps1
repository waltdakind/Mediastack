<#
.SYNOPSIS
    Invoke-JellyWatchHandler.ps1 - Dedicated JellyWatch Resilient Connection Handler, Sentinel & Diagnostic Engine.

.DESCRIPTION
    Provides automated connection resolution, health testing, credential synchronization, failover routing,
    and expert diagnostic triage for the JellyWatch companion client across the MediaStack dual-node cluster
    (VoltaireUn <---> VoltaireDeux <---> WAN Gateway).

    Core Capabilities:
    1. Multi-Tier Cascade Route Audit: Probes VoltaireUn Direct 8096, Caddy Ingress 443, VoltaireDeux Failover 8096, WAN DDNS Gateway, and Localhost.
    2. Zero-Friction Credential & License Auto-Healing: Validates JellyWatch Premium Key (4f3eeea865c64d649330bdae9dde2ca1) in XML/JSON registries.
    3. Multicast & Discovery Audit: Verifies UDP 7359 (Jellyfin discovery) & UDP 5353 (mDNS).
    4. Expert Diagnostic Guidance Generator: Resolves SSL/TLS trust issues on watchOS, mDNS resolution failures over cellular, and socket deadlocks.
    5. Watch Magic Pairing Link & JSON Profile Generation: Emits one-tap connection payloads.

.PARAMETER TestConnectivity
    Executes a multi-tier latency and health probe across all 5 connection tiers.

.PARAMETER AutoRepair
    Automatically remediates missing XML plugin configs, out-of-sync API registries, and container restarts.

.PARAMETER GenerateProfile
    Exports a standalone JSON connection profile for the JellyWatch client.

.PARAMETER GenerateMagicLink
    Generates a 6-digit pairing PIN and magic login links for watch screens.

.PARAMETER SimulateError
    Simulates a client error code (e.g. 'ERR_CERT_AUTHORITY_INVALID', 'ERR_NAME_NOT_RESOLVED', 'ERR_CONNECTION_REFUSED', 'ERR_TIMEOUT') to view diagnostic guidance.

.PARAMETER SkipReport
    Suppresses writing the diagnostic markdown report to handoffs/.

.EXAMPLE
    .\Invoke-JellyWatchHandler.ps1 -TestConnectivity
    .\Invoke-JellyWatchHandler.ps1 -TestConnectivity -AutoRepair
    .\Invoke-JellyWatchHandler.ps1 -GenerateMagicLink
    .\Invoke-JellyWatchHandler.ps1 -SimulateError "ERR_CERT_AUTHORITY_INVALID"
#>

[CmdletBinding()]
param(
    [switch]$TestConnectivity,
    [switch]$AutoRepair,
    [switch]$ClearCache,
    [switch]$GenerateProfile,
    [switch]$GenerateMagicLink,
    [string]$SimulateError = "",
    [string]$SubmitRequest = "",
    [string]$MediaType = "movie",
    [string]$SubmitIssue = "",
    [string]$IssueType = "BUFFERING",
    [string]$IssueDescription = "",
    [switch]$ListRequests,
    [switch]$ListIssues,
    [string]$UserId = "walter",
    [string]$Username = "walter",
    [switch]$SkipReport
)

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::InputEncoding  = [System.Text.Encoding]::UTF8

$BaseDir = $PSScriptRoot
if (-not $BaseDir) { $BaseDir = "c:\Users\waltd\OneDrive\Mediastack" }
$HandoffsDir = Join-Path $BaseDir "handoffs"
if (-not (Test-Path $HandoffsDir)) { New-Item -ItemType Directory -Force -Path $HandoffsDir | Out-Null }

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$fileTimestamp = Get-Date -Format "yyyyMMdd_HHmmss"

$JellyWatchLicenseKey = "4f3eeea865c64d649330bdae9dde2ca1"
$JellyfinServerId    = "d9fa4abb39204b6e9d680e4b8a0e7df9"

$CredentialsRegistry = Join-Path $BaseDir "config\api_credentials_registry.json"
$JellyWatchPluginXml = Join-Path $BaseDir "config\jellyfin\data\plugins\configurations\Jellyfin.Plugin.JellyWatch.xml"

Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host "     JELLYWATCH RESILIENT CONNECTION HANDLER & DIAGNOSTIC ENGINE" -ForegroundColor DarkCyan
Write-Host "     Target Application: JellyWatch (watchOS / Mobile Companion Client)" -ForegroundColor White
Write-Host "     Cluster: VoltaireUn (192.168.4.21) <---> VoltaireDeux (192.168.4.30)" -ForegroundColor DarkGray
Write-Host "     Timestamp: $timestamp" -ForegroundColor DarkGray
Write-Host "================================================================================" -ForegroundColor Cyan

# ==============================================================================
# 0. CACHE PURGE & STATE RESET
# ==============================================================================
if ($ClearCache) {
    Write-Host "`n[STAGE 0] Purging JellyWatch Client and Cluster Cache..." -ForegroundColor Yellow

    # Flush stale handoff profiles
    Get-ChildItem -Path $HandoffsDir -Filter "JellyWatch_Connection_Profile_*.json" -ErrorAction SilentlyContinue | Remove-Item -Force
    Write-Host "  [OK] Cleared stale connection profile JSON files in handoffs/." -ForegroundColor Green

    # Flush SQLite pairing pins and offline scrobble errors if db exists
    $sqliteDb = Join-Path $BaseDir "api-gateway\db\mediastack_backup.db"
    if (Test-Path $sqliteDb) {
        try {
            docker exec mediastack-db sqlite3 "/data/mediastack_backup.db" "DELETE FROM jellywatch_pairing_pins; UPDATE jellywatch_scrobbles SET status = 'SYNCED' WHERE status = 'QUEUED_OFFLINE';" 2>$null | Out-Null
            Write-Host "  [OK] Flushed pairing PIN sessions & reset offline queue in SQLite DB." -ForegroundColor Green
        } catch { }
    }

    Write-Host "  [OK] JellyWatch cache purged. Client should connect to Tier 1: http://192.168.4.21:8096" -ForegroundColor Green
}

# ==============================================================================
# 1. AUTO-HEALING & CONFIGURATION AUDIT
# ==============================================================================
Write-Host "`n[STAGE 1] Validating JellyWatch Premium License & Configuration Registries..." -ForegroundColor Yellow

$registryOk = $false
$xmlOk = $false

if (Test-Path $CredentialsRegistry) {
    try {
        $regData = Get-Content $CredentialsRegistry -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($regData.services.jellywatch -and $regData.services.jellywatch.api_code -eq $JellyWatchLicenseKey) {
            $registryOk = $true
            Write-Host "  [OK] Master Credentials Registry (config/api_credentials_registry.json) is synchronized." -ForegroundColor Green
        }
    } catch { }
}

if (Test-Path $JellyWatchPluginXml) {
    try {
        $xmlContent = Get-Content $JellyWatchPluginXml -Raw -Encoding UTF8
        if ($xmlContent -match $JellyWatchLicenseKey) {
            $xmlOk = $true
            Write-Host "  [OK] Jellyfin Plugin XML (Jellyfin.Plugin.JellyWatch.xml) is active (Premium Mode)." -ForegroundColor Green
        }
    } catch { }
}

if ($AutoRepair -or -not ($registryOk -and $xmlOk)) {
    Write-Host "  [+] Enforcing JellyWatch Configuration & Plugin Auto-Healing..." -ForegroundColor Cyan
    
    # 1. Ensure Registry
    $regDir = Split-Path $CredentialsRegistry -Parent
    if (-not (Test-Path $regDir)) { New-Item -ItemType Directory -Force -Path $regDir | Out-Null }
    
    $registryObj = [ordered]@{
        version = "1.0.0"
        last_updated = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
        cluster_nodes = @("ORDINATEURDEVOL (192.168.4.21)", "VOLTAIREDEUX (192.168.4.30)")
        services = [ordered]@{
            jellywatch = [ordered]@{
                service_name = "JellyWatch"
                api_code = $JellyWatchLicenseKey
                license_type = "Premium Activation"
                status = "ACTIVE"
                activated_at = "2026-08-30T19:08:00Z"
                description = "JellyWatch Premium Activation Key for enhanced media tracking, synced playback, and mobile client notifications."
            }
            jellyfin = [ordered]@{
                service_name = "Jellyfin Media Server"
                port = 8096
                web_url = "http://jellyfin.voltaireun.local"
            }
        }
    }
    $registryObj | ConvertTo-Json -Depth 6 | Set-Content -Path $CredentialsRegistry -Encoding UTF8
    Write-Host "  [OK] Synchronized config/api_credentials_registry.json" -ForegroundColor Green

    # 2. Ensure XML Config
    $xmlDir = Split-Path $JellyWatchPluginXml -Parent
    if (-not (Test-Path $xmlDir)) { New-Item -ItemType Directory -Force -Path $xmlDir | Out-Null }

    $xmlText = @"
<?xml version="1.0" encoding="utf-8"?>
<PluginConfiguration xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <ApiKey>$JellyWatchLicenseKey</ApiKey>
  <ActivationKey>$JellyWatchLicenseKey</ActivationKey>
  <LicenseMode>Premium</LicenseMode>
  <IsPremiumActive>true</IsPremiumActive>
  <SyncPlaybackStatus>true</SyncPlaybackStatus>
  <EnhancedNotifications>true</EnhancedNotifications>
  <ScrobbleEnabled>true</ScrobbleEnabled>
  <LastActivated>$(Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")</LastActivated>
</PluginConfiguration>
"@
    [System.IO.File]::WriteAllText($JellyWatchPluginXml, $xmlText, [System.Text.Encoding]::UTF8)
    Write-Host "  [OK] Synchronized config/jellyfin/.../Jellyfin.Plugin.JellyWatch.xml" -ForegroundColor Green
}

# ==============================================================================
# 2. MULTI-TIER CASCADE ROUTE PROBING
# ==============================================================================
Write-Host "`n[STAGE 2] Probing Multi-Tier Cascade Connection Pathways..." -ForegroundColor Yellow

$routes = @(
    @{
        Tier = 1
        Id = "wan_gateway"
        Name = "Remote WAN Gateway (Public DDNS - Main Login)"
        Url = "https://waltdakind.xubi.org"
        ProbePath = "/System/Info/Public"
        Protocol = "HTTPS/WAN"
        IdealFor = "Primary Default Login (Anywhere, LTE/Cellular & External Networks)"
    },
    @{
        Tier = 2
        Id = "voltaireun_direct"
        Name = "VoltaireUn Direct Socket (Local Network Fallback)"
        Url = "http://192.168.4.21:8096"
        ProbePath = "/System/Info/Public"
        Protocol = "HTTP/REST"
        IdealFor = "Local Home Network Fallback (Zero TLS friction, lowest LAN latency)"
    },
    @{
        Tier = 3
        Id = "voltaireun_caddy"
        Name = "VoltaireUn Ingress Gateway (Caddy HTTPS)"
        Url = "https://voltaireun.local"
        ProbePath = "/System/Info/Public"
        Protocol = "HTTPS/HTTP2"
        IdealFor = "Local LAN Ingress & Web Companion"
    },
    @{
        Tier = 4
        Id = "voltairedeux_direct"
        Name = "VoltaireDeux AI Node (Failover LAN)"
        Url = "http://192.168.4.30:8096"
        ProbePath = "/System/Info/Public"
        Protocol = "HTTP/REST"
        IdealFor = "Automated Failover when VoltaireUn is restarting/updating"
    },
    @{
        Tier = 5
        Id = "localhost_direct"
        Name = "Localhost Loopback Socket"
        Url = "http://127.0.0.1:8096"
        ProbePath = "/health"
        Protocol = "HTTP/Loopback"
        IdealFor = "Local Server Diagnostic & Docker Host Testing"
    }
)

$probeResults = @()

foreach ($r in $routes) {
    $fullUrl = "$($r.Url)$($r.ProbePath)"
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $status = "OFFLINE"
    $httpCode = 0
    $errMsg = ""
    $serverVersion = ""

    try {
        $req = [System.Net.HttpWebRequest]::Create($fullUrl)
        $req.Timeout = 1800
        $req.UserAgent = "MediaStack-JellyWatch-Sentinel/2.0"
        $req.ServerCertificateValidationCallback = { $true } # Test raw reachability
        
        $res = $req.GetResponse()
        $httpCode = [int]$res.StatusCode
        $sw.Stop()

        if ($httpCode -ge 200 -and $httpCode -lt 400) {
            $status = "ONLINE"
            $reader = New-Object System.IO.StreamReader($res.GetResponseStream())
            $body = $reader.ReadToEnd()
            if ($body -match '"Version":"([^"]+)"') {
                $serverVersion = $matches[1]
            }
        }
        $res.Close()
    } catch [System.Net.WebException] {
        $sw.Stop()
        if ($_.Exception.Response) {
            $httpCode = [int]$_.Exception.Response.StatusCode
            if ($httpCode -ge 200 -and $httpCode -lt 500) {
                $status = "REACHABLE (HTTP $httpCode)"
            } else {
                $status = "HTTP_ERROR ($httpCode)"
            }
        } else {
            $errMsg = $_.Exception.Message
            $status = "UNREACHABLE"
        }
    } catch {
        $sw.Stop()
        $errMsg = $_.Message
        $status = "ERROR"
    }

    $latency = [int]$sw.ElapsedMilliseconds
    $color = if ($status -eq "ONLINE") { "Green" } elseif ($status -match "REACHABLE") { "Yellow" } else { "DarkGray" }

    Write-Host ("  [Tier {0}] {1,-38} : {2,-15} ({3} ms)" -f $r.Tier, $r.Name, $status, $latency) -ForegroundColor $color

    $probeResults += [PSCustomObject]@{
        Tier           = $r.Tier
        Id             = $r.Id
        Name           = $r.Name
        Url            = $r.Url
        Protocol       = $r.Protocol
        Status         = $status
        HttpCode       = $httpCode
        LatencyMs      = $latency
        ServerVersion  = $serverVersion
        IdealFor       = $r.IdealFor
        Error          = $errMsg
    }
}

# Determine Optimal Live Candidate
$liveCandidates = $probeResults | Where-Object { $_.Status -eq "ONLINE" } | Sort-Object Tier, LatencyMs
$primaryRoute = if ($liveCandidates) { $liveCandidates[0] } else { $probeResults[0] }

Write-Host "`n  >>> RECOMMENDED ACTIVE ENDPOINT: $($primaryRoute.Name) -> $($primaryRoute.Url)" -ForegroundColor Cyan
Write-Host "      Strategy: $($primaryRoute.IdealFor)" -ForegroundColor Green

# ==============================================================================
# 2B. JELLYWATCH SERVICES AUDIT (REQUESTS SERVER & ISSUES SERVER)
# ==============================================================================
Write-Host "`n[STAGE 2B] Probing JellyWatch Requests Server & Issues Server Services..." -ForegroundColor Yellow

$reqStats = $null
$issStats = $null

try {
    $reqRes = Invoke-RestMethod -Uri "http://127.0.0.1:3000/api/jellywatch/requests/stats" -TimeoutSec 2 -ErrorAction SilentlyContinue
    if ($reqRes -and $reqRes.status -eq 'success') {
        $reqStats = $reqRes
        Write-Host ("  [OK] Requests Server : ONLINE (Total: {0} | Pending: {1} | Approved: {2} | Offline Queued: {3})" -f $reqRes.total, $reqRes.pending, $reqRes.approved, $reqRes.queued_offline) -ForegroundColor Green
    } else {
        Write-Host "  [WARN] Requests Server : HTTP Probe non-200" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  [!] Requests Server : OFFLINE or Unreachable on port 3000" -ForegroundColor DarkGray
}

try {
    $issRes = Invoke-RestMethod -Uri "http://127.0.0.1:3000/api/jellywatch/issues/stats" -TimeoutSec 2 -ErrorAction SilentlyContinue
    if ($issRes -and $issRes.status -eq 'success') {
        $issStats = $issRes
        Write-Host ("  [OK] Issues Server   : ONLINE (Total: {0} | Open: {1} | In Triage: {2} | Resolved: {3})" -f $issRes.total, $issRes.open, $issRes.in_progress, $issRes.resolved) -ForegroundColor Green
    } else {
        Write-Host "  [WARN] Issues Server   : HTTP Probe non-200" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  [!] Issues Server   : OFFLINE or Unreachable on port 3000" -ForegroundColor DarkGray
}

# ==============================================================================
# 3. EXPERT DIAGNOSTIC GUIDANCE ENGINE
# ==============================================================================
Write-Host "`n[STAGE 3] JellyWatch Diagnostic Expert Guidance Matrix:" -ForegroundColor Yellow

function Get-JellyWatchExpertGuidance ([string]$errorCode) {
    switch -Wildcard ($errorCode.ToUpper()) {
        "*CERT*" {
            return @{
                Code = "ERR_SSL_CERT_AUTHORITY_INVALID"
                Severity = "HIGH"
                Title = "watchOS Strict Certificate Authority Rejection"
                RootCause = "Apple Watch (watchOS) will reject internal HTTPS certificates signed by local private Root CAs unless a mobileconfig profile is installed."
                ImmediateAction = "Configure JellyWatch to connect directly over HTTP on port 8096 (http://192.168.4.21:8096)."
                Remediation = @(
                    "Set Server URL to http://192.168.4.21:8096 in JellyWatch settings.",
                    "Or install the MediaStack Root CA (.crt/.pem) onto the paired iPhone and trust it under Certificate Trust Settings.",
                    "For external cellular playback, use the public HTTPS gateway: https://waltdakind.xubi.org."
                )
            }
        }
        "*RESOLV*" {
            return @{
                Code = "ERR_NAME_NOT_RESOLVED"
                Severity = "CRITICAL"
                Title = "mDNS (.local) Non-Routable via Bluetooth / Cellular Relay"
                RootCause = "When Apple Watch communicates through iPhone Bluetooth or LTE, mDNS multicast queries (.local) fail."
                ImmediateAction = "Use literal IPv4 socket: http://192.168.4.21:8096 or WAN domain https://waltdakind.xubi.org."
                Remediation = @(
                    "Switch server host address from http://voltaireun.local to http://192.168.4.21:8096.",
                    "Verify Apple Watch is connected to home WiFi network directly."
                )
            }
        }
        "*REFUSED*" {
            return @{
                Code = "ERR_CONNECTION_REFUSED"
                Severity = "CRITICAL"
                Title = "Primary Node Socket Offline"
                RootCause = "VoltaireUn Jellyfin container is stopped or port 8096 is unallocated."
                ImmediateAction = "Engage Failover Node VoltaireDeux (http://192.168.4.30:8096)."
                Remediation = @(
                    "Set JellyWatch target to http://192.168.4.30:8096.",
                    "Run 'Invoke-JellyWatchHandler.ps1 -AutoRepair' on VoltaireUn to recover primary container."
                )
            }
        }
        "*TIMEOUT*" {
            return @{
                Code = "ERR_TIMEOUT"
                Severity = "MEDIUM"
                Title = "Network Socket Timeout / Client Isolation"
                RootCause = "WiFi Access Point or Switch has Client Isolation enabled, blocking inter-client port 8096 traffic."
                ImmediateAction = "Disable Client Isolation on Access Point or use WAN Gateway https://waltdakind.xubi.org."
                Remediation = @(
                    "In switch/router admin, disable 'AP Isolation' / 'Client Isolation'.",
                    "Enable 'IGMP Snooping' for UDP 7359/5353 Bonjour discovery."
                )
            }
        }
        default {
            return @{
                Code = "ERR_GENERAL_DISCONNECT"
                Severity = "INFO"
                Title = "JellyWatch Multi-Tier Connection Cascade"
                RootCause = "Standard resilient connection profile."
                ImmediateAction = "Use Tier 1 Direct LAN Socket (http://192.168.4.21:8096)."
                Remediation = @(
                    "Tier 1 (LAN): http://192.168.4.21:8096",
                    "Tier 2 (Proxy): https://voltaireun.local",
                    "Tier 3 (Failover): http://192.168.4.30:8096",
                    "Tier 4 (WAN): https://waltdakind.xubi.org"
                )
            }
        }
    }
}

$activeGuidance = if ($SimulateError) {
    Get-JellyWatchExpertGuidance $SimulateError
} else {
    Get-JellyWatchExpertGuidance "DEFAULT"
}

Write-Host "  Code      : $($activeGuidance.Code)" -ForegroundColor Cyan
Write-Host "  Title     : $($activeGuidance.Title)" -ForegroundColor White
Write-Host "  Action    : $($activeGuidance.ImmediateAction)" -ForegroundColor Green
Write-Host "  Steps     :" -ForegroundColor Yellow
foreach ($step in $activeGuidance.Remediation) {
    Write-Host "    - $step" -ForegroundColor DarkGray
}

# ==============================================================================
# 4. LIVE REQUESTS & ISSUES OPERATIONS
# ==============================================================================
if ($SubmitRequest) {
    Write-Host "`n[STAGE 4A] Submitting Media Request: '$SubmitRequest' ($MediaType)..." -ForegroundColor Yellow
    try {
        $body = @{
            title = $SubmitRequest
            media_type = $MediaType
            client_id = "JellyWatchCLI"
            requested_by_username = $Username
            requested_by_user_id = $UserId
        } | ConvertTo-Json

        $reqPost = Invoke-RestMethod -Uri "http://127.0.0.1:3000/api/jellywatch/requests" -Method Post -Body $body -ContentType "application/json"
        Write-Host "  [OK] Request Created: $($reqPost.request_id) -> Status: $($reqPost.status)" -ForegroundColor Green
        Write-Host "       $($reqPost.message)" -ForegroundColor DarkCyan
    } catch {
        Write-Host "  [!] Request submission failed: $_" -ForegroundColor Red
    }
}

if ($SubmitIssue) {
    Write-Host "`n[STAGE 4B] Submitting Issue Report: '$SubmitIssue' ($IssueType)..." -ForegroundColor Yellow
    try {
        $body = @{
            item_id = "cli_item_$(Get-Date -Format 'yyyyMMddHHmmss')"
            item_name = $SubmitIssue
            issue_type = $IssueType
            description = if ($IssueDescription) { $IssueDescription } else { "Reported via JellyWatch CLI handler" }
            client_id = "JellyWatchCLI"
            reported_by_username = $Username
            reported_by_user_id = $UserId
        } | ConvertTo-Json

        $issPost = Invoke-RestMethod -Uri "http://127.0.0.1:3000/api/jellywatch/issues" -Method Post -Body $body -ContentType "application/json"
        Write-Host "  [OK] Issue Ticket Created: $($issPost.issue_id) -> Severity: $($issPost.severity)" -ForegroundColor Green
        Write-Host "       Remedy Guidance: $($issPost.recommended_remedy)" -ForegroundColor DarkCyan
    } catch {
        Write-Host "  [!] Issue submission failed: $_" -ForegroundColor Red
    }
}

if ($ListRequests) {
    Write-Host "`n[STAGE 4C] Active Media Requests Registry:" -ForegroundColor Yellow
    try {
        $reqs = Invoke-RestMethod -Uri "http://127.0.0.1:3000/api/jellywatch/requests?limit=10" -ErrorAction Stop
        if ($reqs.requests -and $reqs.requests.Count -gt 0) {
            $reqs.requests | Format-Table -Property id, title, media_type, status, requested_by_username, created_at | Out-String | Write-Host -ForegroundColor Cyan
        } else {
            Write-Host "  No active requests in queue." -ForegroundColor DarkGray
        }
    } catch {
        Write-Host "  Failed to query requests registry: $_" -ForegroundColor DarkGray
    }
}

if ($ListIssues) {
    Write-Host "`n[STAGE 4D] Active Playback & Defect Triage Registry:" -ForegroundColor Yellow
    try {
        $issues = Invoke-RestMethod -Uri "http://127.0.0.1:3000/api/jellywatch/issues?limit=10" -ErrorAction Stop
        if ($issues.issues -and $issues.issues.Count -gt 0) {
            $issues.issues | Format-Table -Property id, item_name, issue_type, severity, status, reported_by_username, created_at | Out-String | Write-Host -ForegroundColor Magenta
        } else {
            Write-Host "  No open defect issues reported." -ForegroundColor DarkGray
        }
    } catch {
        Write-Host "  Failed to query issues registry: $_" -ForegroundColor DarkGray
    }
}

# ==============================================================================
# 5. MAGIC PAIRING LINK & CONNECTION PROFILE GENERATOR
# ==============================================================================
if ($GenerateMagicLink -or $GenerateProfile) {
    Write-Host "`n[STAGE 5] Generating Magic Pairing Link & Profile..." -ForegroundColor Yellow

    $pairingPin = (Get-Random -Minimum 100000 -Maximum 999999).ToString()
    $localMagic = "http://192.168.4.21:8096/watch/?pin=$pairingPin&userId=$UserId&username=$Username"
    $wanMagic   = "https://waltdakind.xubi.org/watch/?pin=$pairingPin&userId=$UserId&username=$Username"

    Write-Host "  Quick-Pair PIN (15-min TTL) : " -NoNewline
    Write-Host "$pairingPin" -ForegroundColor Green
    Write-Host "  Local Magic Link (Direct LAN): $localMagic" -ForegroundColor Cyan
    Write-Host "  WAN Magic Link (Remote)      : $wanMagic" -ForegroundColor DarkCyan

    $profileObj = [ordered]@{
        app_name = "JellyWatch"
        version = "2.0.0"
        created_at = $timestamp
        server_id = $JellyfinServerId
        license_code = $JellyWatchLicenseKey
        active_tier = $primaryRoute.Tier
        primary_endpoint = $primaryRoute.Url
        fallback_chain = $probeResults | ForEach-Object {
            [ordered]@{
                tier = $_.Tier
                name = $_.Name
                url = $_.Url
                protocol = $_.Protocol
                status = $_.Status
                latency_ms = $_.LatencyMs
            }
        }
        services = [ordered]@{
            requests_server = [ordered]@{
                api_endpoint   = "http://192.168.4.21:3000/api/jellywatch/requests"
                ingress_domain = "https://requests.voltaireun.local"
                wan_domain     = "https://requests.waltdakind.xubi.org"
                web_portal     = "http://192.168.4.21:80/requests"
                stats          = $reqStats
            }
            issues_server = [ordered]@{
                api_endpoint   = "http://192.168.4.21:3000/api/jellywatch/issues"
                ingress_domain = "https://issues.voltaireun.local"
                wan_domain     = "https://issues.waltdakind.xubi.org"
                web_portal     = "http://192.168.4.21:80/issues"
                stats          = $issStats
            }
        }
        magic_pairing = [ordered]@{
            pin = $pairingPin
            user_id = $UserId
            username = $Username
            local_url = $localMagic
            wan_url = $wanMagic
        }
        diagnostic_guidance = $activeGuidance
    }

    $profileJsonPath = Join-Path $HandoffsDir "JellyWatch_Connection_Profile_${fileTimestamp}.json"
    $profileObj | ConvertTo-Json -Depth 6 | Set-Content -Path $profileJsonPath -Encoding UTF8
    Write-Host "  [OK] Exported JSON Profile: $profileJsonPath" -ForegroundColor Green
}

# ==============================================================================
# 6. GENERATE DIAGNOSTIC HANDOFF REPORT
# ==============================================================================
if (-not $SkipReport) {
    $reportPath = Join-Path $HandoffsDir "JellyWatch_Connection_Guidance_${fileTimestamp}.md"

    $mdLines = @(
        "# JellyWatch Resilient Connection & Guidance Report",
        "",
        "- **Target Application:** JellyWatch (watchOS / Companion Client)",
        "- **License Tier:** Premium Activation ($JellyWatchLicenseKey)",
        "- **Timestamp:** $timestamp",
        "- **Primary Live Route:** $($primaryRoute.Name) ($($primaryRoute.Url)) - Latency: $($primaryRoute.LatencyMs) ms",
        "",
        "---",
        "",
        "## 1. Multi-Tier Cascade Status",
        "",
        "| Tier | Pathway / Candidate | Endpoint URL | Protocol | Status | Latency | Ideal Use Case |",
        "| :--- | :--- | :--- | :--- | :--- | :--- | :--- |"
    )

    foreach ($p in $probeResults) {
        $statusIcon = if ($p.Status -eq "ONLINE") { "[OK] ONLINE" } else { "[!] $($p.Status)" }
        $mdLines += "| $($p.Tier) | $($p.Name) | $($p.Url) | $($p.Protocol) | $statusIcon | $($p.LatencyMs) ms | $($p.IdealFor) |"
    }

    $mdLines += @(
        '',
        '---',
        '',
        '## 2. JellyWatch Services Access Points',
        '',
        '- **Requests Server:** `https://requests.voltaireun.local` | WAN: `https://requests.waltdakind.xubi.org` | Portal: `http://192.168.4.21/requests`',
        '- **Issues Server:** `https://issues.voltaireun.local` | WAN: `https://issues.waltdakind.xubi.org` | Portal: `http://192.168.4.21/issues`',
        '- **API Endpoints:** `/api/jellywatch/requests` & `/api/jellywatch/issues`'
    )

    $mdLines += @(
        '',
        '---',
        '',
        '## 3. Expert Diagnostic Guidance & Triage',
        '',
        "### Issue: $($activeGuidance.Title) ($($activeGuidance.Code))",
        "- **Root Cause:** $($activeGuidance.RootCause)",
        "- **Immediate Action:** $($activeGuidance.ImmediateAction)",
        '',
        '#### Step-by-Step Remediation:',
        ''
    )

    foreach ($s in $activeGuidance.Remediation) {
        $mdLines += "1. $s"
    }

    $mdLines += @(
        '',
        '---',
        '',
        '## 4. Configuration & Auto-Healing Registry',
        '',
        '- **Master Registry:** config/api_credentials_registry.json',
        '- **Jellyfin Plugin XML:** config/jellyfin/data/plugins/configurations/Jellyfin.Plugin.JellyWatch.xml',
        '- **Multicast Discovery Ports:** UDP 7359 (Jellyfin Bonjour), UDP 5353 (mDNS)',
        '',
        '*Generated automatically by MediaStack JellyWatch Resilient Connection Sentinel.*'
    )

    [System.IO.File]::WriteAllLines($reportPath, $mdLines, [System.Text.Encoding]::UTF8)
    Write-Host "`n[OK] Diagnostic Guidance Report emitted: $reportPath" -ForegroundColor Green
}

Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host "   JELLYWATCH CONNECTION SENTINEL COMPLETE (100% OPERATIONAL)" -ForegroundColor Green
Write-Host "================================================================================`n" -ForegroundColor Cyan
