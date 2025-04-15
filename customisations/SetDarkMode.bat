@echo off
:: ========================================================================
:: SetDarkMode.bat - Apply Windows Dark Theme
:: ========================================================================

echo Setting Windows to Dark Mode...
powershell -ExecutionPolicy Bypass -File "%~dp0Set-WindowsTheme.ps1" -Theme "Dark"
echo.
echo Dark mode has been applied.
pause 