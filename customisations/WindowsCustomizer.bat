@echo off
:: ========================================================================
:: Windows Customizer - Batch Script Launcher
:: This script provides options to customize Windows appearance including:
:: - Changing desktop wallpaper
:: - Switching between dark and light mode
:: - Turning on/off Windows transparency effects
:: ========================================================================

:: Check for Admin rights
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Administrative privileges required. Please run as Administrator.
    pause
    exit /b 1
)

:menu
cls
echo ========================================
echo         Windows Customizer Menu
echo ========================================
echo 1: Set Desktop Wallpaper
echo 2: Set Dark Mode
echo 3: Set Light Mode
echo 4: Turn On Transparency Effects
echo 5: Turn Off Transparency Effects
echo Q: Quit
echo ========================================

set /p choice="Please make a selection: "

if "%choice%"=="1" goto wallpaper
if "%choice%"=="2" goto darkmode
if "%choice%"=="3" goto lightmode
if "%choice%"=="4" goto transon
if "%choice%"=="5" goto transoff
if /i "%choice%"=="q" goto end

echo Invalid selection. Please try again.
timeout /t 2 >nul
goto menu

:wallpaper
set /p wallpath="Enter the full path to the wallpaper image: "
set /p style="Select the wallpaper style (Fill, Fit, Stretch, Tile, Center, Span): "

if "%style%"=="" set style=Fill

powershell -ExecutionPolicy Bypass -Command "& {Import-Module '%~dp0WindowsCustomizer.ps1'; Set-Wallpaper -WallpaperPath '%wallpath%' -Style '%style%'}"
pause
goto menu

:darkmode
powershell -ExecutionPolicy Bypass -Command "& {Import-Module '%~dp0WindowsCustomizer.ps1'; Set-WindowsTheme -Theme 'Dark'}"
echo Dark mode has been applied.
pause
goto menu

:lightmode
powershell -ExecutionPolicy Bypass -Command "& {Import-Module '%~dp0WindowsCustomizer.ps1'; Set-WindowsTheme -Theme 'Light'}"
echo Light mode has been applied.
pause
goto menu

:transon
powershell -ExecutionPolicy Bypass -Command "& {Import-Module '%~dp0WindowsCustomizer.ps1'; Set-TransparencyEffects -State 'On'}"
echo Transparency effects have been turned on.
pause
goto menu

:transoff
powershell -ExecutionPolicy Bypass -Command "& {Import-Module '%~dp0WindowsCustomizer.ps1'; Set-TransparencyEffects -State 'Off'}"
echo Transparency effects have been turned off.
pause
goto menu

:end
echo Thank you for using Windows Customizer!
timeout /t 2 >nul
exit /b 0 