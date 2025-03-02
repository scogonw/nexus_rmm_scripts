@echo off
SETLOCAL

echo =========================================
echo Windows Wallpaper Setter Utility
echo =========================================
echo.

REM Check if running as administrator
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo This script requires administrator privileges.
    echo Right-click on this file and select "Run as Administrator".
    echo.
    exit /b 1
)

REM Create a temporary directory
set "TEMP_DIR=%TEMP%\WallpaperSetter_%RANDOM%"
mkdir "%TEMP_DIR%" 2>nul

REM Set script paths and URL
set "PS_SCRIPT=%TEMP_DIR%\set_wallpaper.ps1"
set "PS_URL=https://raw.githubusercontent.com/scogonw/nexus_rmm_scripts/refs/heads/main/windows_scripts/set_wallpaper.ps1"

echo Downloading wallpaper setter script...
powershell -Command "(New-Object Net.WebClient).DownloadFile('%PS_URL%', '%PS_SCRIPT%')"

if not exist "%PS_SCRIPT%" (
    echo ERROR: Failed to download the PowerShell script.
    echo Please check your internet connection and try again.
    echo.
    rd /s /q "%TEMP_DIR%" 2>nul
    exit /b 1
)

echo PowerShell script successfully downloaded.
echo.

REM Check if an image file was provided
if "%~1"=="" (
    echo ERROR: No image file specified.
    echo Usage: %~nx0 [path_to_image] [style]
    echo Example: %~nx0 C:\wallpaper.jpg Stretch
    echo Available styles: Fill, Fit, Stretch, Tile, Center, Span (default)
    echo.
    rd /s /q "%TEMP_DIR%" 2>nul
    exit /b 1
)

REM Check if the specified image file exists
if not exist "%~1" (
    echo ERROR: The specified image file does not exist: %~1
    echo Please provide a valid path to an image file.
    echo.
    rd /s /q "%TEMP_DIR%" 2>nul
    exit /b 1
)

REM Determine if a style was specified
set "STYLE_PARAM="
if not "%~2"=="" (
    set "STYLE_PARAM=-Style %~2"
)

echo Setting wallpaper to: %~1
if not "%~2"=="" (
    echo Using style: %~2
) else (
    echo Using default style (Span)
)
echo.

REM Execute the PowerShell script with elevated privileges and execution policy bypass
powershell -NoProfile -ExecutionPolicy Bypass -Command "& {Start-Process PowerShell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"%PS_SCRIPT%\" -ImageFile \"%~1\" %STYLE_PARAM%' -Verb RunAs -Wait}"

if %errorLevel% neq 0 (
    echo The wallpaper setter script encountered an error (Exit code: %errorLevel%)
) else (
    echo Wallpaper set successfully.
)

echo Cleaning up temporary files...
rd /s /q "%TEMP_DIR%" 2>nul

ENDLOCAL
exit /b %errorLevel% 