@echo off
:: ========================================================================
:: DisableTransparency.bat - Turn Off Windows Transparency Effects
:: ========================================================================

echo Disabling Windows transparency effects...
powershell -ExecutionPolicy Bypass -File "%~dp0Set-TransparencyEffects.ps1" -State "Off"
echo.
echo Transparency effects have been disabled.
pause 