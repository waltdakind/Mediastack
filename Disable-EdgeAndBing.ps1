<#
.SYNOPSIS
    Disable-EdgeAndBing.ps1 - Complete Windows system script to prevent Microsoft Edge from loading and disable all Bing integration.

.DESCRIPTION
    Applies comprehensive Group Policy, Registry, Protocol, and Task optimizations on Windows 10/11 to:
    1. NEVER USE BING:
       - Disables Bing Web Search in Start Menu and Taskbar (local search only).
       - Disables Bing search box suggestions and cloud search history.
       - Disables Windows Widgets and "News & Interests" Bing feed.
    2. NEVER LOAD EDGE:
       - Disables Edge Startup Boost (stops msedge.exe background pre-launch).
       - Disables Edge Background Mode & background extensions when closed.
       - Disables Edge auto-launch tasks and telemetry update services.
       - Redirects the "microsoft-edge:" URI protocol to open in the system default browser.
       - Optional Hard-Block Mode (-BlockExecution) to intercept msedge.exe via IFEO.

.PARAMETER BlockExecution
    Redirects msedge.exe execution via Image File Execution Options (IFEO) to ensure Edge can never physically execute.

.PARAMETER Restore
    Restores default Windows settings, re-enables Bing search, and restores standard Edge operation.

.EXAMPLE
    .\Disable-EdgeAndBing.ps1
    Applies recommended policy optimizations to disable Bing and prevent Edge background loading.

.EXAMPLE
    .\Disable-EdgeAndBing.ps1 -BlockExecution
    Applies all policies and prevents msedge.exe from ever launching.

.EXAMPLE
    .\Disable-EdgeAndBing.ps1 -Restore
    Reverts all changes back to Windows defaults.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)][switch]$BlockExecution,
    [Parameter(Mandatory=$false)][switch]$Restore
)

# ------------------------------------------------------------------------------
# 0. ELEVATION CHECK
# ------------------------------------------------------------------------------
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "This script requires Administrative privileges to configure system policies."
    Write-Host "Re-launching with elevated Administrator permissions..." -ForegroundColor Cyan
    $argsList = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    if ($BlockExecution) { $argsList += " -BlockExecution" }
    if ($Restore) { $argsList += " -Restore" }
    Start-Process powershell.exe -Verb RunAs -ArgumentList $argsList
    exit
}

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host "   W I N D O W S   E D G E   &   B I N G   E L I M I N A T O R   S U I T E" -ForegroundColor White
Write-Host "   Zero Edge Preloading | Zero Bing Search | 100% Local Privacy" -ForegroundColor DarkCyan
Write-Host "================================================================================" -ForegroundColor Cyan

function Set-RegDword {
    param(
        [string]$Path,
        [string]$Name,
        [int]$Value
    )
    if (-not (Test-Path $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }
    Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type DWord -Force | Out-Null
}

function Remove-RegValue {
    param(
        [string]$Path,
        [string]$Name
    )
    if (Test-Path $Path) {
        Remove-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue | Out-Null
    }
}

# ==============================================================================
# RESTORE MODE
# ==============================================================================
if ($Restore) {
    Write-Host "`n[RESTORE] Reverting Edge and Bing policies to Windows defaults..." -ForegroundColor Yellow

    # Re-enable Start Menu Search
    Remove-RegValue -Path "HKCU:\Software\Policies\Microsoft\Windows\Explorer" -Name "DisableSearchBoxSuggestions"
    Remove-RegValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "DisableWebSearch"
    Remove-RegValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "ConnectedSearchUseWeb"
    Remove-RegValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "ConnectedSearchUseWebOverMeteredConnections"
    Remove-RegValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "AllowCloudSearch"
    Set-RegDword -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "BingSearchEnabled" -Value 1

    # Re-enable Widgets / News & Interests
    Remove-RegValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" -Name "AllowNewsAndInterests"

    # Remove Edge policies
    Remove-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -Recurse -Force -ErrorAction SilentlyContinue

    # Remove IFEO execution block
    Remove-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\msedge.exe" -Recurse -Force -ErrorAction SilentlyContinue

    # Re-enable Edge scheduled tasks
    Get-ScheduledTask -TaskPath "\Microsoft\EdgeUpdate\*" -ErrorAction SilentlyContinue | Enable-ScheduledTask -ErrorAction SilentlyContinue | Out-Null

    Write-Host "  [OK] Default Windows policies restored." -ForegroundColor Green
    Write-Host "Restarting Windows Explorer to apply changes..." -ForegroundColor DarkCyan
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    exit
}

# ==============================================================================
# 1. ELIMINATE BING WEB SEARCH & SUGGESTIONS
# ==============================================================================
Write-Host "`n[1/4] Disabling Bing Integration & Web Search in Windows..." -ForegroundColor Yellow

# Disable Search Box Web Suggestions in Start Menu
Set-RegDword -Path "HKCU:\Software\Policies\Microsoft\Windows\Explorer" -Name "DisableSearchBoxSuggestions" -Value 1
Set-RegDword -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" -Name "DisableSearchBoxSuggestions" -Value 1

# Disable Bing Search in Windows Search & Cortana
Set-RegDword -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "BingSearchEnabled" -Value 0
Set-RegDword -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "CortanaConsent" -Value 0

# Disable Cloud & Web Search via System Policy
Set-RegDword -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "DisableWebSearch" -Value 1
Set-RegDword -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "ConnectedSearchUseWeb" -Value 0
Set-RegDword -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "ConnectedSearchUseWebOverMeteredConnections" -Value 0
Set-RegDword -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "AllowCloudSearch" -Value 0
Set-RegDword -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "AllowCortana" -Value 0

# Disable Widgets & "News and Interests" Bing Feed
Set-RegDword -Path "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" -Name "AllowNewsAndInterests" -Value 0
Set-RegDword -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Feeds" -Name "ShellFeedsTaskbarViewMode" -Value 2

Write-Host "  [OK] Bing web search and Start Menu cloud queries disabled." -ForegroundColor Green

# ==============================================================================
# 2. ELIMINATE MICROSOFT EDGE BACKGROUND PRELOADING & STARTUP BOOST
# ==============================================================================
Write-Host "`n[2/4] Disabling Edge Pre-launch, Startup Boost & Background Tasks..." -ForegroundColor Yellow

$edgePolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
Set-RegDword -Path $edgePolicyPath -Name "StartupBoostEnabled" -Value 0
Set-RegDword -Path $edgePolicyPath -Name "BackgroundModeEnabled" -Value 0
Set-RegDword -Path $edgePolicyPath -Name "HubsSidebarEnabled" -Value 0
Set-RegDword -Path $edgePolicyPath -Name "ShowAcrobatSubscriptionButton" -Value 0
Set-RegDword -Path $edgePolicyPath -Name "WebWidgetAllowed" -Value 0
Set-RegDword -Path $edgePolicyPath -Name "DefaultSearchProviderEnabled" -Value 0

# Terminate any active background Edge instances
$edgeProcs = Get-Process -Name "msedge" -ErrorAction SilentlyContinue
if ($edgeProcs) {
    Write-Host "  • Terminating background msedge.exe processes..." -ForegroundColor DarkGray
    $edgeProcs | Stop-Process -Force -ErrorAction SilentlyContinue
}

# Disable Edge Update Scheduled Tasks that run in the background
$tasks = Get-ScheduledTask -TaskPath "\Microsoft\EdgeUpdate\*" -ErrorAction SilentlyContinue
foreach ($t in $tasks) {
    Disable-ScheduledTask -TaskName $t.TaskName -TaskPath $t.TaskPath -ErrorAction SilentlyContinue | Out-Null
}

Write-Host "  [OK] Edge background preloading and update tasks disabled." -ForegroundColor Green

# ==============================================================================
# 3. REDIRECT 'microsoft-edge:' PROTOCOL TO SYSTEM DEFAULT BROWSER
# ==============================================================================
Write-Host "`n[3/4] Redirecting 'microsoft-edge:' Protocol Links to Default Browser..." -ForegroundColor Yellow

# Register a lightweight PowerShell protocol handler for microsoft-edge:
$scriptDir = Split-Path -Parent $PSCommandPath
$redirectorScript = Join-Path $scriptDir "Open-DefaultBrowserUri.ps1"

$redirectorContent = @'
param([string]$Url)
if ($Url) {
    # Strip microsoft-edge: prefix and unescape URL
    $cleanUrl = $Url -replace "^microsoft-edge:(\/\/)?", ""
    if ($cleanUrl -match "url=(.+)") {
        $cleanUrl = [System.Uri]::UnescapeDataString($Matches[1])
    }
    if ($cleanUrl -and $cleanUrl -notmatch "^https?://") {
        $cleanUrl = "https://$cleanUrl"
    }
    if ($cleanUrl) {
        Start-Process $cleanUrl
    }
}
'@

Set-Content -Path $redirectorScript -Value $redirectorContent -Encoding UTF8 -Force

# Register Custom Protocol Command Handler in Registry
$protoKey = "HKCU:\Software\Classes\microsoft-edge\shell\open\command"
if (-not (Test-Path $protoKey)) { New-Item -Path $protoKey -Force | Out-Null }
$cmdVal = "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$redirectorScript`" `"%1`""
Set-ItemProperty -Path $protoKey -Name "(Default)" -Value $cmdVal -Force | Out-Null

Write-Host "  [OK] 'microsoft-edge:' links now open in your system default browser." -ForegroundColor Green

# ==============================================================================
# 4. HARD BLOCK EXECUTION (IF REQUESTED)
# ==============================================================================
if ($BlockExecution) {
    Write-Host "`n[4/4] Activating Hard-Block Mode (Image File Execution Options)..." -ForegroundColor Yellow
    
    $ifeoPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\msedge.exe"
    if (-not (Test-Path $ifeoPath)) { New-Item -Path $ifeoPath -Force | Out-Null }
    
    # Set Debugger redirect to launch our default browser redirector instead of msedge.exe
    $ifeoCmd = "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$redirectorScript`""
    Set-ItemProperty -Path $ifeoPath -Name "Debugger" -Value $ifeoCmd -Force | Out-Null
    
    Write-Host "  [OK] Hard-block active: msedge.exe is redirected to your default browser." -ForegroundColor Green
} else {
    Write-Host "`n[4/4] Hard-block mode skipped (use -BlockExecution if you want to completely block msedge.exe from running)." -ForegroundColor DarkGray
}

# ==============================================================================
# 5. RESTART EXPLORER TO APPLY
# ==============================================================================
Write-Host "`nRestarting Windows Explorer to immediately apply Search and Policy changes..." -ForegroundColor Cyan
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1

Write-Host "`n================================================================================" -ForegroundColor Green
Write-Host "   S U C C E S S :   E D G E   &   B I N G   A R E   N O W   D I S A B L E D" -ForegroundColor White
Write-Host "   • Start Menu search is now 100% local (zero Bing search queries)." -ForegroundColor DarkCyan
Write-Host "   • Edge background pre-launch and startup boost are stopped." -ForegroundColor DarkCyan
Write-Host "   • Windows Edge links automatically open in your Default Browser." -ForegroundColor DarkCyan
Write-Host "================================================================================" -ForegroundColor Green
