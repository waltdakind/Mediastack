@echo off
setlocal
title MediaStack - VoltaireUn Autonomous Telemetry ^& Report Generator
cd /d "%~dp0"

echo ================================================================================
echo    M E D I A S T A C K   -   V O L T A I R E U N   T E L E M E T R Y   R E P O R T
echo    Executing Autonomous Collaborator Engine on VoltaireUn (192.168.4.21)
echo ================================================================================
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start-AutonomousMediaStackCollaborator.ps1" -SinglePass

echo.
echo ================================================================================
echo    Report generation completed. Check handoffs\ directory for markdown reports.
echo ================================================================================
pause
