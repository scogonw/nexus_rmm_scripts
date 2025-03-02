@echo off
SETLOCAL EnableDelayedExpansion

echo =========================================
echo Windows Wallpaper Setter Utility
echo =========================================
echo.

echo [DEBUG] Script started at: %date% %time%
echo [DEBUG] Running as user: %USERNAME%
echo [DEBUG] Computer name: %COMPUTERNAME%

REM Check if running as administrator
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [DEBUG] Not running as admin, attempting elevation...
    echo This script requires administrator privileges.
    echo Attempting to elevate privileges...
    
    REM Self-elevate the script if not already admin
    powershell -Command "Start-Process -FilePath '%~dpnx0' -ArgumentList '%~1', '%~2' -Verb RunAs"
    echo [DEBUG] Elevation command executed with exit code: !errorLevel!
    exit /b
)

echo Running with administrator privileges...
echo [DEBUG] Admin check passed

REM Create a temporary directory with a more unique name
set "TEMP_DIR=%TEMP%\WallpaperSetter_%RANDOM%"
echo [DEBUG] Temp directory path: %TEMP_DIR%
echo Creating temporary directory: %TEMP_DIR%
mkdir "%TEMP_DIR%" 2>nul
echo [DEBUG] Directory creation exit code: !errorLevel!

REM Set script paths and URL
set "PS_SCRIPT=%TEMP_DIR%\set_wallpaper.ps1"
set "PS_URL=https://raw.githubusercontent.com/scogonw/nexus_rmm_scripts/refs/heads/main/windows_scripts/set_wallpaper.ps1"
echo [DEBUG] PowerShell script will be saved to: %PS_SCRIPT%

echo Downloading wallpaper setter script...
echo [DEBUG] Download URL: %PS_URL%

REM Simple command that's less likely to have issues
powershell -Command "Invoke-WebRequest -Uri '%PS_URL%' -OutFile '%PS_SCRIPT%'"

REM Verify download succeeded
if not exist "%PS_SCRIPT%" (
    echo [DEBUG] DOWNLOAD FAILED - File does not exist after download attempt
    echo ERROR: Failed to download the PowerShell script.
    echo Please check your internet connection and try again.
    goto :cleanup
)

echo PowerShell script successfully downloaded.
echo [DEBUG] Confirming script content exists...
powershell -Command "if((Get-Content '%PS_SCRIPT%' -ErrorAction SilentlyContinue).Length -gt 0){Write-Host '[DEBUG] Script contains content'} else {Write-Host '[DEBUG] WARNING: Script file is empty'}"
echo.

REM Check if an image file was provided
if "%~1"=="" (
    echo [DEBUG] No image file parameter provided
    echo ERROR: No image file specified.
    echo Usage: %~nx0 [path_to_image] [style]
    echo Example: %~nx0 C:\wallpaper.jpg Stretch
    echo Available styles: Fill, Fit, Stretch, Tile, Center, Span (default)
    goto :cleanup
)

echo [DEBUG] Image parameter provided: %~1

REM Check if the specified image file exists
if not exist "%~1" (
    echo [DEBUG] Specified image file not found
    echo ERROR: The specified image file does not exist: %~1
    echo Please provide a valid path to an image file.
    goto :cleanup
)

echo [DEBUG] Image file exists
powershell -Command "Write-Host '[DEBUG] Image details:' + (Get-Item '%~1' | Select-Object FullName, Length, LastWriteTime | Format-List | Out-String)"

REM Determine if a style was specified
set "STYLE_PARAM="
if not "%~2"=="" (
    set "STYLE_PARAM=-Style %~2"
    echo [DEBUG] Style parameter provided: %~2
) else (
    echo [DEBUG] No style parameter, using default
)

echo Setting wallpaper to: %~1
if not "%~2"=="" (
    echo Using style: %~2
) else (
    echo Using default style (Span)
)
echo.

echo IMPORTANT: Executing PowerShell script...

REM *** DIRECT EXECUTION - SIMPLEST POSSIBLE APPROACH ***
REM This is the most likely to work without any issues
echo Command: powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" -ImageFile "%~1" %STYLE_PARAM% 

powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" -ImageFile "%~1" %STYLE_PARAM%
set PS_EXIT_CODE=%errorLevel%

echo.
echo PowerShell execution completed with exit code: %PS_EXIT_CODE%
echo.

if %PS_EXIT_CODE% EQU 0 (
    echo =========================================
    echo Wallpaper set successfully!
    echo To verify, check your desktop background
    echo =========================================
) else (
    echo =========================================
    echo ERROR: Failed to set wallpaper (Exit code: %PS_EXIT_CODE%)
    echo =========================================
)

:cleanup
echo.
echo Cleaning up temporary files...
rd /s /q "%TEMP_DIR%" 2>nul
echo [DEBUG] Script completed at: %date% %time%

ENDLOCAL
exit /b %PS_EXIT_CODE% 