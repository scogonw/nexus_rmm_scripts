@echo off
:: ========================================================================
:: SetWallpaper.bat - Change Windows Desktop Wallpaper
:: ========================================================================

echo Windows Wallpaper Changer
echo ========================

set /p wallpath="Enter the full path to the wallpaper image: "
set /p style="Select the wallpaper style (Fill, Fit, Stretch, Tile, Center, Span) [Default=Fill]: "

if "%style%"=="" set style=Fill

powershell -ExecutionPolicy Bypass -File "%~dp0Set-Wallpaper.ps1" -WallpaperPath "%wallpath%" -Style "%style%"
pause 