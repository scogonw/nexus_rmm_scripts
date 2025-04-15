#========================================================================
# Set-Wallpaper.ps1 - Change Windows Desktop Wallpaper
#========================================================================

param (
    [Parameter(Mandatory=$true)]
    [string]$WallpaperPath,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet('Fill', 'Fit', 'Stretch', 'Tile', 'Center', 'Span')]
    [string]$Style = 'Fill'
)

# Check if file exists
if (-not (Test-Path $WallpaperPath)) {
    Write-Error "Wallpaper file not found: $WallpaperPath"
    exit 1
}

# Convert style to numeric value
$StyleValue = switch ($Style) {
    'Fill'    { 10 }
    'Fit'     { 6 }
    'Stretch' { 2 }
    'Tile'    { 1 }
    'Center'  { 0 }
    'Span'    { 22 }
}

# Set registry values
$RegistryPath = 'HKCU:\Control Panel\Desktop'
Set-ItemProperty -Path $RegistryPath -Name WallpaperStyle -Value $StyleValue
Set-ItemProperty -Path $RegistryPath -Name TileWallpaper -Value 0

# Use the .NET method to set the wallpaper
Add-Type -TypeDefinition @"
    using System;
    using System.Runtime.InteropServices;
    
    public class Wallpaper {
        [DllImport("user32.dll", CharSet = CharSet.Auto)]
        public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
    }
"@

$SPI_SETDESKWALLPAPER = 0x0014
$SPIF_UPDATEINIFILE = 0x01
$SPIF_SENDWININICHANGE = 0x02

# Set the wallpaper
$result = [Wallpaper]::SystemParametersInfo($SPI_SETDESKWALLPAPER, 0, $WallpaperPath, $SPIF_UPDATEINIFILE -bor $SPIF_SENDWININICHANGE)

if ($result) {
    Write-Host "Wallpaper has been set to $WallpaperPath with style: $Style" -ForegroundColor Green
} else {
    Write-Error "Failed to set wallpaper."
    exit 1
} 