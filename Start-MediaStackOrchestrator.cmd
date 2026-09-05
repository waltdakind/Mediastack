@echo off
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0start-files\Start-MediaStackOrchestrator.ps1" %*
