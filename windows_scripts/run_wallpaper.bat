@echo off
SETLOCAL EnableDelayedExpansion

if "%~1"=="" (
    echo ERROR: No image file specified.
    echo Usage: %~nx0 [path_to_image] [style]
    echo Example: %~nx0 C:\wallpaper.jpg Stretch
    echo Available styles: Fill, Fit, Stretch, Tile, Center, Span (default)
    exit /b 1
)

set "PS_URL=https://raw.githubusercontent.com/scogonw/nexus_rmm_scripts/refs/heads/main/windows_scripts/set_wallpaper.ps1"
set "PS_SCRIPT=%TEMP%\set_wallpaper.ps1"

powershell -Command "& { Invoke-WebRequest -Uri '%PS_URL%' -OutFile '%PS_SCRIPT%' }"

if not exist "%PS_SCRIPT%" (
    echo ERROR: Failed to download the PowerShell script.
    exit /b 1
)

if "%~2"=="" (
    powershell -Command "Start-Process PowerShell -ArgumentList '-ExecutionPolicy Bypass -Command ""& ''%PS_SCRIPT%'' -ImageFile ''%~1''"" ' -Verb RunAs"
) else (
    powershell -Command "Start-Process PowerShell -ArgumentList '-ExecutionPolicy Bypass -Command ""& ''%PS_SCRIPT%'' -ImageFile ''%~1'' -Style ''%~2''"" ' -Verb RunAs"
)

timeout /t 2 > nul
del "%PS_SCRIPT%" 2>nul
exit /b 0