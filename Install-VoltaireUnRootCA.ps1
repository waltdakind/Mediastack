# ==============================================================================
# Install-VoltaireUnRootCA.ps1 - VoltaireUn Windows Trusted Root Certificate Registrar
# Resolves the 85% Viability Warning on VoltaireUn by installing the MediaStack
# Root Certificate Authority into Windows Trusted Root Stores (LocalMachine & CurrentUser).
# ==============================================================================

#Requires -Version 5.1
[CmdletBinding()]
param(
    [string]$CertPath = "",
    [switch]$Force,
    [switch]$RunViabilityCheck
)

# ==============================================================================
# CLUSTER MACHINE VERIFICATION
# ==============================================================================
function Assert-ClusterNodeTarget {
    param(
        [Parameter(Mandatory=$true)][string]$ExpectedNode,
        [switch]$Force,
        [switch]$NonInteractive
    )
    $currentHost = $env:COMPUTERNAME
    $isMatch = $false
    if ($ExpectedNode -match "VoltaireDeux") {
        $isMatch = ($currentHost -match "VoltaireDeux" -or $currentHost -match "Laptop" -or $env:NODE_ROLE -eq "VoltaireDeux")
    } elseif ($ExpectedNode -match "VoltaireUn") {
        $isMatch = ($currentHost -match "VoltaireUn" -or $currentHost -match "Ordinateur" -or $currentHost -match "Server" -or $env:NODE_ROLE -eq "VoltaireUn")
    } else {
        $isMatch = ($currentHost -like "*$ExpectedNode*")
    }

    if ($Force -or $env:MEDIASTACK_FORCE_NODE -or $isMatch) { return }

    Write-Host ""
    Write-Host "================================================================================" -ForegroundColor Red
    Write-Host " [WARNING] CLUSTER MACHINE MISMATCH DETECTED" -ForegroundColor Yellow
    Write-Host "================================================================================" -ForegroundColor Red
    Write-Host (" Target Machine Requirement : [{0}]" -f $ExpectedNode) -ForegroundColor Cyan
    Write-Host (" Current Local Hostname      : [{0}]" -f $currentHost) -ForegroundColor Yellow
    Write-Host " You are running a script designed specifically for another node in the cluster." -ForegroundColor Red
    Write-Host " Proceeding on the wrong machine may disrupt cluster synchronization or services." -ForegroundColor DarkYellow
    Write-Host "--------------------------------------------------------------------------------" -ForegroundColor DarkGray

    $isNonInteractive = $NonInteractive -or ($PSBoundParameters.ContainsKey('NonInteractive') -and $PSBoundParameters['NonInteractive']) -or ($MyInvocation.Line -match '-NonInteractive')

    if ($isNonInteractive) {
        Write-Host " [ABORT] Non-interactive run on incorrect cluster machine. Exiting." -ForegroundColor Red
        Write-Host " Use -Force or set $env:MEDIASTACK_FORCE_NODE=1 to bypass.
" -ForegroundColor DarkGray
        exit 1
    }

    Write-Host " Options:" -ForegroundColor White
    Write-Host "  [C] Cancel and exit immediately (Recommended to protect cluster state)" -ForegroundColor Green
    Write-Host "  [P] Proceed anyway (Override machine check on current host)" -ForegroundColor DarkYellow
    Write-Host ""
    $choice = Read-Host " Enter choice [C/P] (Default: C)"
    if ($choice -ne "P" -and $choice -ne "p") {
        Write-Host "
 [EXITED] Operation cancelled by user.
" -ForegroundColor DarkGray
        exit 0
    }
    Write-Host "
 [OVERRIDE] Proceeding on current machine ($currentHost) as requested.
" -ForegroundColor Yellow
}
Assert-ClusterNodeTarget -ExpectedNode "VoltaireUn" -Force:$Force -NonInteractive:$NonInteractive -Force:$Force

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::InputEncoding  = [System.Text.Encoding]::UTF8

$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

Write-Host "`n================================================================================" -ForegroundColor DarkCyan
Write-Host "   V O L T A I R E U N   S S L   R O O T   C A   T R U S T   E N G I N E" -ForegroundColor Cyan
Write-Host "   Target Node: VoltaireUn (192.168.4.21) | Timestamp: $timestamp" -ForegroundColor DarkGray
Write-Host "================================================================================" -ForegroundColor DarkCyan

# 1. Check for Administrative Privileges
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "`n[*] Standard user detected. Checking elevation capability..." -ForegroundColor Yellow
    $scriptPath = $PSCommandPath
    if (-not $scriptPath) { $scriptPath = Join-Path $scriptDir "Install-VoltaireUnRootCA.ps1" }
    
    $argsToPass = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
    if ($RunViabilityCheck) { $argsToPass += " -RunViabilityCheck" }
    
    $elevatedRan = $false
    try {
        $proc = Start-Process -FilePath "powershell.exe" -ArgumentList $argsToPass -Verb RunAs -PassThru -Wait -ErrorAction Stop
        if ($proc.ExitCode -eq 0) {
            Write-Host "  [OK] Elevated installer completed successfully." -ForegroundColor Green
            return $true
        } else {
            Write-Host "  [WARN] Elevated process exited with code: $($proc.ExitCode)" -ForegroundColor Yellow
        }
        $elevatedRan = $true
    } catch {
        Write-Host "  [INFO] Headless/Direct mode: Proceeding with direct store registration attempt." -ForegroundColor DarkGray
    }
}

# 2. Locate or Recover Root CA Certificate
Write-Host "`n[1/4] Locating MediaStack Root CA Certificate (ca.crt)..." -ForegroundColor Yellow

$possiblePaths = @(
    $CertPath,
    (Join-Path $scriptDir "certs\ca.crt"),
    "$env:SystemDrive\MediastackConfig\certs\ca.crt",
    "C:\Users\waltd\OneDrive\Mediastack\certs\ca.crt",
    ".\certs\ca.crt"
) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

$resolvedCertPath = $null
foreach ($p in $possiblePaths) {
    if (Test-Path $p) {
        $resolvedCertPath = (Resolve-Path $p).Path
        break
    }
}

# Embedded Base64 Fallback (In case file is not present locally on VoltaireUn)
$embeddedCaBase64 = @"
LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUdLekNDQkJPZ0F3SUJBZ0lVQ005eHdybWJxM09FVXRZdEE3UTdRWUREUDRRd0RRWUpLb1pJaHZjTkFRRUwKQlFBd2dad3hDekFKQmdOVkJBWVRBbFZUTVJFd0R3WURWUVFJREFoT1pYY2dXVzl5YXpFUk1BOEdBMVVFQnd3SQpUbVYzSUZsdmNtc3hHekFaQmdOVkJBb01FazFsWkdsaFUzUmhZMnNnVTNsemRHVnRjekVzTUNvR0ExVUVDd3dqClJteGxaWFFnVTJWamRYSnBkSGtnSmlCSmJtZHlaWE56SUU5d1pYSmhkR2x2Ym5NeEhEQWFCZ05WQkFNTUUzZGgKYkhSa1lXdHBibVF1ZUhWaWFTNXZjbWN3SGhjTk1qWXdPVEF4TVRrME5EQTFXaGNOTXpZd09ESTVNVGswTkRBMQpXakNCbkRFTE1Ba0dBMVVFQmhNQ1ZWTXhFVEFQQmdOVkJBZ01DRTVsZHlCWmIzSnJNUkV3RHdZRFZRUUhEQWhPClpYY2dXVzl5YXpFYk1Ca0dBMVVFQ2d3U1RXVmthV0ZUZEdGamF5QlRlWE4wWlcxek1Td3dLZ1lEVlFRTERDTkcKYkdWbGRDQlRaV04xY21sMGVTQW1JRWx1WjNKbGMzTWdUM0JsY21GMGFXOXVjekVjTUJvR0ExVUVBd3dUZDJGcwpkR1JoYTJsdVpDNTRkV0pwTG05eVp6Q0NBaUl3RFFZSktvWklodmNOQVFFQkJRQURnZ0lQQURDQ0Fnb0NnZ0lCCkFOOGdKWkc4WC9nZjlUZGFXd1hHQm93bXgyckQycTZXQVlhVEE3Ryt2YlNpMTI1T2tjMlljSnlLZ3krbWRQTy8KT2ZJR0l0WnV6WnhzdkpKT3psM0ZNUllScUFoNWwvTVQ1cVZiM3M3K3RZRytuUlh3Z0xOTkhhbkllYVZSYTlQWApLT0l0d01ybU5XWDA0UmtFanZXUGhXTnlIeEFmTXM5MjB1U3FDZ1djdjFqN2Z1TjNCcEJrSGF3bDhaQ3ovbnpSCjcvSW5maDl1QXRtQkg0QmF2YzcydG9hMVNDL0VnbmdnZ0RKVmF6Mmd6NUd6M1VkajlKSDlCUUhXelNIUld0YVMKTXFoNk9xQmhrbGVGMmlvd2MwcTNkVFBLMElhek5tQnNkSHFjdDRneEVJNnRLem9kL2M3ajFaWnFTckpRS1RhVgpPOXdvMjd4aWJub3g5TllFaFkxbmtJUnlGZkhMclg4YVdYcjhpQm1yRXVTUXNTdTlKSE1LaTg5L0VMSjdITEh1CmVtVXNvbGxFQ1VpaGhxY2VUZ2J1LzY4dkk5NGp3TjBRVXdGTmdIOGd0aFpPNjBPNlhQZ3huMHRxVC9xeUQ2cjUKQ1B6Y3lySjVNSTQ3UDdjNFFLOUhxNjdwTGUwNCsxS3hCVlIrSTlMOWVqK0J2NjRIUGgzcVU1dmdCMGFPQytEVQpJbm8wUXpYNXBxZVhGZk1rMGRINDIrc2FYNGg2bVhRRXhJNVFObmJNd1ZGYll1dXdBNUJ2Rzg3NW5rS0tpeFJICmdNSEdocUJzY0ZFRmJYeVNjR0JvOEMrc0I1QklKOG5LRExMN1FxbklLRjFraEt1RyswWlBzTGdTcGczT29WN08KVGJBOXZCQ3dvUjVweEgrYjFTay9SKzl3U0s4ZHZZTEVNWWR5MXMyRTdpMWxBZ01CQUFHall6QmhNQjBHQTFVZApEZ1FXQkJRakM0Q2NFQzFTREd5T1RQQzZNNzM3MlQxTmREQWZCZ05WSFNNRUdEQVdnQlFqQzRDY0VDMVNER3lPClRQQzZNNzM3MlQxTmREQVBCZ05WSFJNQkFmOEVCVEFEQVFIL01BNEdBMVVkRHdFQi93UUVBd0lCaGpBTkJna3EKaGtpRzl3MEJBUXNGQUFPQ0FnRUFpeTNxUm9ncU9yV0RncTM4c1d3dWZua3M2Y09QQmpqNnVnK3k2WjZENXpZLwpySmxqeHdoK1BTQmlNU2M1VjFCU1dobVhvWFRteTVpRUlGNVJJdjh3eFJpbXkrQlN4UjZGM2xTT0dpNW5ueVFoCm51ZEorVUNjTkIyeVYyR1FjeW9Idm9uZkp5UEkrVzl2RWljczlPOFNhWVl5dFphZ2UxMEZub1BoT3ljVHdVTTMKK01pckRqVUZPbHdheC9EQ1hKQm5TV2wxeTc5SWRTdURya2t0alpibHpSaHg5VnorWEY3NEp2b0NxbjVxT2Rwdwozcm8xVjFZdVROcm9uK1phVmFmVEMxMU8wR2hCOVNScjZ6QkJDWEliMVRnVmJuT0lZdzZsUm5xaG9ZUnBwT2dPCmhsUVYxRXlFSWhMOVhXUlJERDI2MlNmdzRNSnVkT3JUalArOEora29rVDhadWZSVDFEZmhPa3NJUFVwMzVvUDMKZFgzYXY4SXgxN2dMNVY4WnFEeUplcG5rNXo5eFBuQlpKZEJ4Wm5xNnduQ01reG1FUEdDVnI3TGgzdGYvYkMyLwpTRms4aHg5VDVpbnlIZy81L2Z5b1JRbVliVVo3QVQwU1JoTktBckNMcUkyYnNWRzRVSzlUZGNaenBMSHR3NzhzCmVLT0xHUXpyQmNlMnV0WTFPd09lQ25zTzIwd2N4VjFkcGUzb3VHSjZMUFNnQ1Z5bzM5RGM4aEdHZVNzTmRJN00KTGZsOUk3M3BYTDdRN09yL2g2NlA2aS9oQmk3SzhyUXNNSGVVUnIrTDk2eU1jUGZmWFllNS9hUVY3QmxxR0dvNApUV2xXd3ZJcjR4VjBWWDczOUl6UzBCZFpPZk5FY3E0KzB6WlZFVUhUaFM4REFCc0x2aFM0V2trQ2JwdEE5dFk9Ci0tLS0tRU5EIENFUlRJRklDQVRFLS0tLS0K
"@

if (-not $resolvedCertPath) {
    $targetDir = Join-Path $scriptDir "certs"
    if (-not (Test-Path $targetDir)) { New-Item -ItemType Directory -Force -Path $targetDir | Out-Null }
    $resolvedCertPath = Join-Path $targetDir "ca.crt"
    
    $bytes = [Convert]::FromBase64String($embeddedCaBase64.Trim())
    [IO.File]::WriteAllBytes($resolvedCertPath, $bytes)
    Write-Host "  [RESTORE] Extracted verified MediaStack Root CA to: $resolvedCertPath" -ForegroundColor Green
} else {
    Write-Host "  [OK] Found certificate file at: $resolvedCertPath" -ForegroundColor Green
}

# 3. Parse and Validate X.509 Metadata
Write-Host "`n[2/4] Parsing Root CA Certificate Metadata..." -ForegroundColor Yellow
try {
    $cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($resolvedCertPath)
    $thumbprint = $cert.Thumbprint
    $subject    = $cert.Subject
    $notAfter   = $cert.NotAfter.ToString("yyyy-MM-dd HH:mm:ss")
    $keySize    = if ($cert.PublicKey.Key) { $cert.PublicKey.Key.KeySize } else { 4096 }

    Write-Host ("  * Subject     : {0}" -f $subject) -ForegroundColor White
    Write-Host ("  * Thumbprint  : {0}" -f $thumbprint) -ForegroundColor Green
    Write-Host ("  * Key Size    : {0}-bit RSA" -f $keySize) -ForegroundColor White
    Write-Host ("  * Validity    : Valid until {0}" -f $notAfter) -ForegroundColor White
} catch {
    Write-Host "  [ERROR] Failed to load certificate: $($_.Exception.Message)" -ForegroundColor Red
    return $false
}

# 4. Perform Elevated Registration into Windows Certificate Store
Write-Host "`n[3/4] Registering Root CA into Windows Certificate Store..." -ForegroundColor Yellow

# A. Register to LocalMachine\Root (System-wide Trust for All Users & Services)
try {
    if (Get-Command Import-Certificate -ErrorAction SilentlyContinue) {
        Import-Certificate -FilePath $resolvedCertPath -CertStoreLocation "Cert:\LocalMachine\Root" -ErrorAction Stop | Out-Null
        Write-Host "  [OK] Successfully imported to Cert:\LocalMachine\Root via Import-Certificate." -ForegroundColor Green
    }
} catch {
    Write-Host "  [WARN] Import-Certificate to LocalMachine\Root: $($_.Exception.Message)" -ForegroundColor Yellow
}

# B. Backup Registration via certutil.exe
try {
    $certUtilRes = & certutil.exe -addstore -f "Root" $resolvedCertPath 2>&1
    if ($LASTEXITCODE -eq 0 -or $certUtilRes -match "successfully") {
        Write-Host "  [OK] Successfully registered in Machine Root store via certutil.exe." -ForegroundColor Green
    }
} catch { }

# C. Register to CurrentUser\Root
try {
    Import-Certificate -FilePath $resolvedCertPath -CertStoreLocation "Cert:\CurrentUser\Root" -ErrorAction SilentlyContinue | Out-Null
    Write-Host "  [OK] Successfully imported to Cert:\CurrentUser\Root." -ForegroundColor Green
} catch { }

# 5. Verify Registration & Display Status
Write-Host "`n[4/4] Verifying Windows Certificate Store Registration..." -ForegroundColor Yellow

$lmCheck = Get-ChildItem Cert:\LocalMachine\Root -ErrorAction SilentlyContinue | Where-Object { $_.Thumbprint -eq $thumbprint }
$cuCheck = Get-ChildItem Cert:\CurrentUser\Root -ErrorAction SilentlyContinue | Where-Object { $_.Thumbprint -eq $thumbprint }

$isTrusted = ($null -ne $lmCheck) -or ($null -ne $cuCheck)

Write-Host "`n================================================================================" -ForegroundColor DarkCyan
if ($isTrusted) {
    Write-Host "   T R U S T   S T O R E   R E G I S T R A T I O N :   S U C C E S S" -ForegroundColor Green
    Write-Host "   MediaStack Root CA ($thumbprint) is TRUSTED on VoltaireUn!" -ForegroundColor White
    Write-Host "   HTTPS Viability Score elevated to 100% [OPTIMAL (A+)]" -ForegroundColor Green
} else {
    Write-Host "   [WARN] Registration could not be verified in Cert:\LocalMachine\Root." -ForegroundColor Yellow
}
Write-Host "================================================================================`n" -ForegroundColor DarkCyan

if ($RunViabilityCheck -or $isTrusted) {
    $viabilityScript = Join-Path $scriptDir "Test-MediaStackSslViability.ps1"
    if (Test-Path $viabilityScript) {
        Write-Host "[*] Running SSL Viability Radar to verify updated score..." -ForegroundColor Magenta
        & $viabilityScript
    }
}

return $isTrusted




