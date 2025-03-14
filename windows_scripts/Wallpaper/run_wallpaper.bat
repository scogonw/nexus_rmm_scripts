@echo off
setlocal EnableDelayedExpansion

echo Scogo Nexus RMM Wallpaper Deployment Tool v1.1.0
echo ----------------------------------------------

:: Check for Administrator privileges
NET SESSION >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] This script requires administrator privileges.
    echo [INFO] Requesting elevation...
    
    :: Get the full path of the script
    set "SCRIPT=%~f0"
    
    :: Self-elevate with the same parameters
    powershell -Command "Start-Process cmd.exe -ArgumentList '/c \"%SCRIPT%\" %*' -Verb RunAs"
    exit /b
)

:: Set default values
set "IMAGE_URL=https://triton-media.s3.ap-south-1.amazonaws.com/media/logos/wallpaper-scogo.jpg"
set "STYLE=Span"

:: Process parameters
if not "%~1"=="" (
    :: Check if URL seems valid
    echo %~1 | findstr /i "^http:/\|^https:/\|^ftp:/\|^ftps:/" >nul
    if %ERRORLEVEL% EQU 0 (
        set "IMAGE_URL=%~1"
        echo [INFO] Using provided URL: !IMAGE_URL!
    ) else (
        echo [WARNING] Invalid URL format: %~1
        echo [INFO] URLs must start with http://, https://, ftp:// or ftps://
        echo [INFO] Using default URL instead: !IMAGE_URL!
    )
) else (
    echo [INFO] No URL provided, using default: !IMAGE_URL!
)

:: Check for style parameter
if not "%~2"=="" (
    :: Validate style parameter
    set "VALID_STYLE=0"
    for %%s in (Fill Fit Stretch Tile Center Span) do (
        if /i "%%s"=="%~2" (
            set "STYLE=%~2"
            set "VALID_STYLE=1"
        )
    )
    
    if "!VALID_STYLE!"=="1" (
        echo [INFO] Using wallpaper style: !STYLE!
    ) else (
        echo [WARNING] Invalid style: %~2. Using default style: !STYLE!
    )
)

echo [INFO] Downloading and setting corporate wallpaper...
echo [INFO] This may take a moment...

:: Define local paths with fallbacks
set "PS_DIR=%ProgramData%\Scogo\Wallpaper"
set "PS_SCRIPT=%PS_DIR%\set_wallpaper.ps1"
set "PS_URL=https://raw.githubusercontent.com/scogonw/nexus_rmm_scripts/refs/heads/main/windows_scripts/Wallpaper/set_wallpaper.ps1"
set "PS_LOCAL_FALLBACK=%~dp0set_wallpaper.ps1"

:: Create directory if it doesn't exist
if not exist "%PS_DIR%" (
    echo [INFO] Creating directory: %PS_DIR%
    mkdir "%PS_DIR%" 2>nul
    if !ERRORLEVEL! NEQ 0 (
        echo [ERROR] Failed to create directory: %PS_DIR%
        echo [INFO] Will use temporary directory instead.
        set "PS_DIR=%TEMP%\Scogo\Wallpaper"
        set "PS_SCRIPT=%PS_DIR%\set_wallpaper.ps1"
        mkdir "%PS_DIR%" 2>nul
    )
)

:: Try to use local script if it exists
if exist "%PS_LOCAL_FALLBACK%" (
    echo [INFO] Found local script, copying to: %PS_SCRIPT%
    copy /Y "%PS_LOCAL_FALLBACK%" "%PS_SCRIPT%" >nul
    if !ERRORLEVEL! NEQ 0 (
        echo [ERROR] Failed to copy local script.
    ) else (
        echo [INFO] Local script copied successfully.
        goto :run_script
    )
)

:: Download the PowerShell script
echo [INFO] Downloading PowerShell script from %PS_URL%...
powershell -Command "& { try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri '%PS_URL%' -OutFile '%PS_SCRIPT%' -TimeoutSec 30; if($?) { Write-Host '[INFO] Download successful.' } } catch { Write-Host '[ERROR] Download failed: ' + $_.Exception.Message; exit 1 } }"

if not exist "%PS_SCRIPT%" (
    echo [ERROR] Failed to download PowerShell script.
    
    :: Try to copy from script directory as fallback
    echo [INFO] Checking for local copy in script directory...
    if exist "%~dp0set_wallpaper.ps1" (
        echo [INFO] Found local copy, using it instead.
        copy /Y "%~dp0set_wallpaper.ps1" "%PS_SCRIPT%" >nul
        if !ERRORLEVEL! NEQ 0 (
            echo [ERROR] Failed to copy script. Exiting.
            exit /b 1
        )
    ) else (
        echo [ERROR] No local copy found. Exiting.
        exit /b 1
    )
)

echo [INFO] PowerShell script ready at: %PS_SCRIPT%

:run_script
:: Run the PowerShell script with parameters
echo [INFO] Executing wallpaper script...
powershell -ExecutionPolicy Bypass -File "%PS_SCRIPT%" -ImageUrl "%IMAGE_URL%" -Style "%STYLE%"
set PS_EXIT_CODE=%ERRORLEVEL%

if %PS_EXIT_CODE% EQU 0 (
    echo [SUCCESS] Wallpaper deployment completed successfully.
) else (
    echo [ERROR] Wallpaper deployment failed with exit code: %PS_EXIT_CODE%
)

exit /b %PS_EXIT_CODE%