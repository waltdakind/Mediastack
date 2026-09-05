@echo off
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0sync-files\s-sync.ps1" %*
