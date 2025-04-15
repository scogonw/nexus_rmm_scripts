@echo off
title Airplane Mode Toggle

:: Check for admin privileges
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Administrator privileges required. Elevating...
    powershell -Command "Start-Process '%~dpnx0' -Verb RunAs"
    exit /b
)

:: Run the PowerShell script
echo Running Airplane Mode Toggle script...
powershell -ExecutionPolicy Bypass -File "%~dp0Airplanemode.ps1"

:: Pause to see the results
pause