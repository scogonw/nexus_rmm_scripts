@echo off
SETLOCAL EnableDelayedExpansion

echo =========================================
echo Windows Wallpaper Setter Utility
echo =========================================
echo.

REM Check if running as administrator
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo This script requires administrator privileges.
    echo Attempting to elevate privileges...
    
    REM Self-elevate the script if not already admin
    powershell -Command "Start-Process -FilePath '%~dpnx0' -ArgumentList '%~1', '%~2' -Verb RunAs"
    exit /b
)

echo Running with administrator privileges...

REM Create a temporary directory with a more unique name
set "TEMP_DIR=%TEMP%\WallpaperSetter_%RANDOM%_%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
mkdir "%TEMP_DIR%" 2>nul

REM Set script paths and URL
set "PS_SCRIPT=%TEMP_DIR%\set_wallpaper.ps1"
set "PS_LOG=%TEMP_DIR%\wallpaper_log.txt"
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

REM Create a wrapper script to ensure proper execution
set "WRAPPER_SCRIPT=%TEMP_DIR%\run_wallpaper_wrapper.ps1"
echo $ErrorActionPreference = 'Continue' > "%WRAPPER_SCRIPT%"
echo $VerbosePreference = 'Continue' >> "%WRAPPER_SCRIPT%"
echo try { >> "%WRAPPER_SCRIPT%"
echo     Write-Verbose "Starting wallpaper setting process..." >> "%WRAPPER_SCRIPT%"
echo     Write-Verbose "PowerShell Version: $($PSVersionTable.PSVersion)" >> "%WRAPPER_SCRIPT%"
echo     Write-Verbose "Script path: '%PS_SCRIPT%'" >> "%WRAPPER_SCRIPT%"
echo     Write-Verbose "Image path: '%~1'" >> "%WRAPPER_SCRIPT%"
echo     Write-Verbose "Style parameter: '%STYLE_PARAM%'" >> "%WRAPPER_SCRIPT%"
echo     $scriptOutput = ^& '%PS_SCRIPT%' -ImageFile '%~1' %STYLE_PARAM% -Verbose *>&1 >> "%WRAPPER_SCRIPT%"
echo     $scriptOutput | ForEach-Object { Write-Verbose $_ } >> "%WRAPPER_SCRIPT%"
echo     if ($LASTEXITCODE -ne 0) { >> "%WRAPPER_SCRIPT%"
echo         throw "PowerShell script execution failed with exit code $LASTEXITCODE" >> "%WRAPPER_SCRIPT%"
echo     } >> "%WRAPPER_SCRIPT%"
echo     Write-Verbose "Wallpaper set successfully!" >> "%WRAPPER_SCRIPT%"
echo } catch { >> "%WRAPPER_SCRIPT%"
echo     Write-Error "Error: $_" >> "%WRAPPER_SCRIPT%"
echo     exit 1 >> "%WRAPPER_SCRIPT%"
echo } >> "%WRAPPER_SCRIPT%"

echo Executing PowerShell script...
powershell -NoProfile -ExecutionPolicy Bypass -File "%WRAPPER_SCRIPT%" 2>"%PS_LOG%"
set PS_EXIT_CODE=%errorLevel%

type "%PS_LOG%"

if %PS_EXIT_CODE% neq 0 (
    echo =========================================
    echo ERROR: The wallpaper setter script encountered an error (Exit code: %PS_EXIT_CODE%)
    echo See detailed log below:
    type "%PS_LOG%"
    echo =========================================
    echo For technical support, the log file is available at: %PS_LOG%
) else (
    echo Wallpaper set successfully!
    echo To verify, check your desktop background
)

echo.
echo Keep temporary files for troubleshooting? (Y/N)
choice /c YN /t 10 /d N /m "Auto-delete in 10 seconds: "
if %errorLevel% equ 2 (
    echo Cleaning up temporary files...
    rd /s /q "%TEMP_DIR%" 2>nul
) else (
    echo Temporary files kept at: %TEMP_DIR%
)

ENDLOCAL
exit /b %PS_EXIT_CODE% 