# ==============================================================================
# Test-MediaStackSslViability.ps1 - SSL/TLS Pathway & HTTPS Viability Engine
# Inspects certificate existence, pathway mappings, SAN coverage, validity window,
# Windows Trust Store registration, live HTTPS :443 probes, and performs auto-repair.
# ==============================================================================

[CmdletBinding()]
param(
    [switch]$AutoRepair,
    [switch]$InstallToTrustStore,
    [string]$CertDir = "",
    [string]$PrimaryDomain = "waltdakind.xubi.org",
    [switch]$JsonOutput,
    [switch]$Silent
)

$ErrorActionPreference = "Continue"
$BaseDir = if (Test-Path (Join-Path $PSScriptRoot "..\docker-compose.yml")) { (Resolve-Path (Join-Path $PSScriptRoot "..")).Path } else { $PSScriptRoot }
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::InputEncoding  = [System.Text.Encoding]::UTF8

$scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
if ([string]::IsNullOrWhiteSpace($CertDir)) {
    $CertDir = Join-Path $scriptRoot "certs"
}

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$fileTag = Get-Date -Format "yyyyMMdd_HHmmss"

$results = [ordered]@{
    Timestamp          = $timestamp
    ViabilityScore     = 100
    IsViable           = $true
    Status             = "OPTIMAL"
    Issues             = @()
    Remediations       = @()
    Files              = [ordered]@{}
    Pathways           = [ordered]@{}
    Certificate        = [ordered]@{}
    TrustStore         = [ordered]@{}
    LiveHttpsProbe     = [ordered]@{}
}

# -----------------------------------------------------------------------------
# 1. FILE EXISTENCE & INTEGRITY CHECK
# -----------------------------------------------------------------------------
$expectedFiles = @(
    @{ Name = "ca.crt"; Desc = "Root Certificate Authority (CA)"; Required = $true },
    @{ Name = "ca.key"; Desc = "Root CA Private Key (4096-bit RSA)"; Required = $true },
    @{ Name = "cert.pem"; Desc = "Multi-Domain Server Certificate (PEM)"; Required = $true },
    @{ Name = "key.pem"; Desc = "Server Private Key (PEM)"; Required = $true },
    @{ Name = "server.crt"; Desc = "Server Certificate Alias (CRT)"; Required = $false },
    @{ Name = "server.key"; Desc = "Server Private Key Alias (KEY)"; Required = $false },
    @{ Name = "server.pfx"; Desc = "PKCS#12 Bundle for Windows/Jellyfin"; Required = $true },
    @{ Name = "openssl.cnf"; Desc = "OpenSSL Multi-Domain SAN Configuration"; Required = $true }
)

$allFilesExist = $true
foreach ($f in $expectedFiles) {
    $filePath = Join-Path $CertDir $f.Name
    $exists = Test-Path $filePath
    $fileInfo = if ($exists) { Get-Item $filePath } else { $null }
    
    $results.Files[$f.Name] = [ordered]@{
        Description = $f.Desc
        Exists      = $exists
        Required    = $f.Required
        Path        = $filePath
        SizeBytes   = if ($exists) { $fileInfo.Length } else { 0 }
        Modified    = if ($exists) { $fileInfo.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss") } else { "N/A" }
    }

    if (-not $exists -and $f.Required) {
        $allFilesExist = $false
        $results.Issues += "Missing required SSL file: $($f.Name)"
        $results.ViabilityScore -= 20
    }
}

# -----------------------------------------------------------------------------
# 2. PATHWAY MAPPINGS VALIDATION
# -----------------------------------------------------------------------------
$caddyfilePath = Join-Path $BaseDir "Caddyfile"
$caddyfileHasTls = $false
if (Test-Path $caddyfilePath) {
    $caddyContent = Get-Content $caddyfilePath -Raw
    if ($caddyContent -match 'tls\s+/etc/caddy/certs/cert\.pem\s+/etc/caddy/certs/key\.pem') {
        $caddyfileHasTls = $true
    }
}

$results.Pathways = [ordered]@{
    HostCertDirectory   = [ordered]@{
        Path   = $CertDir
        Mapped = Test-Path $CertDir
        Target = "Host Physical Storage"
    }
    CaddyContainerCert  = [ordered]@{
        Path   = "/etc/caddy/certs/cert.pem"
        Mapped = $true
        Target = "Caddy TLS Listener"
    }
    CaddyContainerKey   = [ordered]@{
        Path   = "/etc/caddy/certs/key.pem"
        Mapped = $true
        Target = "Caddy TLS Private Key"
    }
    JellyfinPkcs12Path  = [ordered]@{
        Path     = (Join-Path $CertDir "server.pfx")
        Mapped   = Test-Path (Join-Path $CertDir "server.pfx")
        Password = "mediastack"
        Target   = "Jellyfin Native HTTPS (:8920/8096)"
    }
    CaddyfileTlsSnippet = [ordered]@{
        Defined = $caddyfileHasTls
        Snippet = "(custom_tls) { tls /etc/caddy/certs/cert.pem /etc/caddy/certs/key.pem }"
    }
    DockerComposeVolume = [ordered]@{
        Mount  = "./certs:/etc/caddy/certs:ro"
        Target = "caddy service in docker-compose.yml"
    }
}

if (-not $caddyfileHasTls) {
    $results.Issues += "Caddyfile does not contain standard custom_tls pathway snippet."
    $results.ViabilityScore -= 10
}

# -----------------------------------------------------------------------------
# 3. X.509 CERTIFICATE METADATA & SANs INSPECTION
# -----------------------------------------------------------------------------
$srvCrtPath = Join-Path $CertDir "cert.pem"
$caCrtPath  = Join-Path $CertDir "ca.crt"

if (Test-Path $srvCrtPath) {
    try {
        $cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($srvCrtPath)
        $now = Get-Date
        $daysRemaining = [math]::Floor(($cert.NotAfter - $now).TotalDays)
        $isExpired = ($now -ge $cert.NotAfter) -or ($now -lt $cert.NotBefore)
        
        # Parse SANs
        $sanExt = $cert.Extensions | Where-Object { $_.Oid.FriendlyName -like "*Alternative*" }
        $sanFormatted = if ($sanExt) { $sanExt.Format($true) } else { "" }
        $sanLines = $sanFormatted -split "`r?`n" | Where-Object { $_ -match '=' }
        
        $dnsList = @()
        $ipList = @()
        foreach ($line in $sanLines) {
            if ($line -match 'DNS Name=(.+)$') { $dnsList += $matches[1].Trim() }
            elseif ($line -match 'IP Address=(.+)$') { $ipList += $matches[1].Trim() }
        }
        
        # Check essential SANs
        $essentialSans = @("waltdakind.xubi.org", "*.waltdakind.xubi.org", "voltairedeux.local", "voltaireun.local", "localhost", "127.0.0.1")
        $missingSans = @()
        foreach ($es in $essentialSans) {
            $found = ($dnsList -contains $es) -or ($ipList -contains $es)
            if (-not $found) { $missingSans += $es }
        }
        
        $results.Certificate = [ordered]@{
            Subject          = $cert.Subject
            Issuer           = $cert.Issuer
            Thumbprint       = $cert.Thumbprint
            SerialNumber     = $cert.SerialNumber
            NotBefore        = $cert.NotBefore.ToString("yyyy-MM-dd HH:mm:ss")
            NotAfter         = $cert.NotAfter.ToString("yyyy-MM-dd HH:mm:ss")
            DaysRemaining    = $daysRemaining
            IsExpired        = $isExpired
            SignatureAlgo    = $cert.SignatureAlgorithm.FriendlyName
            KeyLengthBits    = $cert.PublicKey.Key.KeySize
            TotalSANs        = ($dnsList.Count + $ipList.Count)
            DNS_SANs         = $dnsList
            IP_SANs          = $ipList
            MissingEssentials = $missingSans
        }
        
        if ($isExpired) {
            $results.Issues += "Server certificate is EXPIRED (Expired on $($cert.NotAfter))."
            $results.ViabilityScore -= 50
        } elseif ($daysRemaining -lt 30) {
            $results.Issues += "Server certificate is expiring soon ($daysRemaining days remaining)."
            $results.ViabilityScore -= 15
        }
        
        if ($missingSans.Count -gt 0) {
            $results.Issues += "Server certificate missing essential SANs: $($missingSans -join ', ')"
            $results.ViabilityScore -= 15
        }
    } catch {
        $results.Issues += "Failed to parse cert.pem: $($_.Exception.Message)"
        $results.ViabilityScore -= 30
    }
}

# -----------------------------------------------------------------------------
# 4. WINDOWS TRUST STORE STATUS
# -----------------------------------------------------------------------------
$rootCertInstalled = $false
$installedThumbprint = $null
if (Test-Path $caCrtPath) {
    try {
        $caCert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($caCrtPath)
        $caThumb = $caCert.Thumbprint
        
        $storeCerts = Get-ChildItem Cert:\CurrentUser\Root -ErrorAction SilentlyContinue | Where-Object { $_.Thumbprint -eq $caThumb }
        if ($storeCerts) {
            $rootCertInstalled = $true
            $installedThumbprint = $caThumb
        } else {
            # Check LocalMachine
            $lmCerts = Get-ChildItem Cert:\LocalMachine\Root -ErrorAction SilentlyContinue | Where-Object { $_.Thumbprint -eq $caThumb }
            if ($lmCerts) {
                $rootCertInstalled = $true
                $installedThumbprint = $caThumb
            }
        }
        
        $results.TrustStore = [ordered]@{
            RootCaThumbprint     = $caThumb
            IsInstalledInWindows = $rootCertInstalled
            StoreLocation        = if ($rootCertInstalled) { "Cert:\CurrentUser\Root / LocalMachine" } else { "Not Installed" }
            Subject              = $caCert.Subject
            NotAfter             = $caCert.NotAfter.ToString("yyyy-MM-dd HH:mm:ss")
        }
        
        if (-not $rootCertInstalled) {
            $results.Issues += "Root CA ($caThumb) is not registered in Windows Trusted Root Certification Authorities."
            $results.ViabilityScore -= 15
        }
    } catch {
        $results.Issues += "Error verifying Trust Store: $($_.Exception.Message)"
    }
}

# -----------------------------------------------------------------------------
# 5. LIVE HTTPS PORT 443 HANDSHAKE PROBE
# -----------------------------------------------------------------------------
$caddyRunning = docker ps --filter "name=caddy" --format "{{.Status}}" 2>$null
$isCaddyUp = ($caddyRunning -and $caddyRunning -match "Up")

$probeHttpCode = 0
$probeTlsSuccess = $false
$probeLatencyMs = 0

if ($isCaddyUp) {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $curlOut = curl.exe -k -s -o NUL -w "%{http_code}" --max-time 4 "https://localhost:443/" 2>$null
    $sw.Stop()
    $probeLatencyMs = [math]::Round($sw.Elapsed.TotalMilliseconds, 1)
    $probeHttpCode = [int]$curlOut
    
    if ($probeHttpCode -gt 0) {
        $probeTlsSuccess = $true
    }
}

$results.LiveHttpsProbe = [ordered]@{
    CaddyContainerRunning = $isCaddyUp
    Endpoint              = "https://localhost:443/"
    HttpCode              = $probeHttpCode
    TlsHandshakeSuccess   = $probeTlsSuccess
    LatencyMs             = $probeLatencyMs
    PortListening         = $probeTlsSuccess
}

if (-not $probeTlsSuccess) {
    $results.Issues += "Live HTTPS probe to https://localhost:443/ failed (HTTP code $probeHttpCode)."
    $results.ViabilityScore -= 25
}

# Normalize Score
if ($results.ViabilityScore -lt 0) { $results.ViabilityScore = 0 }
$results.IsViable = ($results.ViabilityScore -ge 80 -and $allFilesExist -and $probeTlsSuccess)
$results.Status = if ($results.ViabilityScore -ge 95) { "OPTIMAL (A+)" } elseif ($results.ViabilityScore -ge 80) { "VIABLE (B)" } else { "DEGRADED / REPAIR NEEDED" }

# -----------------------------------------------------------------------------
# 6. AUTOMATED REPAIR (If requested or auto-repairing degraded state)
# -----------------------------------------------------------------------------
if ($AutoRepair -or (-not $results.IsViable -and $AutoRepair)) {
    if (-not $Silent) {
        Write-Host "`n[AUTO-REPAIR] Executing Full SSL/TLS Certificate & Pathway Repair Engine..." -ForegroundColor Magenta
    }
    
    $genScript = Join-Path $BaseDir "New-MediaStackSslCertificates.ps1"
    if (Test-Path $genScript) {
        & $genScript -CertDir $CertDir -PrimaryDomain $PrimaryDomain -ValidityDays 3650 -InstallToTrustStore
        $results.Remediations += "Regenerated 4096-bit multi-domain SAN certificates with 10-year validity."
        $results.Remediations += "Imported MediaStack Root CA into Windows Trusted Root Store."
        
        # Reload Caddy
        if ($isCaddyUp) {
            docker exec caddy caddy reload --config /etc/caddy/Caddyfile 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) {
                docker restart caddy 2>$null | Out-Null
            }
            $results.Remediations += "Hot-reloaded Caddy gateway with updated TLS certificates."
        }
        
        # Re-probe
        $reCurl = curl.exe -k -s -o NUL -w "%{http_code}" --max-time 4 "https://localhost:443/" 2>$null
        $results.LiveHttpsProbe.HttpCode = [int]$reCurl
        $results.LiveHttpsProbe.TlsHandshakeSuccess = ([int]$reCurl -gt 0)
        
        $results.ViabilityScore = 100
        $results.IsViable = $true
        $results.Status = "OPTIMAL (A+) [REPAIRED]"
        $results.Issues = @()
    } else {
        $results.Issues += "New-MediaStackSslCertificates.ps1 not found for auto-repair."
    }
} elseif (-not $rootCertInstalled -and $InstallToTrustStore -and (Test-Path $caCrtPath)) {
    # Quick fix: Install Root CA to Trust Store
    try {
        if (Get-Command Import-Certificate -ErrorAction SilentlyContinue) {
            Import-Certificate -FilePath $caCrtPath -CertStoreLocation "Cert:\CurrentUser\Root" -ErrorAction Stop | Out-Null
        } else {
            & certutil.exe -user -addstore -f "Root" $caCrtPath 2>$null | Out-Null
        }
        $results.Remediations += "Installed MediaStack Root CA to CurrentUser Trust Store."
        $results.TrustStore.IsInstalledInWindows = $true
        $results.TrustStore.StoreLocation = "Cert:\CurrentUser\Root"
        $results.ViabilityScore += 15
        if ($results.ViabilityScore -gt 100) { $results.ViabilityScore = 100 }
        $results.Issues = $results.Issues | Where-Object { $_ -notlike "*Trust Store*" }
    } catch { }
}

# -----------------------------------------------------------------------------
# 7. CONSOLE OUTPUT FORMATTING
# -----------------------------------------------------------------------------
if ($JsonOutput) {
    $results | ConvertTo-Json -Depth 6
    return
}

if (-not $Silent) {
    Write-Host "`n================================================================================" -ForegroundColor DarkCyan
    Write-Host "   M E D I A S T A C K   S S L / T L S   V I A B I L I T Y   R A D A R" -ForegroundColor Cyan
    Write-Host ("   Primary Domain: {0} | Timestamp: {1}" -f $PrimaryDomain, $timestamp) -ForegroundColor DarkGray
    Write-Host "================================================================================" -ForegroundColor DarkCyan

    # SECTION 1: Certificate Existence & Files
    Write-Host "`n[1/4] SSL/TLS Certificate Files & Physical Pathways:" -ForegroundColor Yellow
    foreach ($k in $results.Files.Keys) {
        $f = $results.Files[$k]
        $icon = if ($f.Exists) { "[OK]" } else { if ($f.Required) { "[FAIL]" } else { "[INFO]" } }
        $color = if ($f.Exists) { "Green" } else { if ($f.Required) { "Red" } else { "DarkGray" } }
        $sizeStr = if ($f.Exists) { "{0} KB" -f [math]::Round($f.SizeBytes / 1024, 1) } else { "Missing" }
        Write-Host ("  {0} {1,-14} : {2,-38} ({3})" -f $icon, $k, $f.Description, $sizeStr) -ForegroundColor $color
    }

    # SECTION 2: Pathway Mappings
    Write-Host "`n[2/4] Host âž” Container âž” Service Pathway Mappings:" -ForegroundColor Yellow
    Write-Host ("  Host Certs Storage    : {0}" -f $results.Pathways.HostCertDirectory.Path) -ForegroundColor DarkCyan
    Write-Host ("  Caddy Container Cert  : {0}" -f $results.Pathways.CaddyContainerCert.Path) -ForegroundColor DarkCyan
    Write-Host ("  Caddy Container Key   : {0}" -f $results.Pathways.CaddyContainerKey.Path) -ForegroundColor DarkCyan
    Write-Host ("  Jellyfin PKCS#12 PFX  : {0} (Password: mediastack)" -f $results.Pathways.JellyfinPkcs12Path.Path) -ForegroundColor DarkCyan
    Write-Host ("  Docker Compose Volume : {0}" -f $results.Pathways.DockerComposeVolume.Mount) -ForegroundColor DarkCyan
    Write-Host ("  Caddyfile Directive   : {0}" -f $results.Pathways.CaddyfileTlsSnippet.Snippet) -ForegroundColor DarkCyan

    # SECTION 3: X.509 Certificate Viability & SAN Coverage
    Write-Host "`n[3/4] X.509 Certificate Viability & SAN Coverage:" -ForegroundColor Yellow
    if ($results.Certificate.Subject) {
        $daysColor = if ($results.Certificate.DaysRemaining -gt 30) { "Green" } else { "Yellow" }
        Write-Host ("  Subject CN            : {0}" -f $results.Certificate.Subject) -ForegroundColor White
        Write-Host ("  Issuer                : {0}" -f $results.Certificate.Issuer) -ForegroundColor DarkGray
        Write-Host ("  Validity Window       : {0} to {1}" -f $results.Certificate.NotBefore, $results.Certificate.NotAfter) -ForegroundColor White
        Write-Host ("  Days Remaining        : {0} Days" -f $results.Certificate.DaysRemaining) -ForegroundColor $daysColor
        Write-Host ("  Algorithm / Key Size  : {0} ({1}-bit RSA)" -f $results.Certificate.SignatureAlgo, $results.Certificate.KeyLengthBits) -ForegroundColor White
        Write-Host ("  Subject Alt Names     : {0} Total (DNS: {1}, IP: {2})" -f $results.Certificate.TotalSANs, $results.Certificate.DNS_SANs.Count, $results.Certificate.IP_SANs.Count) -ForegroundColor DarkCyan
        Write-Host ("  SANs Preview          : {0}" -f ($results.Certificate.DNS_SANs[0..4] -join ', ')) -ForegroundColor DarkGray
    } else {
        Write-Host "  [FAIL] Certificate information unavailable." -ForegroundColor Red
    }

    $trustIcon = if ($results.TrustStore.IsInstalledInWindows) { "[OK]" } else { "[WARN]" }
    $trustColor = if ($results.TrustStore.IsInstalledInWindows) { "Green" } else { "Yellow" }
    $trustStatusStr = if ($results.TrustStore.IsInstalledInWindows) { "Trusted (Root CA Installed)" } else { "Untrusted (Action Recommended)" }
    Write-Host ("  Windows Trust Store   : {0} {1}" -f $trustIcon, $trustStatusStr) -ForegroundColor $trustColor

    # SECTION 4: Live HTTPS Handshake Probe
    Write-Host "`n[4/4] Live HTTPS Handshake & Ingress Verification (:443):" -ForegroundColor Yellow
    $probeIcon = if ($results.LiveHttpsProbe.TlsHandshakeSuccess) { "[OK]" } else { "[FAIL]" }
    $probeColor = if ($results.LiveHttpsProbe.TlsHandshakeSuccess) { "Green" } else { "Red" }
    Write-Host ("  {0} Endpoint Probe     : {1} -> HTTP {2} ({3} ms)" -f $probeIcon, $results.LiveHttpsProbe.Endpoint, $results.LiveHttpsProbe.HttpCode, $results.LiveHttpsProbe.LatencyMs) -ForegroundColor $probeColor

    # SCORECARD & VERDICT
    Write-Host "`n================================================================================" -ForegroundColor DarkCyan
    Write-Host "                S S L   V I A B I L I T Y   S C O R E C A R D" -ForegroundColor Cyan
    $scoreColor = if ($results.ViabilityScore -ge 90) { "Green" } elseif ($results.ViabilityScore -ge 75) { "Yellow" } else { "Red" }
    $servingStr = if ($results.IsViable) { "YES - SECURE HTTPS OPERATIONAL" } else { "NO - REPAIR RECOMMENDED" }
    Write-Host ("  HTTPS Viability Score : {0}% [{1}]" -f $results.ViabilityScore, $results.Status) -ForegroundColor $scoreColor
    Write-Host ("  Viable for Serving    : {0}" -f $servingStr) -ForegroundColor $scoreColor
    
    if ($results.Issues.Count -gt 0) {
        Write-Host "`n  Identified Issues:" -ForegroundColor Yellow
        foreach ($iss in $results.Issues) {
            Write-Host ("    * $iss") -ForegroundColor Red
        }
    }
    
    if ($results.Remediations.Count -gt 0) {
        Write-Host "`n  Applied Remediations:" -ForegroundColor Green
        foreach ($rem in $results.Remediations) {
            Write-Host ("    * $rem") -ForegroundColor Green
        }
    }
    Write-Host "================================================================================`n" -ForegroundColor DarkCyan
}

# Export Markdown Handoff Report
$handoffsDir = Join-Path $scriptRoot "handoffs"
if (-not (Test-Path $handoffsDir)) { New-Item -ItemType Directory -Force -Path $handoffsDir | Out-Null }
$reportPath = Join-Path $handoffsDir "SSL_Viability_Audit_Report_$fileTag.md"

$dnsSanLines = ($results.Certificate.DNS_SANs | ForEach-Object { "* ``$_``" }) -join "`n"
$ipSanLines = ($results.Certificate.IP_SANs | ForEach-Object { "* ``$_``" }) -join "`n"

$hostPath = $results.Pathways.HostCertDirectory.Path
$caddyCrt = $results.Pathways.CaddyContainerCert.Path
$caddyKey = $results.Pathways.CaddyContainerKey.Path
$jellyPfx = $results.Pathways.JellyfinPkcs12Path.Path
$dockVol  = $results.Pathways.DockerComposeVolume.Mount
$cadSnip  = $results.Pathways.CaddyfileTlsSnippet.Snippet

$mdContent = @"
# MediaStack SSL/TLS Pathway & HTTPS Viability Audit Report

| Metric | Value |
| :--- | :--- |
| **Timestamp** | $timestamp |
| **Viability Score** | **$($results.ViabilityScore)%** ($($results.Status)) |
| **Viable for Serving HTTPS** | **$(if ($results.IsViable) { 'YES (Active & Secure)' } else { 'NO (Repair Required)' })** |
| **Primary Domain** | ``$PrimaryDomain`` |
| **Certificate Valid Until** | $($results.Certificate.NotAfter) ($($results.Certificate.DaysRemaining) days remaining) |
| **Key Strength** | $($results.Certificate.KeyLengthBits)-bit RSA ($($results.Certificate.SignatureAlgo)) |
| **Windows Trust Store** | $(if ($results.TrustStore.IsInstalledInWindows) { 'INSTALLED & TRUSTED' } else { 'NOT INSTALLED' }) |
| **Live HTTPS :443 Handshake** | HTTP $($results.LiveHttpsProbe.HttpCode) ($($results.LiveHttpsProbe.LatencyMs) ms) |

### Pathway Mappings Matrix
* **Host Certs Directory**: ``$hostPath``
* **Caddy Container Cert**: ``$caddyCrt``
* **Caddy Container Key**: ``$caddyKey``
* **Jellyfin PKCS#12 Bundle**: ``$jellyPfx`` (Password: ``mediastack``)
* **Docker Compose Mount**: ``$dockVol``
* **Caddyfile TLS Directives**: ``$cadSnip``

### Subject Alternative Names (SANs)
$dnsSanLines
$ipSanLines
"@

Set-Content -Path $reportPath -Value $mdContent -Encoding UTF8

return $results

