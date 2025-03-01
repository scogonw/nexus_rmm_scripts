@echo off
SETLOCAL

REM Windows Temporary Files Cleanup Launcher
REM This batch file downloads the PowerShell script from GitHub and runs it

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

REM Create a temporary directory
set "TEMP_DIR=%TEMP%\TempCleanup_%RANDOM%"
mkdir "%TEMP_DIR%" 2>nul

REM Set script paths and URL
set "PS_SCRIPT=%TEMP_DIR%\cleanup.ps1"
set "PS_URL=https://raw.githubusercontent.com/scogonw/nexus_rmm_scripts/refs/heads/main/windows_scripts/temporary_files_cleanup.ps1"

echo Downloading cleanup script...
echo.

REM Download the script using PowerShell
powershell -Command "(New-Object Net.WebClient).DownloadFile('%PS_URL%', '%PS_SCRIPT%')"

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

REM Display mode information
if "%~1"=="" (
    echo No parameters specified - running with default settings (production mode).
    echo.
) else (
    echo Running with custom parameters: "%*"
    echo.
)

REM Directly execute the PowerShell script using -File mode
echo Executing cleanup script...
echo.

REM This is the key part - using the simpler -File parameter approach
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" "%*"

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