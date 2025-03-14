@echo off
setlocal EnableDelayedExpansion

echo Scogo Nexus RMM Wallpaper Restriction Removal Tool v1.0.0
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

:: Define local paths with fallbacks
set "PS_DIR=%ProgramData%\Scogo\Wallpaper"
set "PS_SCRIPT=%PS_DIR%\allow_changing_wallpaper.ps1"
set "PS_LOCAL_FALLBACK=%~dp0allow_changing_wallpaper.ps1"

:: Create directory if it doesn't exist
if not exist "%PS_DIR%" (
    echo [INFO] Creating directory: %PS_DIR%
    mkdir "%PS_DIR%" 2>nul
    if !ERRORLEVEL! NEQ 0 (
        echo [ERROR] Failed to create directory: %PS_DIR%
        echo [INFO] Will use temporary directory instead.
        set "PS_DIR=%TEMP%\Scogo\Wallpaper"
        set "PS_SCRIPT=%PS_DIR%\allow_changing_wallpaper.ps1"
        mkdir "%PS_DIR%" 2>nul
    )
)

:: Try to use local script if it exists (first priority)
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

:: Check if we already have a copy of the script in the destination
if exist "%PS_SCRIPT%" (
    echo [INFO] Found existing script at %PS_SCRIPT%
    echo [INFO] Will use existing script.
    goto :run_script
)

:: If no script exists, we will create a minimal version
echo [ERROR] PowerShell script not found.
echo [INFO] Creating a minimal script...

:: Create a minimal script that removes wallpaper restrictions
(
    echo # Minimal wallpaper restriction removal script
    echo Write-Host "Removing wallpaper restrictions..."
    echo.
    echo # Remove global restrictions
    echo try {
    echo     # Remove ActiveDesktop restriction
    echo     Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop" -Name "NoChangingWallPaper" -Force -ErrorAction SilentlyContinue
    echo.
    echo     # Remove Personalization restriction
    echo     Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization" -Name "PreventChangingWallPaper" -Force -ErrorAction SilentlyContinue
    echo.
    echo     # Remove Control Panel restriction
    echo     Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "NoDispBackgroundPage" -Force -ErrorAction SilentlyContinue
    echo.
    echo     # Remove Explorer restriction
    echo     Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoActiveDesktopChanges" -Force -ErrorAction SilentlyContinue
    echo.
    echo     Write-Host "[SUCCESS] Global wallpaper restrictions removed"
    echo } catch {
    echo     Write-Host "[ERROR] Failed to remove global restrictions: $_"
    echo }
    echo.
    echo # Remove startup script
    echo try {
    echo     $startupFile = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp\RefreshWallpaper.bat"
    echo     if ^(Test-Path $startupFile^) {
    echo         Remove-Item -Path $startupFile -Force
    echo         Write-Host "Removed startup script"
    echo     }
    echo } catch {
    echo     Write-Host "[ERROR] Failed to remove startup script: $_"
    echo }
    echo.
    echo # Refresh desktop settings
    echo try { 
    echo     & rundll32.exe user32.dll,UpdatePerUserSystemParameters
    echo     Write-Host "Desktop settings refreshed"
    echo } catch { }
    echo.
    echo Write-Host "You can now change your wallpaper using Windows Settings or Control Panel."
) > "%PS_SCRIPT%"

if not exist "%PS_SCRIPT%" (
    echo [ERROR] Could not create script. Exiting.
    exit /b 1
) else (
    echo [INFO] Created minimal script.
)

:run_script
:: Run the PowerShell script
echo [INFO] Executing wallpaper restriction removal script...
powershell -ExecutionPolicy Bypass -File "%PS_SCRIPT%" -ErrorAction "Stop"
set PS_EXIT_CODE=%ERRORLEVEL%

if %PS_EXIT_CODE% EQU 0 (
    echo [SUCCESS] Wallpaper restrictions removed successfully.
    echo [INFO] You can now change your wallpaper using Windows Settings or Control Panel.
) else (
    echo [ERROR] Wallpaper restriction removal failed with exit code: %PS_EXIT_CODE%
    
    :: Try a direct method as a last resort
    echo [INFO] Attempting fallback method...
    powershell -ExecutionPolicy Bypass -Command "& { try { Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop' -Name 'NoChangingWallPaper' -Force -ErrorAction SilentlyContinue; Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization' -Name 'PreventChangingWallPaper' -Force -ErrorAction SilentlyContinue; Write-Host '[SUCCESS] Fallback method successful.'; } catch { Write-Host '[ERROR] Fallback method failed: ' + $_.Exception.Message; exit 1 } }"
    set PS_FALLBACK_CODE=%ERRORLEVEL%
    
    if %PS_FALLBACK_CODE% EQU 0 (
        echo [SUCCESS] Wallpaper restrictions removed using fallback method.
        exit /b 0
    ) else (
        echo [ERROR] All methods failed. Unable to remove wallpaper restrictions.
        exit /b %PS_EXIT_CODE%
    )
)

exit /b %PS_EXIT_CODE% 