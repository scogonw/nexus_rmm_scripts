@echo off
:: ========================================================================
:: SetLightMode.bat - Apply Windows Light Theme
:: ========================================================================

echo Setting Windows to Light Mode...
powershell -ExecutionPolicy Bypass -File "%~dp0Set-WindowsTheme.ps1" -Theme "Light"
echo.
echo Light mode has been applied.
pause 