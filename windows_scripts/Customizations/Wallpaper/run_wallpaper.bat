@echo off
setlocal EnableDelayedExpansion

echo Scogo Nexus RMM Wallpaper Deployment Tool v1.1.2
echo ----------------------------------------------

:: Set default values
set "DEFAULT_URL=https://triton-media.s3.ap-south-1.amazonaws.com/media/logos/wallpaper-scogo.jpg"
set "WALLPAPER_URL=%DEFAULT_URL%"
set "WALLPAPER_STYLE=Fit"

:: Process URL parameter if provided
if not "%~1"=="" (
    set "USER_URL=%~1"
    
    :: Remove @ if present at the start
    if "!USER_URL:~0,1!"=="@" (
        set "USER_URL=!USER_URL:~1!"
    )
    
    echo [INFO] User provided URL: !USER_URL!
    set "WALLPAPER_URL=!USER_URL!"
) else (
    echo [INFO] No URL parameter provided, using default URL
)

:: Process style parameter if provided
if not "%~2"=="" (
    set "WALLPAPER_STYLE=%~2"
    echo [INFO] Using custom style: !WALLPAPER_STYLE!
) else (
    echo [INFO] Using default style: !WALLPAPER_STYLE!
)

echo [INFO] Wallpaper URL: !WALLPAPER_URL!
echo [INFO] Wallpaper Style: !WALLPAPER_STYLE!

:: Create directories
set "WALLPAPER_DIR=%TEMP%\Scogo\Wallpaper"
mkdir "%WALLPAPER_DIR%" 2>nul
set "WALLPAPER_FILE=%WALLPAPER_DIR%\corporate-wallpaper.jpg"

:: Download wallpaper
echo [INFO] Downloading wallpaper...

:: Create a simple PowerShell script for downloading the wallpaper
set "DOWNLOAD_PS=%TEMP%\download_wallpaper.ps1"
echo [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 > "%DOWNLOAD_PS%"
echo try { >> "%DOWNLOAD_PS%"
echo     Invoke-WebRequest -Uri '%WALLPAPER_URL%' -OutFile '%WALLPAPER_FILE%' -UseBasicParsing >> "%DOWNLOAD_PS%"
echo     Write-Host '[SUCCESS] Wallpaper downloaded successfully' >> "%DOWNLOAD_PS%"
echo     exit 0 >> "%DOWNLOAD_PS%"
echo } catch { >> "%DOWNLOAD_PS%"
echo     Write-Host '[ERROR] Failed to download wallpaper: ' $_.Exception.Message >> "%DOWNLOAD_PS%"
echo     exit 1 >> "%DOWNLOAD_PS%"
echo } >> "%DOWNLOAD_PS%"

:: Execute the download script
powershell -ExecutionPolicy Bypass -File "%DOWNLOAD_PS%"

if not %ERRORLEVEL% == 0 (
    echo [ERROR] Failed to download wallpaper
    del "%DOWNLOAD_PS%" 2>nul
    exit /b 1
)

:: Create a simpler PowerShell script for setting the wallpaper
set "WALLPAPER_PS=%TEMP%\set_wallpaper.ps1"
echo # Wallpaper setting script > "%WALLPAPER_PS%"
echo Add-Type -TypeDefinition @' >> "%WALLPAPER_PS%"
echo using System; >> "%WALLPAPER_PS%"
echo using System.Runtime.InteropServices; >> "%WALLPAPER_PS%"
echo public class Wallpaper { >> "%WALLPAPER_PS%"
echo     [DllImport("user32.dll", CharSet = CharSet.Auto)] >> "%WALLPAPER_PS%"
echo     public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni); >> "%WALLPAPER_PS%"
echo } >> "%WALLPAPER_PS%"
echo '@ >> "%WALLPAPER_PS%"
echo. >> "%WALLPAPER_PS%"
echo $style = '%WALLPAPER_STYLE%' >> "%WALLPAPER_PS%"
echo $styleValue = switch ($style) { >> "%WALLPAPER_PS%"
echo     'Fill'    {10} >> "%WALLPAPER_PS%"
echo     'Fit'     {6} >> "%WALLPAPER_PS%"
echo     'Stretch' {2} >> "%WALLPAPER_PS%"
echo     'Tile'    {0} >> "%WALLPAPER_PS%"
echo     'Center'  {0} >> "%WALLPAPER_PS%"
echo     'Span'    {22} >> "%WALLPAPER_PS%"
echo     default   {6} >> "%WALLPAPER_PS%"
echo } >> "%WALLPAPER_PS%"
echo. >> "%WALLPAPER_PS%"
echo try { >> "%WALLPAPER_PS%"
echo     # Set registry values >> "%WALLPAPER_PS%"
echo     $null = New-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name WallpaperStyle -PropertyType String -Value $styleValue -Force >> "%WALLPAPER_PS%"
echo     $null = New-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name TileWallpaper -PropertyType String -Value 0 -Force >> "%WALLPAPER_PS%"
echo     # Set the wallpaper >> "%WALLPAPER_PS%"
echo     $result = [Wallpaper]::SystemParametersInfo(20, 0, '%WALLPAPER_FILE%', 3) >> "%WALLPAPER_PS%"
echo     Write-Host "[INFO] SystemParametersInfo result: $result" >> "%WALLPAPER_PS%"
echo     Write-Host '[SUCCESS] Wallpaper set successfully' >> "%WALLPAPER_PS%"
echo     # Force refresh desktop >> "%WALLPAPER_PS%"
echo     RUNDLL32.EXE user32.dll,UpdatePerUserSystemParameters >> "%WALLPAPER_PS%"
echo     exit 0 >> "%WALLPAPER_PS%"
echo } catch { >> "%WALLPAPER_PS%"
echo     Write-Host '[ERROR] Failed to set wallpaper: ' $_.Exception.Message >> "%WALLPAPER_PS%"
echo     exit 1 >> "%WALLPAPER_PS%"
echo } >> "%WALLPAPER_PS%"

:: Set wallpaper
echo [INFO] Setting wallpaper...
powershell -ExecutionPolicy Bypass -File "%WALLPAPER_PS%"

:: Clean up
del "%DOWNLOAD_PS%" 2>nul
del "%WALLPAPER_PS%" 2>nul

if %ERRORLEVEL% == 0 (
    echo [SUCCESS] Wallpaper deployment completed successfully.
    
    :: Add final desktop refresh attempt via direct command
    echo [INFO] Final desktop refresh...
    rundll32.exe user32.dll,UpdatePerUserSystemParameters
    
    echo [SUCCESS] Process completed. Your wallpaper has been set.
) else (
    echo [ERROR] Failed to set wallpaper.
    exit /b 1
)

exit /b 0