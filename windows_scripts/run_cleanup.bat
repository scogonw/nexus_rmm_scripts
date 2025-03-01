@echo off
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
    pause
    exit /b 1
)

REM Set up script locations
set "TEMP_DIR=%TEMP%\TempCleanup_%RANDOM%"
set "PS_SCRIPT=%TEMP_DIR%\temporary_files_cleanup.ps1"

REM Set GitHub URL for the PowerShell script
set "PS_URL=https://raw.githubusercontent.com/scogonw/nexus_rmm_scripts/refs/heads/main/windows_scripts/temporary_files_cleanup.ps1"

REM Create temporary directory
mkdir "%TEMP_DIR%" 2>nul

echo Downloading cleanup script from GitHub...
echo Source: %PS_URL%
echo.

REM Try to use curl (available on Windows 10/11)
curl -s -o "%PS_SCRIPT%" "%PS_URL%" 

REM Verify download succeeded
if not exist "%PS_SCRIPT%" (
    echo ERROR: Failed to download the PowerShell script.
    echo Please check your internet connection and try again.
    echo.
    rmdir /s /q "%TEMP_DIR%" 2>nul
    pause
    exit /b 1
)

echo PowerShell script successfully downloaded.
echo.

REM Parse command-line arguments to pass to the PowerShell script
set "PS_ARGS="
if "%~1"=="" (
    echo No parameters specified. 
    echo.
    echo Available options:
    echo   -TestMode           : Test only, no files will be deleted
    echo   -WindowsDrive X:    : Specify Windows drive (default is C:)
    echo   -DaysToKeep N       : Keep files newer than N days
    echo   -SkipPrefetch       : Skip cleaning prefetch folder
    echo   -LogPath "path"     : Custom log path
    echo.
    echo Example usage:
    echo   %~nx0 -TestMode
    echo   %~nx0 -WindowsDrive D: -DaysToKeep 7
    echo.
    
    choice /C YNT /N /M "Run with: [Y]No parameters [N]Quit [T]Test mode "
    
    if %errorLevel%==1 goto execute
    if %errorLevel%==2 (
        echo Cleaning up temporary files...
        rmdir /s /q "%TEMP_DIR%" 2>nul
        exit /b 0
    )
    if %errorLevel%==3 (
        set "PS_ARGS=-TestMode"
        goto execute
    )
) else (
    set "PS_ARGS=%*"
)

:execute
echo Executing cleanup script with execution policy bypass...
echo Command: powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" %PS_ARGS%
echo.

REM Run the PowerShell script with execution policy bypass
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" %PS_ARGS%

REM Check if the script executed successfully
if %errorLevel% neq 0 (
    echo.
    echo The cleanup script encountered an error.
    echo.
) else (
    echo.
    echo Cleanup completed successfully.
    echo.
)

REM Clean up the downloaded script
echo Cleaning up temporary files...
rmdir /s /q "%TEMP_DIR%" 2>nul

pause
exit /b %errorLevel% 