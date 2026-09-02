@echo off
setlocal
cd /d "%~dp0"
echo ================================================================================
echo    M E D I A S T A C K   R O O T   C A   R E G I S T R A T I O N   L A U N C H E R
echo ================================================================================
echo.

net session >nul 2>&1
if %errorLevel% == 0 (
    echo [OK] Running with Administrator privileges.
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-MediaStackRootCA.ps1" -RunViabilityCheck %*
) else (
    echo [*] Requesting Administrator Elevation for Windows Root CA Installation...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process powershell.exe -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File ""%~dp0Install-MediaStackRootCA.ps1"" -RunViabilityCheck' -Verb RunAs -Wait"
)

echo.
pause
