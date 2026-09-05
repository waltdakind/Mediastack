@echo off
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0sync-files\Sync-MediaStackPriorityHandoffs.ps1" %*
