@echo off
title Windows Security Check Runner

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
echo Running security check script...
powershell -ExecutionPolicy Bypass -File "%~dp0systemHealthcheck.ps1"

:: Pause to see the results
pause Additional_Security_Investigation