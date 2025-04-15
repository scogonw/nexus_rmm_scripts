@echo off
:: ========================================================================
:: EnableTransparency.bat - Turn On Windows Transparency Effects
:: ========================================================================

echo Enabling Windows transparency effects...
powershell -ExecutionPolicy Bypass -File "%~dp0Set-TransparencyEffects.ps1" -State "On"
echo.
echo Transparency effects have been enabled.
pause 