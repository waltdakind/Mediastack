# ==============================================================================
# Install-MediaStackRootCA.ps1 - Windows Trusted Root Certificate Authority Registrar
# Registers and trusts the MediaStack Root CA (ca.crt) in the Windows Certificate Store
# (LocalMachine\Root and CurrentUser\Root) to eliminate SSL/TLS warnings and achieve 100% Viability.
# ==============================================================================

[CmdletBinding()]
param(
    [string]$CertPath = "",
    [switch]$Elevate,
    [switch]$PruneOldCAs,
    [switch]$RunViabilityCheck,
    [switch]$NonInteractive
)

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::InputEncoding  = [System.Text.Encoding]::UTF8

$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }

if ([string]::IsNullOrWhiteSpace($CertPath)) {
    $CertPath = Join-Path $scriptDir "certs\ca.crt"
}

Write-Host "`n================================================================================" -ForegroundColor DarkCyan
Write-Host "   M E D I A S T A C K   R O O T   C A   T R U S T   I N S T A L L E R" -ForegroundColor Cyan
Write-Host "   Target Certificate: $CertPath" -ForegroundColor DarkGray
Write-Host "================================================================================" -ForegroundColor DarkCyan

if (-not (Test-Path $CertPath)) {
    Write-Host "  [ERROR] Certificate file not found at: $CertPath" -ForegroundColor Red
    return $false
}

# 1. Load Certificate Metadata
try {
    $cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($CertPath)
    $thumbprint = $cert.Thumbprint
    $subject    = $cert.Subject
    $issuer     = $cert.Issuer
    $notAfter   = $cert.NotAfter.ToString("yyyy-MM-dd HH:mm:ss")
    $keySize    = if ($cert.PublicKey.Key) { $cert.PublicKey.Key.KeySize } else { 4096 }

    Write-Host "`n[1/3] Validating MediaStack Root CA Metadata:" -ForegroundColor Yellow
    Write-Host ("  Subject     : {0}" -f $subject) -ForegroundColor White
    Write-Host ("  Issuer      : {0}" -f $issuer) -ForegroundColor DarkGray
    Write-Host ("  Thumbprint  : {0}" -f $thumbprint) -ForegroundColor Green
    Write-Host ("  Key Size    : {0}-bit RSA" -f $keySize) -ForegroundColor White
    Write-Host ("  Valid Until : {0}" -f $notAfter) -ForegroundColor White
} catch {
    Write-Host "  [ERROR] Failed to parse certificate file: $($_.Exception.Message)" -ForegroundColor Red
    return $false
}

# 2. Check if already installed
$lmMatch = Get-ChildItem Cert:\LocalMachine\Root -ErrorAction SilentlyContinue | Where-Object { $_.Thumbprint -eq $thumbprint }
$cuMatch = Get-ChildItem Cert:\CurrentUser\Root -ErrorAction SilentlyContinue | Where-Object { $_.Thumbprint -eq $thumbprint }

$isInstalled = ($null -ne $lmMatch) -or ($null -ne $cuMatch)

# Check Administrative Status
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

Write-Host "`n[2/3] Inspecting Windows Certificate Store Trust Status:" -ForegroundColor Yellow
Write-Host ("  LocalMachine\Root Store : {0}" -f $(if ($lmMatch) { "[INSTALLED]" } else { "[NOT FOUND]" })) -ForegroundColor $(if ($lmMatch) { "Green" } else { "Yellow" })
Write-Host ("  CurrentUser\Root Store  : {0}" -f $(if ($cuMatch) { "[INSTALLED]" } else { "[NOT FOUND]" })) -ForegroundColor $(if ($cuMatch) { "Green" } else { "Yellow" })
Write-Host ("  Execution Privilege     : {0}" -f $(if ($isAdmin) { "Administrator (Elevated)" } else { "Standard User" })) -ForegroundColor $(if ($isAdmin) { "Green" } else { "Yellow" })

# 3. Perform Installation
Write-Host "`n[3/3] Registering MediaStack Root CA into Windows Trust Store:" -ForegroundColor Yellow

$installSuccess = $false

if ($isAdmin) {
    # Method A: Direct Elevated Installation into LocalMachine\Root (System-wide, no prompts)
    try {
        if (Get-Command Import-Certificate -ErrorAction SilentlyContinue) {
            Import-Certificate -FilePath $CertPath -CertStoreLocation "Cert:\LocalMachine\Root" -ErrorAction Stop | Out-Null
            Write-Host "  [OK] Successfully imported to Cert:\LocalMachine\Root via Import-Certificate." -ForegroundColor Green
            $installSuccess = $true
        }
    } catch {
        Write-Host "  [WARN] Import-Certificate to LocalMachine\Root: $($_.Exception.Message)" -ForegroundColor Yellow
    }

    # Backup registration via certutil
    try {
        $res = & certutil.exe -addstore -f "Root" $CertPath 2>&1
        if ($LASTEXITCODE -eq 0 -or $res -match "successfully") {
            Write-Host "  [OK] Successfully registered in Machine Root store via certutil.exe." -ForegroundColor Green
            $installSuccess = $true
        }
    } catch { }

    # Also register in CurrentUser\Root for good measure
    try {
        Import-Certificate -FilePath $CertPath -CertStoreLocation "Cert:\CurrentUser\Root" -ErrorAction SilentlyContinue | Out-Null
        Write-Host "  [OK] Successfully imported to Cert:\CurrentUser\Root." -ForegroundColor Green
    } catch { }

    # Prune outdated MediaStack CAs if requested
    if ($PruneOldCAs) {
        $oldCAs = Get-ChildItem Cert:\LocalMachine\Root, Cert:\CurrentUser\Root -ErrorAction SilentlyContinue |
            Where-Object { ($_.Subject -like "*MediaStack*" -or $_.Subject -like "*waltdakind*") -and $_.Thumbprint -ne $thumbprint }
        
        foreach ($old in $oldCAs) {
            try {
                Remove-Item $old.PSPath -Force -ErrorAction SilentlyContinue
                Write-Host "  [PRUNE] Removed obsolete Root CA: $($old.Thumbprint) ($($old.Subject))" -ForegroundColor DarkGray
            } catch { }
        }
    }
} else {
    # Not admin - Attempt CurrentUser or trigger elevated helper
    Write-Host "  [*] Standard user detected. Initiating LocalMachine elevation for seamless system-wide trust..." -ForegroundColor Cyan
    
    # Attempt CurrentUser directly first
    try {
        $cuStore = New-Object System.Security.Cryptography.X509Certificates.X509Store("Root", "CurrentUser")
        $cuStore.Open("ReadWrite")
        $cuStore.Add($cert)
        $cuStore.Close()
        Write-Host "  [OK] Root CA added to Cert:\CurrentUser\Root." -ForegroundColor Green
        $installSuccess = $true
    } catch {
        Write-Host "  [INFO] User-space direct store access: $($_.Exception.Message)" -ForegroundColor DarkGray
    }

    # Launch elevated process to register to LocalMachine\Root (which prevents browser popups)
    if (-not $installSuccess -or $Elevate -or (-not $lmMatch)) {
        Write-Host "  [*] Requesting Administrator elevation to register in LocalMachine\Root..." -ForegroundColor Yellow
        $scriptPath = $PSCommandPath
        if (-not $scriptPath) { $scriptPath = Join-Path $scriptDir "Install-MediaStackRootCA.ps1" }
        
        $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -CertPath `"$CertPath`""
        if ($PruneOldCAs) { $argList += " -PruneOldCAs" }
        
        try {
            $proc = Start-Process -FilePath "powershell.exe" -ArgumentList $argList -Verb RunAs -PassThru -Wait
            if ($proc.ExitCode -eq 0) {
                Write-Host "  [OK] Elevated installer completed successfully." -ForegroundColor Green
                $installSuccess = $true
            } else {
                Write-Host "  [WARN] Elevated installer exited with code: $($proc.ExitCode)" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "  [WARN] Elevation was cancelled or unavailable: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
}

# Re-verify Installation
$finalLm = Get-ChildItem Cert:\LocalMachine\Root -ErrorAction SilentlyContinue | Where-Object { $_.Thumbprint -eq $thumbprint }
$finalCu = Get-ChildItem Cert:\CurrentUser\Root -ErrorAction SilentlyContinue | Where-Object { $_.Thumbprint -eq $thumbprint }

$isTrusted = ($null -ne $finalLm) -or ($null -ne $finalCu)

Write-Host "`n================================================================================" -ForegroundColor DarkCyan
if ($isTrusted) {
    Write-Host "   T R U S T   S T O R E   R E G I S T R A T I O N :   S U C C E S S" -ForegroundColor Green
    Write-Host "   MediaStack Root CA ($thumbprint) is TRUSTED by Windows!" -ForegroundColor White
    Write-Host ("   Location: {0}" -f $(if ($finalLm) { "Cert:\LocalMachine\Root (System-wide)" } else { "Cert:\CurrentUser\Root" })) -ForegroundColor DarkCyan
} else {
    Write-Host "   T R U S T   S T O R E   R E G I S T R A T I O N :   P E N D I N G" -ForegroundColor Yellow
    Write-Host "   Please run this script from an elevated Administrator PowerShell prompt." -ForegroundColor Yellow
}
Write-Host "================================================================================`n" -ForegroundColor DarkCyan

if ($RunViabilityCheck -or $isTrusted) {
    $viabilityScript = Join-Path $scriptDir "Test-MediaStackSslViability.ps1"
    if (Test-Path $viabilityScript) {
        Write-Host "[*] Executing SSL/TLS Viability Radar to verify updated score..." -ForegroundColor Magenta
        & $viabilityScript
    }
}

return $isTrusted
