@echo off
setlocal
cd /d "%~dp0"
echo ================================================================================
echo    V O L T A I R E U N   S S L   R O O T   C A   R E G I S T R A T I O N
echo ================================================================================
echo.

net session >nul 2>&1
if %errorLevel% == 0 (
    echo [OK] Running with Administrator privileges.
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-VoltaireUnRootCA.ps1" -RunViabilityCheck %*
) else (
    echo [*] Requesting Administrator Elevation for Windows Root CA Installation on VoltaireUn...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process powershell.exe -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File ""%~dp0Install-VoltaireUnRootCA.ps1"" -RunViabilityCheck' -Verb RunAs -Wait"
)

echo.
pause
