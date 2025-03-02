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
powershell -Command "(New-Object Net.WebClient).DownloadFile('%PS_URL%', '%PS_SCRIPT%'); if(Test-Path '%PS_SCRIPT%'){Write-Host '[DEBUG] File size: ' + (Get-Item '%PS_SCRIPT%').Length + ' bytes'}"

if not exist "%PS_SCRIPT%" (
    echo [DEBUG] DOWNLOAD FAILED - File does not exist after download attempt
    echo ERROR: Failed to download the PowerShell script.
    echo Please check your internet connection and try again.
    echo.
    rd /s /q "%TEMP_DIR%" 2>nul
    exit /b 1
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
    echo.
    rd /s /q "%TEMP_DIR%" 2>nul
    exit /b 1
)

echo [DEBUG] Image parameter provided: %~1

REM Check if the specified image file exists
if not exist "%~1" (
    echo [DEBUG] Specified image file not found
    echo ERROR: The specified image file does not exist: %~1
    echo Please provide a valid path to an image file.
    echo.
    rd /s /q "%TEMP_DIR%" 2>nul
    exit /b 1
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

echo Preparing to execute PowerShell script...
echo [DEBUG] PowerShell environment details:
powershell -Command "Write-Host '[DEBUG] PowerShell version: ' + $PSVersionTable.PSVersion; Write-Host '[DEBUG] .NET version: ' + [Environment]::Version"

REM Create a debug-focused script wrapper
set "DEBUG_WRAPPER=%TEMP_DIR%\debug_wrapper.ps1"
echo [DEBUG] Creating debug wrapper script: %DEBUG_WRAPPER%

echo # Debug wrapper for set_wallpaper.ps1 > "%DEBUG_WRAPPER%"
echo $ErrorActionPreference = 'Continue' >> "%DEBUG_WRAPPER%"
echo $VerbosePreference = 'Continue' >> "%DEBUG_WRAPPER%"
echo $DebugPreference = 'Continue' >> "%DEBUG_WRAPPER%"
echo Write-Host "`n[DEBUG] ===== STARTING POWERSHELL SCRIPT EXECUTION =====" -ForegroundColor Cyan >> "%DEBUG_WRAPPER%"
echo Write-Host "[DEBUG] Parameters:" -ForegroundColor Cyan >> "%DEBUG_WRAPPER%"
echo Write-Host "[DEBUG]   - ImageFile: '%~1'" -ForegroundColor Cyan >> "%DEBUG_WRAPPER%"
echo if ('%STYLE_PARAM%' -ne '') { Write-Host "[DEBUG]   - Style: %~2" -ForegroundColor Cyan } >> "%DEBUG_WRAPPER%"
echo Write-Host "[DEBUG] System Info:" -ForegroundColor Cyan >> "%DEBUG_WRAPPER%"
echo Write-Host "[DEBUG]   - Current user: $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)" -ForegroundColor Cyan >> "%DEBUG_WRAPPER%"
echo Write-Host "[DEBUG]   - Is admin: $([bool](New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))" -ForegroundColor Cyan >> "%DEBUG_WRAPPER%"
echo Write-Host "[DEBUG]   - PS Execution Policy: $(Get-ExecutionPolicy)" -ForegroundColor Cyan >> "%DEBUG_WRAPPER%"
echo Write-Host "[DEBUG] Script source content preview (first 5 lines):" -ForegroundColor Cyan >> "%DEBUG_WRAPPER%"
echo Get-Content '%PS_SCRIPT%' -TotalCount 5 | ForEach-Object { Write-Host "[DEBUG]   $_" -ForegroundColor Gray } >> "%DEBUG_WRAPPER%"
echo Write-Host "`n[DEBUG] ===== EXECUTING MAIN SCRIPT =====" -ForegroundColor Cyan >> "%DEBUG_WRAPPER%"
echo try { >> "%DEBUG_WRAPPER%"
echo     # All output streams (1-6) get merged to output stream >> "%DEBUG_WRAPPER%"
echo     & '%PS_SCRIPT%' -ImageFile '%~1' %STYLE_PARAM% -Verbose -Debug *>&1 | ForEach-Object { >> "%DEBUG_WRAPPER%"
echo         $_  # This ensures all output is displayed >> "%DEBUG_WRAPPER%"
echo     } >> "%DEBUG_WRAPPER%"
echo     $script:LastExitCode = $LASTEXITCODE >> "%DEBUG_WRAPPER%"
echo     Write-Host "`n[DEBUG] ===== SCRIPT EXECUTION COMPLETED =====" -ForegroundColor Cyan >> "%DEBUG_WRAPPER%"
echo     Write-Host "[DEBUG] Exit code: $script:LastExitCode" -ForegroundColor Cyan >> "%DEBUG_WRAPPER%"
echo } catch { >> "%DEBUG_WRAPPER%"
echo     Write-Host "`n[DEBUG] ===== ERROR OCCURRED =====" -ForegroundColor Red >> "%DEBUG_WRAPPER%"
echo     Write-Host "[DEBUG] Error in PowerShell script execution:" -ForegroundColor Red >> "%DEBUG_WRAPPER%"
echo     Write-Host $_.Exception.Message -ForegroundColor Red >> "%DEBUG_WRAPPER%"
echo     Write-Host "[DEBUG] Stack trace:" -ForegroundColor Red >> "%DEBUG_WRAPPER%"
echo     Write-Host $_.ScriptStackTrace -ForegroundColor Red >> "%DEBUG_WRAPPER%"
echo     $script:LastExitCode = 1 >> "%DEBUG_WRAPPER%"
echo } >> "%DEBUG_WRAPPER%"
echo exit $script:LastExitCode >> "%DEBUG_WRAPPER%"

echo [DEBUG] Executing wrapper script...
echo Running PowerShell with all debug output enabled:
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%DEBUG_WRAPPER%"
set PS_EXIT_CODE=%errorLevel%

echo.
echo PowerShell script execution completed with exit code: %PS_EXIT_CODE%
echo.

if %PS_EXIT_CODE% neq 0 (
    echo =========================================
    echo ERROR: The wallpaper setter script encountered an error ^(Exit code: %PS_EXIT_CODE%^)
    echo Check the output above for detailed error information
    echo =========================================
) else (
    echo =========================================
    echo Wallpaper set successfully!
    echo To verify, check your desktop background
    echo =========================================
)

echo.
echo [DEBUG] Final cleanup...
echo Cleaning up temporary files...
rd /s /q "%TEMP_DIR%" 2>nul
echo [DEBUG] Script completed at: %date% %time%

ENDLOCAL
exit /b %PS_EXIT_CODE% 