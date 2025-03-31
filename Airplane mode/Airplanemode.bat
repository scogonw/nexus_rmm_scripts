@echo off
title Airplanemode

# Ensure script runs with administrative privileges
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Restarting script with Administrator privileges..." -ForegroundColor Yellow
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}



:: Run the PowerShell script
echo Running security scan script...
powershell -ExecutionPolicy Bypass -File "%~dp0Airplanemode.ps1"

:: Pause to see the results
pause Additional_Security_Investigation