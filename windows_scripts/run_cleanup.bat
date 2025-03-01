@echo off
SETLOCAL EnableDelayedExpansion

REM Windows Temporary Files Cleanup Launcher
REM This batch file downloads the PowerShell script from GitHub,
REM bypasses execution policy restrictions, and runs the script.

echo =========================================
echo Windows Temporary Files Cleanup Utility
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

REM Create a unique temp directory
set "TEMP_DIR=%TEMP%\TempCleanup_%RANDOM%"
mkdir "%TEMP_DIR%" 2>nul

REM Set script path and URL
set "PS_SCRIPT=%TEMP_DIR%\cleanup.ps1"
set "PS_URL=https://raw.githubusercontent.com/scogonw/nexus_rmm_scripts/refs/heads/main/windows_scripts/temporary_files_cleanup.ps1"

echo Downloading cleanup script...
echo.

REM Use PowerShell to download the file instead of curl
powershell -Command "& { Invoke-WebRequest -Uri '%PS_URL%' -OutFile '%PS_SCRIPT%' }"

REM Check if download succeeded
if not exist "%PS_SCRIPT%" (
    echo ERROR: Failed to download the PowerShell script.
    echo Please check your internet connection and try again.
    echo.
    rd /s /q "%TEMP_DIR%" 2>nul
    exit /b 1
)

echo PowerShell script successfully downloaded.
echo.

REM Display information about default parameters if none provided
if "%~1"=="" (
    echo No parameters specified - running with default settings (production mode).
    echo Default settings:
    echo - Windows Drive: C:
    echo - Days to Keep: 0 (delete all temporary files regardless of age)
    echo - Prefetch cleaning: Enabled
    echo - Mode: Production (files will be deleted)
    echo.
    
    echo Executing with default parameters...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "& '%PS_SCRIPT%'"
) else (
    echo Executing with provided parameters...
    
    REM Build the parameter string
    set "params="
    for %%a in (%*) do (
        set "params=!params! '%%a'"
    )
    
    REM Execute with parameters
    powershell -NoProfile -ExecutionPolicy Bypass -Command "& '%PS_SCRIPT%'%params%"
)

REM Check exit code
if %errorLevel% neq 0 (
    echo.
    echo The cleanup script encountered an error (Exit code: %errorLevel%).
    echo.
) else (
    echo.
    echo Cleanup completed successfully.
    echo.
)

REM Clean up
echo Cleaning up temporary files...
rd /s /q "%TEMP_DIR%" 2>nul

ENDLOCAL
exit /b %errorLevel% 