param([switch]$DryRun)

$hostsScript = Join-Path $PSScriptRoot "update-hosts.ps1"

Clear-Host
Write-Host ""
Write-Host " =========================================================" -ForegroundColor Cyan
Write-Host "               MEDIASTACK MINI-PC DEPLOYER"
Write-Host " =========================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host " Welcome to the MediaStack migration wizard!"
Write-Host ""
Write-Host " [STEP 1] Preparing your Windows Environment" -ForegroundColor Yellow
Write-Host "---------------------------------------------------------"
Write-Host " We need to route all 'ordinateur.local' traffic from this"
Write-Host " Windows PC to the new Mini-PC (192.168.4.21)."
Write-Host ""

$response = Read-Host " Ready to update Windows Hosts file? (Y/N)"
if ($response -match "^y") {
    if (Test-Path $hostsScript) {
        Write-Host " Launching Administrator prompt..." -ForegroundColor Green
        Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$hostsScript`"" -Verb RunAs -Wait
        Write-Host " Windows routing configured!" -ForegroundColor Green
    } else {
        Write-Host " Could not find update-hosts.ps1 in $PSScriptRoot!" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host " [STEP 2] Deploy to Mini-PC" -ForegroundColor Yellow
Write-Host "---------------------------------------------------------"
Write-Host " Because the Mini-PC is also running Windows, the final installation"
Write-Host " will be executed seamlessly via PowerShell."
Write-Host " Since you synced this folder via OneDrive, everything is already"
Write-Host " waiting for you on the Mini-PC!"
Write-Host ""
Write-Host " HOW TO FINISH THE INSTALL:"
Write-Host " 1. Open PowerShell on your Mini-PC."
Write-Host " 2. Navigate to your synced install-tools folder:"
Write-Host "    cd ~/OneDrive/Mediastack/install-tools (or wherever it synced)"
Write-Host " 3. Execute the PowerShell installer with the backup zip:"
Write-Host "    .\02-Deploy-MiniPC.ps1 $BackupFile"
Write-Host ""
Write-Host " The PowerShell script will deploy to C:\Users\Public\MediaStack and start Docker!"
Write-Host ""
Write-Host " =========================================================" -ForegroundColor Cyan
Read-Host "Press Enter to exit..."
