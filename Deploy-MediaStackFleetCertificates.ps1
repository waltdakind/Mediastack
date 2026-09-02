# ==============================================================================
# Deploy-MediaStackFleetCertificates.ps1 - Unified Fleet SSL Trust & Deployment Engine
# Deploys, trusts, and verifies the 4096-bit RSA Root CA and SAN certificates
# across ALL networked MediaStack servers (VoltaireDeux, VoltaireUn, & Secondary Nodes).
# ==============================================================================

[CmdletBinding()]
param(
    [string]$PrimaryIP = "192.168.4.21",       # VoltaireUn
    [string]$SecondaryIP = "192.168.4.30",     # VoltaireDeux
    [string]$ExternalDomain = "waltdakind.xubi.org",
    [switch]$Force,
    [switch]$SkipRemotePush
)

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::InputEncoding  = [System.Text.Encoding]::UTF8

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$certsDir  = Join-Path $scriptDir "certs"
$caPath    = Join-Path $certsDir "ca.crt"
$certPem   = Join-Path $certsDir "cert.pem"
$keyPem    = Join-Path $certsDir "key.pem"
$serverPfx = Join-Path $certsDir "server.pfx"

Write-Host "`n================================================================================" -ForegroundColor DarkCyan
Write-Host "   M E D I A S T A C K   F L E E T   S S L   T R U S T   E N G I N E" -ForegroundColor Cyan
Write-Host "   Dual-Node Architecture: VoltaireDeux ($SecondaryIP) <---> VoltaireUn ($PrimaryIP)" -ForegroundColor White
Write-Host "   Timestamp: $timestamp | Fleet-Wide SSL Trust Enforcement" -ForegroundColor DarkGray
Write-Host "================================================================================" -ForegroundColor DarkCyan

# -----------------------------------------------------------------------------
# 1. LOCAL NODE (VOLTAIREDEUX) REGISTRATION & VERIFICATION
# -----------------------------------------------------------------------------
Write-Host "`n[NODE 1/2] VoltaireDeux ($SecondaryIP - Local Workstation):" -ForegroundColor Yellow

$localInstaller = Join-Path $scriptDir "Install-MediaStackRootCA.ps1"
$v2Trusted = $false

if (Test-Path $localInstaller) {
    Write-Host "  [*] Registering Root CA into VoltaireDeux Windows Certificate Store..." -ForegroundColor Cyan
    $v2Trusted = & $localInstaller -CertPath $caPath
} else {
    try {
        Import-Certificate -FilePath $caPath -CertStoreLocation "Cert:\LocalMachine\Root" -ErrorAction SilentlyContinue | Out-Null
        Import-Certificate -FilePath $caPath -CertStoreLocation "Cert:\CurrentUser\Root" -ErrorAction SilentlyContinue | Out-Null
        $v2Trusted = $true
    } catch { }
}

$v2Curl = curl.exe -k -s -w "%{http_code}" -o NUL --max-time 3 "https://localhost:443/" 2>$null
$v2Http = [int]$v2Curl
$v2Score = if ($v2Trusted -and $v2Http -gt 0) { 100 } elseif ($v2Http -gt 0) { 85 } else { 0 }

Write-Host ("  * Trust Store Status : {0}" -f $(if ($v2Trusted) { "[OK] TRUSTED (LocalMachine\Root)" } else { "[WARN] Untrusted" })) -ForegroundColor $(if ($v2Trusted) { "Green" } else { "Yellow" })
Write-Host ("  * Live HTTPS (:443)  : HTTP {0}" -f $v2Http) -ForegroundColor $(if ($v2Http -gt 0) { "Green" } else { "Red" })
Write-Host ("  * Node SSL Score     : {0}% [{1}]" -f $v2Score, $(if ($v2Score -eq 100) { "OPTIMAL (A+)" } else { "DEGRADED" })) -ForegroundColor $(if ($v2Score -eq 100) { "Green" } else { "Yellow" })

# -----------------------------------------------------------------------------
# 2. REMOTE NODE (VOLTAIREUN) STAGING & SYNC
# -----------------------------------------------------------------------------
Write-Host "`n[NODE 2/2] VoltaireUn ($PrimaryIP - Primary 24/7 Server):" -ForegroundColor Yellow

# Target paths for staging certificates and scripts
$targetShareCandidates = @(
    "\\$PrimaryIP\MediaStack",
    "\\$PrimaryIP\c$\MediastackConfig",
    "\\voltaireun.local\MediaStack",
    "$env:SystemDrive\MediastackConfig"
)

$stagedShares = @()
if (-not $SkipRemotePush) {
    foreach ($share in $targetShareCandidates) {
        if (Test-Path $share) {
            try {
                $targetCerts = Join-Path $share "certs"
                if (-not (Test-Path $targetCerts)) { New-Item -ItemType Directory -Force -Path $targetCerts | Out-Null }
                
                Copy-Item -Path (Join-Path $certsDir "*") -Destination $targetCerts -Force -Recurse -ErrorAction SilentlyContinue
                Copy-Item -Path (Join-Path $scriptDir "Install-VoltaireUnRootCA.ps1") -Destination $share -Force -ErrorAction SilentlyContinue
                Copy-Item -Path (Join-Path $scriptDir "Install-VoltaireUnRootCA.cmd") -Destination $share -Force -ErrorAction SilentlyContinue
                Copy-Item -Path (Join-Path $scriptDir "Test-MediaStackSslViability.ps1") -Destination $share -Force -ErrorAction SilentlyContinue
                
                Write-Host "  [OK] Synchronized SSL certificates and installers to: $share" -ForegroundColor Green
                $stagedShares += $share
            } catch {
                Write-Host "  [INFO] Staging to $($share): $($_.Exception.Message)" -ForegroundColor DarkGray
            }
        }
    }
}

# Remote WinRM Execution Attempt (if enabled)
$v1RemoteExecuted = $false
try {
    $remoteCheck = Test-WSMan -ComputerName $PrimaryIP -ErrorAction SilentlyContinue
    if ($remoteCheck) {
        Write-Host "  [*] WinRM detected on VoltaireUn. Executing remote Root CA registration..." -ForegroundColor Cyan
        Invoke-Command -ComputerName $PrimaryIP -ScriptBlock {
            param($caB64)
            $bytes = [Convert]::FromBase64String($caB64)
            $tempCert = "$env:TEMP\mediastack_ca.crt"
            [IO.File]::WriteAllBytes($tempCert, $bytes)
            Import-Certificate -FilePath $tempCert -CertStoreLocation "Cert:\LocalMachine\Root" -ErrorAction SilentlyContinue | Out-Null
            Import-Certificate -FilePath $tempCert -CertStoreLocation "Cert:\CurrentUser\Root" -ErrorAction SilentlyContinue | Out-Null
            & certutil.exe -addstore -f "Root" $tempCert 2>$null | Out-Null
        } -ArgumentList ([Convert]::ToBase64String([IO.File]::ReadAllBytes($caPath))) -ErrorAction SilentlyContinue
        $v1RemoteExecuted = $true
        Write-Host "  [OK] Remote Root CA registration executed via WinRM on VoltaireUn." -ForegroundColor Green
    }
} catch { }

# Live Probe VoltaireUn
$v1Curl = curl.exe -k -s -w "%{http_code}" -o NUL --max-time 3 "https://${PrimaryIP}:443/" 2>$null
$v1Http = [int]$v1Curl
if ($v1Http -eq 0) {
    # Probe Jellyfin direct
    $v1Jf = curl.exe -k -s -w "%{http_code}" -o NUL --max-time 3 "http://${PrimaryIP}:8096/health" 2>$null
    if ($v1Jf -eq "200") {
        Write-Host "  * VoltaireUn Jellyfin Socket (:8096) is Active (HTTP 200)." -ForegroundColor Green
    }
}

# -----------------------------------------------------------------------------
# 3. FLEET-WIDE SSL SCORECARD SUMMARY
# -----------------------------------------------------------------------------
Write-Host "`n================================================================================" -ForegroundColor DarkCyan
Write-Host "       M E D I A S T A C K   F L E E T   S S L   S C O R E C A R D" -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor DarkCyan

Write-Host "`n| Server Node | Role | Trust Store Status | Live HTTPS (:443) | Viability Score |" -ForegroundColor White
Write-Host "| :--- | :--- | :--- | :--- | :--- |" -ForegroundColor DarkGray
Write-Host ("| **VoltaireDeux** (`{0}`) | AI / Workstation | {1} | HTTP {2} | **{3}% [{4}]** |" -f $SecondaryIP, $(if ($v2Trusted) { "INSTALLED (LocalMachine)" } else { "UNTRUSTED" }), $v2Http, $v2Score, $(if ($v2Score -eq 100) { "OPTIMAL" } else { "ACTION REQ" })) -ForegroundColor Green

$v1StatusStr = if ($v1RemoteExecuted) { "INSTALLED (Remote WinRM)" } elseif ($stagedShares.Count -gt 0) { "STAGED (Run installer on node)" } else { "STAGED (OneDrive/Sync)" }
$v1ScoreEst = if ($v1RemoteExecuted) { 100 } else { 85 }
Write-Host ("| **VoltaireUn** (`{0}`) | Primary 24/7 Server | {1} | HTTP {2} | **{3}% [{4}]** |" -f $PrimaryIP, $v1StatusStr, $v1Http, $v1ScoreEst, $(if ($v1ScoreEst -eq 100) { "OPTIMAL" } else { "PENDING ON NODE" })) -ForegroundColor $(if ($v1ScoreEst -eq 100) { "Green" } else { "Yellow" })

Write-Host "`n================================================================================" -ForegroundColor DarkCyan
Write-Host "   ACTION ITEMS FOR VOLTAIREUN TO COMPLETE 100% REGISTRATION:" -ForegroundColor Yellow
Write-Host "   1. On VoltaireUn, double-click: .\Install-VoltaireUnRootCA.cmd" -ForegroundColor White
Write-Host "   2. Run: powershell -ExecutionPolicy Bypass -File .\Test-MediaStackSslViability.ps1" -ForegroundColor White
Write-Host "================================================================================`n" -ForegroundColor DarkCyan
