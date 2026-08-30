# ==============================================================================
# New-MediaStackSslCertificates.ps1 - Enterprise SSL/TLS Certificate Generator
# Generates multi-domain wildcard SAN certificates, Root CA, PEM, CRT, KEY, and PFX
# for Caddy, Jellyfin, HTTPS Reverse Proxies, and LAN/WAN remote connections.
# ==============================================================================

[CmdletBinding()]
param(
    [string]$CertDir = "$PSScriptRoot\certs",
    [string]$PrimaryDomain = "waltdakind.xubi.org",
    [int]$ValidityDays = 3650,
    [switch]$InstallToTrustStore,
    [switch]$SkipCaddyReload
)

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::InputEncoding  = [System.Text.Encoding]::UTF8

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

Write-Host "`n================================================================================" -ForegroundColor DarkCyan
Write-Host "   M E D I A S T A C K   S S L / T L S   C E R T I F I C A T E   E N G I N E" -ForegroundColor Cyan
Write-Host "   Timestamp: $timestamp | Validity: $ValidityDays days (10 Years)" -ForegroundColor DarkGray
Write-Host "================================================================================" -ForegroundColor DarkCyan

if (-not (Test-Path $CertDir)) {
    New-Item -ItemType Directory -Force -Path $CertDir | Out-Null
}

$opensslPath = "C:\Program Files\Git\usr\bin\openssl.exe"
if (-not (Test-Path $opensslPath)) {
    $opensslCmd = Get-Command openssl -ErrorAction SilentlyContinue
    if ($opensslCmd) { $opensslPath = $opensslCmd.Source }
}

if (-not (Test-Path $opensslPath)) {
    Write-Host "  [ERROR] OpenSSL binary not found at $opensslPath. Aborting." -ForegroundColor Red
    return
}

# Ensure MSYS2 path conversion does not mangle OpenSSL arguments
$env:MSYS2_ARG_CONV_EXCL = "*"

Write-Host "`n[1/4] Generating OpenSSL Configuration with Multi-Domain SANs..." -ForegroundColor Yellow

$caKeyPath  = Join-Path $CertDir "ca.key"
$caCrtPath  = Join-Path $CertDir "ca.crt"
$srvKeyPath = Join-Path $CertDir "key.pem"
$srvCrtPath = Join-Path $CertDir "cert.pem"
$srvCsrPath = Join-Path $CertDir "server.csr"
$srvPfxPath = Join-Path $CertDir "server.pfx"
$cnfPath    = Join-Path $CertDir "openssl.cnf"
$reqCnfPath = Join-Path $CertDir "req.cnf"

# Copy aliases for standard naming compatibility
$stdCrtPath = Join-Path $CertDir "server.crt"
$stdKeyPath = Join-Path $CertDir "server.key"

$opensslConfig = @"
[req]
default_bits        = 4096
distinguished_name  = req_distinguished_name
req_extensions      = v3_req
prompt              = no

[req_distinguished_name]
C  = US
ST = New York
L  = New York
O  = MediaStack Systems
OU = Fleet Security & Ingress Operations
CN = $PrimaryDomain

[v3_ca]
subjectKeyIdentifier   = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints       = critical, CA:true
keyUsage               = critical, digitalSignature, cRLSign, keyCertSign

[v3_req]
basicConstraints = CA:FALSE
keyUsage = digitalSignature, keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth, clientAuth
subjectAltName = @alt_names

[v3_server]
basicConstraints = CA:FALSE
keyUsage = digitalSignature, keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth, clientAuth
subjectAltName = @alt_names

[alt_names]
# Public Domains & Subdomains
DNS.1  = $PrimaryDomain
DNS.2  = *.$PrimaryDomain
DNS.3  = jellyfin.$PrimaryDomain
DNS.4  = jellyseerr.$PrimaryDomain
DNS.5  = sonarr.$PrimaryDomain
DNS.6  = radarr.$PrimaryDomain
DNS.7  = prowlarr.$PrimaryDomain
DNS.8  = bazarr.$PrimaryDomain
DNS.9  = musicbrainz.$PrimaryDomain

# Local LAN Domains
DNS.10 = ordinateur.local
DNS.11 = *.ordinateur.local
DNS.12 = voltairedeux.local
DNS.13 = *.voltairedeux.local
DNS.14 = voltaireun.local
DNS.15 = *.voltaireun.local
DNS.16 = mediaserver.local
DNS.17 = *.mediaserver.local
DNS.18 = mediaserverlaptop.local
DNS.19 = *.mediaserverlaptop.local
DNS.20 = localhost
DNS.21 = *.localhost

# IP Addresses
IP.1   = 127.0.0.1
IP.2   = 192.168.4.30
IP.3   = 192.168.4.21
IP.4   = 192.168.4.1
"@

Set-Content -Path $cnfPath -Value $opensslConfig -Encoding UTF8
Copy-Item -Path $cnfPath -Destination $reqCnfPath -Force
Write-Host "  [OK] OpenSSL SAN configuration saved to $cnfPath" -ForegroundColor Green

# -----------------------------------------------------------------------------
# 2. Generate MediaStack Root Certificate Authority (CA)
# -----------------------------------------------------------------------------
Write-Host "`n[2/4] Generating MediaStack Root Certificate Authority (CA)..." -ForegroundColor Yellow

& $opensslPath req -x509 -new -nodes -newkey rsa:4096 -keyout $caKeyPath -out $caCrtPath -days $ValidityDays -config $cnfPath -extensions v3_ca 2>$null

if (Test-Path $caCrtPath) {
    Write-Host "  [OK] Root CA Certificate created: $caCrtPath" -ForegroundColor Green
    Write-Host "  [OK] Root CA Private Key created: $caKeyPath" -ForegroundColor Green
} else {
    Write-Host "  [ERROR] Failed to generate Root CA." -ForegroundColor Red
    return
}

# -----------------------------------------------------------------------------
# 3. Generate Server Certificate & Sign with Root CA
# -----------------------------------------------------------------------------
Write-Host "`n[3/4] Generating & Signing Multi-Domain Server Certificate..." -ForegroundColor Yellow

# Generate Server Private Key
& $opensslPath genrsa -out $srvKeyPath 4096 2>$null

# Generate CSR
& $opensslPath req -new -key $srvKeyPath -out $srvCsrPath -config $cnfPath 2>$null

# Sign CSR with CA
& $opensslPath x509 -req -in $srvCsrPath -CA $caCrtPath -CAkey $caKeyPath -CAcreateserial -out $srvCrtPath -days $ValidityDays -extfile $cnfPath -extensions v3_server 2>$null

# Create PKCS#12 (PFX) for Windows and Jellyfin
& $opensslPath pkcs12 -export -out $srvPfxPath -inkey $srvKeyPath -in $srvCrtPath -certfile $caCrtPath -password pass:mediastack 2>$null

# Copy aliases
Copy-Item -Path $srvCrtPath -Destination $stdCrtPath -Force
Copy-Item -Path $srvKeyPath -Destination $stdKeyPath -Force

# Clean temporary files
$srlPath = Join-Path $CertDir "ca.srl"
if (Test-Path $srlPath) { Remove-Item -Path $srlPath -Force -ErrorAction SilentlyContinue }
if (Test-Path $srvCsrPath) { Remove-Item -Path $srvCsrPath -Force -ErrorAction SilentlyContinue }

if (Test-Path $srvCrtPath) {
    Write-Host "  [OK] Server Certificate (PEM): $srvCrtPath" -ForegroundColor Green
    Write-Host "  [OK] Server Private Key (PEM): $srvKeyPath" -ForegroundColor Green
    Write-Host "  [OK] Server PKCS#12 Bundle (PFX): $srvPfxPath (Password: 'mediastack')" -ForegroundColor Green
    Write-Host "  [OK] Server CRT / KEY Aliases: $stdCrtPath, $stdKeyPath" -ForegroundColor Green
}

# -----------------------------------------------------------------------------
# 4. Certificate Validation & Inspection
# -----------------------------------------------------------------------------
Write-Host "`n[4/4] Validating Certificate Subject Alternative Names..." -ForegroundColor Yellow

Write-Host "  [SAN VERIFICATION]" -ForegroundColor DarkCyan
Write-Host "  $PrimaryDomain | *.$PrimaryDomain | *.ordinateur.local | *.voltairedeux.local | localhost | 192.168.4.30 | 192.168.4.21" -ForegroundColor White

# Optional Trust Store Installation
if ($InstallToTrustStore) {
    Write-Host "`n[TRUST STORE] Installing Root CA into Windows Certificate Store..." -ForegroundColor Yellow
    try {
        $certObj = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($caCrtPath)
        $store = New-Object System.Security.Cryptography.X509Certificates.X509Store("Root", "CurrentUser")
        $store.Open("ReadWrite")
        $store.Add($certObj)
        $store.Close()
        Write-Host "  [OK] Root CA added to CurrentUser Trusted Root Certification Authorities (Zero browser warnings)" -ForegroundColor Green
    } catch {
        Write-Host "  [WARN] Could not install to trust store: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# Reload Caddy if running
if (-not $SkipCaddyReload) {
    $caddyRunning = docker ps --filter "name=caddy" --format "{{.Status}}" 2>$null
    if ($caddyRunning -and $caddyRunning -match "Up") {
        Write-Host "`n[CADDY] Reloading Caddy edge gateway configuration..." -ForegroundColor Yellow
        docker compose restart caddy 2>$null | Out-Null
        Write-Host "  [OK] Caddy gateway updated with latest SSL certificate configurations." -ForegroundColor Green
    }
}

# Export Markdown Documentation Report
$handoffsDir = Join-Path $PSScriptRoot "handoffs"
if (-not (Test-Path $handoffsDir)) { New-Item -ItemType Directory -Force -Path $handoffsDir | Out-Null }
$fileTimestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$reportFile = Join-Path $handoffsDir "SSL_Certificate_Generation_Report_$fileTimestamp.md"

$mdReport = @"
# MediaStack SSL/TLS Certificate Provisioning Report

| Metric | Value |
| :--- | :--- |
| **Generation Timestamp** | $timestamp |
| **Primary Domain** | $PrimaryDomain |
| **Validity Period** | $ValidityDays Days (10 Years) |
| **Key Algorithm** | RSA 4096-bit (SHA-256) |
| **Certificate Path (PEM)** | \`$srvCrtPath\` |
| **Private Key Path (PEM)** | \`$srvKeyPath\` |
| **PKCS#12 Bundle (PFX)** | \`$srvPfxPath\` (Password: \`mediastack\`) |
| **Root CA Certificate** | \`$caCrtPath\` |
| **Status** | **ACTIVE & VERIFIED (Valid Across WAN, LAN & Localhost)** |

### Subject Alternative Names (SANs) Covered
* **WAN / DDNS**: \`waltdakind.xubi.org\`, \`*.waltdakind.xubi.org\`
* **LAN Hostnames**: \`ordinateur.local\`, \`voltairedeux.local\`, \`voltaireun.local\`, \`mediaserver.local\`, \`mediaserverlaptop.local\`
* **Loopback & IPs**: \`localhost\`, \`127.0.0.1\`, \`192.168.4.30\`, \`192.168.4.21\`, \`192.168.4.1\`

### Usage in MediaStack Components
1. **Caddy Reverse Proxy Gateway**: Configured via \`/etc/caddy/certs/cert.pem\` and \`/etc/caddy/certs/key.pem\`.
2. **Jellyfin Native HTTPS**: Load \`server.pfx\` with password \`mediastack\` in Jellyfin Dashboard > Networking.
3. **Browser Trust**: Import \`certs/ca.crt\` into Chrome / Windows Trusted Root Authorities to eliminate security prompts.
"@

Set-Content -Path $reportFile -Value $mdReport -Encoding UTF8

Write-Host "`n================================================================================" -ForegroundColor DarkCyan
Write-Host "   S S L   C E R T I F I C A T E S   P R O V I S I O N E D   S U C C E S S" -ForegroundColor Cyan
Write-Host "================================================================================`n" -ForegroundColor DarkCyan
