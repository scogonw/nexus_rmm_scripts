@echo off
:: =======================================================================
:: Create User Script for Windows (Batch Wrapper)
:: =======================================================================
:: Description: Wrapper script that downloads and executes the PowerShell
::              script for creating user accounts on Windows systems.
:: Author: Nexus RMM Team
:: Date: %date%
:: Version: 1.0
:: =======================================================================

SETLOCAL EnableDelayedExpansion

:: Check for administrator privileges
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo ERROR: This script must be run with administrator privileges.
    echo Please right-click and select "Run as administrator"
    exit /b 1
)

:: Setup logging
set "LOG_DIR=%ProgramData%\Nexus_RMM\Logs"
set "LOG_FILE=%LOG_DIR%\user_management.log"

:: Create log directory if it doesn't exist
if not exist "%LOG_DIR%" (
    mkdir "%LOG_DIR%" 2>nul
    if errorlevel 1 (
        echo WARNING: Failed to create log directory. Logs will be written to temp directory.
        set "LOG_FILE=%TEMP%\nexus_user_management.log"
    )
)

:: Log script start with timestamp
echo %date% %time% [INFO] User management batch wrapper started >> "%LOG_FILE%"

:: Create a temporary directory for script execution
set "TEMP_DIR=%TEMP%\UserMgmt_%RANDOM%"
mkdir "%TEMP_DIR%" 2>nul

:: Configure script paths and URLs
:: Uncomment and modify this URL if you want to download the script from a repository
:: set "PS_URL=https://raw.githubusercontent.com/YOUR_ORG/nexus_rmm_scripts/main/windows_scripts/User_Management/create_user_windows.ps1"
set "PS_SCRIPT=%TEMP_DIR%\create_user_windows.ps1"
set "LOCAL_PS_SCRIPT=%~dp0create_user_windows.ps1"

:: Check if local PowerShell script exists
if exist "%LOCAL_PS_SCRIPT%" (
    echo %date% %time% [INFO] Using local PowerShell script >> "%LOG_FILE%"
    copy "%LOCAL_PS_SCRIPT%" "%PS_SCRIPT%" >nul
    echo Using local PowerShell script...
) else (
    :: Uncomment this section if you want to download the script
    :: echo Downloading user management script...
    :: powershell -Command "(New-Object Net.WebClient).DownloadFile('%PS_URL%', '%PS_SCRIPT%')"
    ::
    :: if not exist "%PS_SCRIPT%" (
    ::     echo ERROR: Failed to download the PowerShell script.
    ::     echo Please check your internet connection and try again.
    ::     echo %date% %time% [ERROR] Failed to download PowerShell script >> "%LOG_FILE%"
    ::     rd /s /q "%TEMP_DIR%" 2>nul
    ::     exit /b 1
    :: )
    
    echo ERROR: PowerShell script not found at %LOCAL_PS_SCRIPT%
    echo %date% %time% [ERROR] PowerShell script not found >> "%LOG_FILE%"
    rd /s /q "%TEMP_DIR%" 2>nul
    exit /b 1
)

:: Process parameters to pass to PowerShell script
set "PS_PARAMS="

:parse_args
if "%~1"=="" goto :execute_script

if /i "%~1"=="-u" (
    set "PS_PARAMS=!PS_PARAMS! -Username %~2"
    shift
    shift
    goto :parse_args
)
if /i "%~1"=="--username" (
    set "PS_PARAMS=!PS_PARAMS! -Username %~2"
    shift
    shift
    goto :parse_args
)
if /i "%~1"=="-f" (
    set "PS_PARAMS=!PS_PARAMS! -FullName %~2"
    shift
    shift
    goto :parse_args
)
if /i "%~1"=="--fullname" (
    set "PS_PARAMS=!PS_PARAMS! -FullName %~2"
    shift
    shift
    goto :parse_args
)
if /i "%~1"=="-a" (
    set "PS_PARAMS=!PS_PARAMS! -IsAdmin"
    shift
    goto :parse_args
)
if /i "%~1"=="--admin" (
    set "PS_PARAMS=!PS_PARAMS! -IsAdmin"
    shift
    goto :parse_args
)
if /i "%~1"=="-h" (
    goto :display_help
)
if /i "%~1"=="--help" (
    goto :display_help
)

:: If we get here, it's an unrecognized parameter, pass it through to PowerShell
set "PS_PARAMS=!PS_PARAMS! %~1"
shift
goto :parse_args

:execute_script
:: Execute the PowerShell script with appropriate parameters
echo Executing PowerShell script with parameters: %PS_PARAMS%
echo %date% %time% [INFO] Executing PowerShell script with parameters: %PS_PARAMS% >> "%LOG_FILE%"

:: Execute PowerShell with Bypass execution policy
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" %PS_PARAMS%

:: Capture the error level from PowerShell
set PS_ERROR=%errorLevel%

:: Clean up temporary files
rd /s /q "%TEMP_DIR%" 2>nul

:: Log completion
if %PS_ERROR% neq 0 (
    echo %date% %time% [ERROR] PowerShell script execution failed with exit code: %PS_ERROR% >> "%LOG_FILE%"
    echo.
    echo User creation failed. Please check the log for details.
    echo Log location: %LOG_FILE%
) else (
    echo %date% %time% [INFO] PowerShell script executed successfully >> "%LOG_FILE%"
)

exit /b %PS_ERROR%

:display_help
echo Usage: %~nx0 [OPTIONS]
echo Creates a new user account with the specified settings
echo.
echo Options:
echo   -u, --username USERNAME     Username for the new account (required)
echo   -f, --fullname "FULL NAME"  Full name for the user (optional)
echo   -a, --admin                 Add user to Administrators group (optional)
echo   -h, --help                  Display this help and exit
echo.
echo Example:
echo   %~nx0 -u jsmith -f "John Smith" -a
echo.
rd /s /q "%TEMP_DIR%" 2>nul
exit /b 1 