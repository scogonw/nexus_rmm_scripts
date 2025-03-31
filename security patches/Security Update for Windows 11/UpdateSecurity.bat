@echo off
setlocal enabledelayedexpansion

:: Windows 11 Security Updates Installer Batch Script
:: This script will download and install Windows 11 security updates
:: Run as administrator for best results

:: Set up logging
set LOGDIR=C:\Logs
set TIMESTAMP=%date:~-4,4%%date:~-10,2%%date:~-7,2%_%time:~0,2%%time:~3,2%%time:~6,2%
set TIMESTAMP=!TIMESTAMP: =0!
set LOGFILE=%LOGDIR%\Windows11_Security_Updates_!TIMESTAMP!.log

:: Create log directory if it doesn't exist
if not exist %LOGDIR% mkdir %LOGDIR%

:: Function to log messages
call :log "======================================================"
call :log "Starting Windows 11 Security Updates Installation"
call :log "======================================================"
call :log "Log file: %LOGFILE%"

:: Check for admin rights
NET SESSION >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    call :log "WARNING: Script is not running with administrator privileges"
    call :log "WARNING: Some updates may fail to install"
    call :log "WARNING: For best results, restart this script with administrator privileges"
)

:: Main update process
call :log "Initiating Windows Update process"

:: Using WUAUCLT method for older compatibility
call :log "Using Windows Update Agent method"
call :log "Checking for updates..."
wuauclt /detectnow
call :log "Downloading updates..."
wuauclt /updatenow

:: Using PowerShell for more modern method as backup
call :log "Using PowerShell method as backup"
powershell -Command "& {Write-Host 'Starting PowerShell Windows Update process'; try { Install-Module -Name PSWindowsUpdate -Force -ErrorAction SilentlyContinue; Import-Module PSWindowsUpdate -ErrorAction SilentlyContinue; Get-WindowsUpdate -MicrosoftUpdate -Download -Install -AcceptAll -ErrorAction SilentlyContinue } catch { Write-Host 'PowerShell update method failed: $_' }}"

:: Check if PSWindowsUpdate is installed
powershell -Command "& {if (Get-Module -ListAvailable -Name PSWindowsUpdate) {exit 0} else {exit 1}}" >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    call :log "PSWindowsUpdate module not installed, using built-in methods only"
) else (
    call :log "Using PSWindowsUpdate module for enhanced update capabilities"
    powershell -Command "& {Import-Module PSWindowsUpdate; Get-WindowsUpdate -Category 'Security Updates' -Install -AcceptAll -IgnoreReboot}"
)

:: Using Usoclient (modern method)
call :log "Using modern UsoClient method"
UsoClient StartScan
timeout /t 60 /nobreak
call :log "Starting download of updates"
UsoClient StartDownload
timeout /t 120 /nobreak
call :log "Starting installation of updates"
UsoClient StartInstall

call :log "Update process completed"

:: Check if reboot is needed
wmic /namespace:\\root\ccm\clientsdk path CCM_ClientUtilities call DetermineIfRebootPending >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    call :log "Checking if system restart is required..."
    
    powershell -Command "& {$Reboot = (New-Object -ComObject Microsoft.Update.SystemInfo).RebootRequired; if ($Reboot) {Write-Host 'REBOOT-REQUIRED'} else {Write-Host 'NO-REBOOT-REQUIRED'}}" > %TEMP%\reboot_check.txt
    
    set /p REBOOT_STATUS=<%TEMP%\reboot_check.txt
    del %TEMP%\reboot_check.txt
    
    if "!REBOOT_STATUS!"=="REBOOT-REQUIRED" (
        call :log "WARNING: System restart is required to complete update installation"
        
        echo.
        echo A system restart is required to complete the update installation.
        echo.
        set /p RESTART_NOW="Do you want to restart the computer now? (Y/N): "
        
        if /i "!RESTART_NOW!"=="Y" (
            call :log "Initiating system restart"
            shutdown /r /t 60 /c "Windows will restart in 60 seconds to complete security updates installation"
            echo Windows will restart in 60 seconds.
            echo Close any open applications before the restart.
            timeout /t 55 /nobreak
        ) else (
            call :log "System restart postponed. Please restart your computer as soon as possible."
            echo Please restart your computer as soon as possible to complete the update process.
        )
    ) else (
        call :log "No system restart is required"
    )
) else (
    call :log "Unable to determine if restart is required, please check Windows Update in Settings"
)

call :log "======================================================"
call :log "Windows 11 Security Updates Installation Completed"
call :log "======================================================"

echo.
echo Security updates installation complete.
echo Log file saved to: %LOGFILE%
echo.
pause
goto :eof

:log
echo %date% %time% - %~1
echo %date% %time% - %~1 >> %LOGFILE%
goto :eof