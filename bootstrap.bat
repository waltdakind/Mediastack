@echo off
title MediaStack Cluster Node Bootstrapper
echo ================================================================================
echo    M E D I A S T A C K   C L U S T E R   N O D E   B O O T S T R A P
echo ================================================================================
echo.
echo Launching elevated PowerShell installer...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& { Start-Process powershell.exe -Verb RunAs -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"%~dp0Bootstrap-NewNode.ps1\"' }"
