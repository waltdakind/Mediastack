@echo off
:: ==============================================================================
:: MediaStack - Windows Hosts File Local Virtual Host Registrar (UAC Elevated)
:: ==============================================================================
title MediaStack Local DNS Registrar

:: Auto-Elevation Check
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [MEDIASTACK] Requesting Administrator Privileges to update C:\Windows\System32\drivers\etc\hosts...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process cmd.exe -ArgumentList '/c \"\"%~f0\"\"' -Verb RunAs"
    exit /b
)

echo ================================================================================
echo    M E D I A S T A C K   L O C A L   D N S   R E G I S T R A R
echo ================================================================================
echo.

set "HOSTS_FILE=%SystemRoot%\System32\drivers\etc\hosts"
set "BACKUP_FILE=%SystemRoot%\System32\drivers\etc\hosts.bak_%date:~10,4%%date:~4,2%%date:~7,2%_%time:~0,2%%time:~3,2%%time:~6,2%"
set "BACKUP_FILE=%BACKUP_FILE: =0%"

echo [*] Backing up current hosts file to: %BACKUP_FILE%
copy /Y "%HOSTS_FILE%" "%BACKUP_FILE%" >nul

echo [*] Appending VoltaireDeux and VoltaireUn local SSL virtual hosts...

(
echo.
echo # ==============================================================================
echo # MEDIASTACK MULTI-NODE CLUSTER ^& SSL VIRTUAL HOSTS
echo # ==============================================================================
echo 127.0.0.1       localhost
echo 192.168.4.30    voltairedeux.local
echo 192.168.4.30    jellyfin.voltairedeux.local
echo 192.168.4.30    dashboard.voltairedeux.local
echo 192.168.4.30    sonarr.voltairedeux.local
echo 192.168.4.30    radarr.voltairedeux.local
echo 192.168.4.30    prowlarr.voltairedeux.local
echo 192.168.4.30    bazarr.voltairedeux.local
echo 192.168.4.30    jellyseerr.voltairedeux.local
echo 192.168.4.30    transmission.voltairedeux.local
echo 192.168.4.30    tvheadend.voltairedeux.local
echo 192.168.4.30    hdhomerun.voltairedeux.local
echo 192.168.4.30    musicbrainz.voltairedeux.local
echo 192.168.4.30    db.voltairedeux.local
echo 192.168.4.30    home.voltairedeux.local
echo 192.168.4.30    homepage.voltairedeux.local
echo.
echo 192.168.4.21    voltaireun.local
echo 192.168.4.21    jellyfin.voltaireun.local
echo 192.168.4.21    dashboard.voltaireun.local
echo 192.168.4.21    sonarr.voltaireun.local
echo 192.168.4.21    radarr.voltaireun.local
echo 192.168.4.21    prowlarr.voltaireun.local
echo 192.168.4.21    bazarr.voltaireun.local
echo 192.168.4.21    jellyseerr.voltaireun.local
echo 192.168.4.21    transmission.voltaireun.local
echo 192.168.4.21    tvheadend.voltaireun.local
echo 192.168.4.21    hdhomerun.voltaireun.local
echo 192.168.4.21    musicbrainz.voltaireun.local
echo 192.168.4.21    db.voltaireun.local
echo.
) >> "%HOSTS_FILE%"

echo [*] Flushing DNS cache...
ipconfig /flushdns >nul

echo.
echo [SUCCESS] Windows hosts file updated successfully!
echo All .local subdomains (https://sonarr.voltairedeux.local, etc.) are now resolving locally.
echo.
timeout /t 5
