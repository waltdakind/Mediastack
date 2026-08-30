@echo off
setlocal

:: MediaStack Homepage Auto-Installer
title MediaStack Homepage Installer

echo ===================================================
echo     MediaStack Homepage Automated Installer
echo ===================================================
echo.

:: Check for Docker
docker --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Docker is not installed or not in PATH!
    echo Please install Docker Desktop or Docker Engine first.
    pause
    exit /b 1
)

echo [INFO] Docker detected. Initializing deployment...
echo.

:: Navigate to the directory containing this script
cd /d "%~dp0"

echo [INFO] Pulling the latest Homepage image (Architecture auto-matched)...
docker compose pull
if %errorlevel% neq 0 (
    echo [ERROR] Failed to pull the image. Check your internet connection.
    pause
    exit /b 1
)

echo.
echo [INFO] Starting the Homepage container...
docker compose up -d
if %errorlevel% neq 0 (
    echo [ERROR] Failed to start the container.
    pause
    exit /b 1
)

echo.
echo ===================================================
echo   SUCCESS! The dashboard is now running.
echo   You can access it at: http://localhost:3000
echo ===================================================
echo.
pause
