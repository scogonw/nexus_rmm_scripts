@echo off
if "%~1"=="" (
    echo Usage: %~nx0 [path_to_image]
    exit /b 1
)

set "PS_URL=https://raw.githubusercontent.com/scogonw/nexus_rmm_scripts/refs/heads/main/windows_scripts/set_wallpaper.ps1"
set "PS_SCRIPT=%TEMP%\set_wallpaper.ps1"

powershell -Command "& { Invoke-WebRequest -Uri '%PS_URL%' -OutFile '%PS_SCRIPT%' }"
powershell -Command "Start-Process PowerShell -ArgumentList '-ExecutionPolicy Bypass -Command ""& ''%PS_SCRIPT%'' -ImageFile ''%~1''"" ' -Verb RunAs"
del "%PS_SCRIPT%" 2>nul