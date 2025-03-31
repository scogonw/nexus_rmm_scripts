@echo off
title Debolat Windows 

:: Check for admin privileges
NET SESSION >nul 2>&1
if %errorLevel% == 0 (
    echo Running with administrator privileges...
) else (
    echo Requesting administrator privileges...
    powershell -Command "Start-Process '%~dpnx0' -Verb RunAs"
    exit /b
)


:: Run the PowerShell script
echo Running Debolat Windows...
powershell -ExecutionPolicy Bypass -File "%~dp0win-debloater.ps1"

