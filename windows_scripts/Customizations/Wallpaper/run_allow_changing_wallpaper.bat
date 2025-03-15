@echo off
setlocal EnableDelayedExpansion

echo Scogo Nexus RMM Wallpaper Restriction Removal Tool v1.0.1
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
set "PS_URL=https://raw.githubusercontent.com/scogonw/nexus_rmm_scripts/refs/heads/main/windows_scripts/Wallpaper/allow_changing_wallpaper.ps1"

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

:: Download the PowerShell script from GitHub
echo [INFO] Downloading PowerShell script from %PS_URL%...
powershell -Command "& { try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri '%PS_URL%' -OutFile '%PS_SCRIPT%' -UseBasicParsing -TimeoutSec 30; if($?) { Write-Host '[INFO] Download successful.' } } catch { Write-Host '[ERROR] Download failed: ' + $_.Exception.Message; exit 1 } }"

if not exist "%PS_SCRIPT%" (
    echo [ERROR] Failed to download PowerShell script.
    
    :: Try to copy from script directory as fallback
    echo [INFO] Checking for local copy in script directory...
    if exist "%~dp0allow_changing_wallpaper.ps1" (
        echo [INFO] Found local copy, using it instead.
        copy /Y "%~dp0allow_changing_wallpaper.ps1" "%PS_SCRIPT%" >nul
        if !ERRORLEVEL! NEQ 0 (
            echo [ERROR] Failed to copy script. Will create minimal version.
        ) else (
            echo [INFO] Local copy used successfully.
            goto :run_script
        )
    )
    
    :: If no script exists, we will create a minimal version
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
        echo     Remove-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop" -Force -Recurse -ErrorAction SilentlyContinue
        echo.
        echo     # Remove Personalization restriction
        echo     Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization" -Name "PreventChangingWallPaper" -Force -ErrorAction SilentlyContinue
        echo     Remove-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization" -Force -Recurse -ErrorAction SilentlyContinue
        echo.
        echo     # Remove Control Panel restriction
        echo     Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "NoDispBackgroundPage" -Force -ErrorAction SilentlyContinue
        echo     Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "NoDispAppearancePage" -Force -ErrorAction SilentlyContinue
        echo.
        echo     # Remove Explorer restriction
        echo     Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoActiveDesktopChanges" -Force -ErrorAction SilentlyContinue
        echo     Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoDesktop" -Force -ErrorAction SilentlyContinue
        echo.
        echo     # Remove current user restrictions too
        echo     Remove-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop" -Force -Recurse -ErrorAction SilentlyContinue
        echo     Remove-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System" -Force -Recurse -ErrorAction SilentlyContinue
        echo     Remove-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Force -Recurse -ErrorAction SilentlyContinue
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
        echo     
        echo     $refreshScript = "C:\ProgramData\Scogo\Wallpaper\RefreshWallpaper.ps1"
        echo     if ^(Test-Path $refreshScript^) {
        echo         Remove-Item -Path $refreshScript -Force
        echo         Write-Host "Removed refresh script"
        echo     }
        echo     
        echo     try {
        echo         $taskExists = Get-ScheduledTask -TaskName "RefreshCorporateWallpaper" -ErrorAction SilentlyContinue
        echo         if ^($taskExists^) {
        echo             Unregister-ScheduledTask -TaskName "RefreshCorporateWallpaper" -Confirm:$false
        echo             Write-Host "Removed scheduled task"
        echo         }
        echo     } catch {
        echo         # Try alternative method
        echo         try {
        echo             schtasks /Delete /TN "RefreshCorporateWallpaper" /F 2^>$null
        echo         } catch { }
        echo     }
        echo } catch {
        echo     Write-Host "[ERROR] Failed to remove startup script: $_"
        echo }
        echo.
        echo # Restart Explorer to apply changes
        echo try {
        echo     $explorerProcesses = Get-Process -Name "explorer" -ErrorAction SilentlyContinue
        echo     if ^($explorerProcesses^) {
        echo         $explorerProcesses ^| ForEach-Object { Stop-Process -Id $_.Id -Force }
        echo         Start-Sleep -Seconds 2
        echo         Start-Process "explorer.exe"
        echo         Write-Host "Restarted Explorer"
        echo     }
        echo } catch { }
        echo.
        echo # Refresh desktop settings
        echo try { 
        echo     & rundll32.exe user32.dll,UpdatePerUserSystemParameters
        echo     & rundll32.exe user32.dll,UpdatePerUserSystemParameters 1, True
        echo     Write-Host "Desktop settings refreshed"
        echo } catch { }
        echo.
        echo Write-Host "You can now change your wallpaper using Windows Settings or Control Panel."
        echo Write-Host "If you still cannot change your wallpaper, try restarting your computer."
    ) > "%PS_SCRIPT%"

    if not exist "%PS_SCRIPT%" (
        echo [ERROR] Could not create script. Exiting.
        exit /b 1
    ) else (
        echo [INFO] Created minimal script.
    )
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
    powershell -ExecutionPolicy Bypass -Command "& { try { Remove-Item -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop' -Force -Recurse -ErrorAction SilentlyContinue; Remove-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization' -Force -Recurse -ErrorAction SilentlyContinue; Remove-Item -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop' -Force -Recurse -ErrorAction SilentlyContinue; Remove-Item -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System' -Force -Recurse -ErrorAction SilentlyContinue; $explorerProcesses = Get-Process -Name 'explorer' -ErrorAction SilentlyContinue; if ($explorerProcesses) { $explorerProcesses | ForEach-Object { Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue }; Start-Sleep -Seconds 2; Start-Process 'explorer.exe'; }; & rundll32.exe user32.dll,UpdatePerUserSystemParameters 1, True; Write-Host '[SUCCESS] Fallback method successful.'; } catch { Write-Host '[ERROR] Fallback method failed: ' + $_.Exception.Message; exit 1 } }"
    set PS_FALLBACK_CODE=%ERRORLEVEL%
    
    if %PS_FALLBACK_CODE% EQU 0 (
        echo [SUCCESS] Wallpaper restrictions removed using fallback method.
        echo [INFO] You may need to restart your computer for all changes to take effect.
        exit /b 0
    ) else (
        echo [ERROR] All methods failed. Unable to remove wallpaper restrictions.
        echo [INFO] You may need to restart your computer and try again.
        exit /b %PS_EXIT_CODE%
    )
)

exit /b %PS_EXIT_CODE% 