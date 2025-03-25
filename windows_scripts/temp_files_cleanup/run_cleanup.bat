@echo off
SETLOCAL

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
set "PS_URL=https://raw.githubusercontent.com/scogonw/nexus_rmm_scripts/refs/heads/main/windows_scripts/temp_files_cleanup/temporary_files_cleanup.ps1"

echo Downloading cleanup script...
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

if "%~1"=="" (
    echo No parameters specified - running with default settings.
    powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%"
) else (
    echo Running with custom parameters: %*
    powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" %*
)

if %errorLevel% neq 0 (
    echo The cleanup script encountered an error (Exit code: %errorLevel%)
) else (
    echo Cleanup completed successfully.
)

echo Cleaning up temporary files...
rd /s /q "%TEMP_DIR%" 2>nul

ENDLOCAL
exit /b %errorLevel%