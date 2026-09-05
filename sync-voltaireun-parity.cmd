@echo off
setlocal
cd /d "%~dp0"
echo ================================================================================
echo    V O L T A I R E U N   F E A T U R E   P A R I T Y   P R O V I S I O N E R
echo ================================================================================
echo.

net session >nul 2>&1
if %errorLevel% == 0 (
    echo [OK] Running with Administrator privileges.
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0sync-files\Sync-VoltaireUnFeatureParity.ps1" %*
) else (
    echo [*] Requesting Administrator Elevation for VoltaireUn Parity Engine...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process powershell.exe -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File ""%~dp0sync-files\Sync-VoltaireUnFeatureParity.ps1""' -Verb RunAs -Wait"
)

echo.
pause
