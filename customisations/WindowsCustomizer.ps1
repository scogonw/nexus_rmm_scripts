#========================================================================
# Windows Customizer - PowerShell Script
# Functions included:
# - Change desktop wallpaper
# - Toggle between dark and light mode
# - Turn on/off Windows transparency effects
#========================================================================

# Requires administrator privileges for some operations
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "This script requires elevation. Please run as Administrator."
    exit
}

function Set-Wallpaper {
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
        return
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
    }
}

function Set-WindowsTheme {
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet('Dark', 'Light')]
        [string]$Theme
    )
    
    $RegistryPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
    
    # Make sure the registry path exists
    if (-not (Test-Path $RegistryPath)) {
        New-Item -Path $RegistryPath -Force | Out-Null
    }
    
    # 0 = Dark mode, 1 = Light mode
    $ThemeValue = if ($Theme -eq 'Dark') { 0 } else { 1 }
    
    # Set app theme
    Set-ItemProperty -Path $RegistryPath -Name 'AppsUseLightTheme' -Value $ThemeValue -Type Dword
    
    # Set system theme
    Set-ItemProperty -Path $RegistryPath -Name 'SystemUsesLightTheme' -Value $ThemeValue -Type Dword
    
    Write-Host "Windows theme has been set to $Theme mode." -ForegroundColor Green
}

function Set-TransparencyEffects {
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet('On', 'Off')]
        [string]$State
    )
    
    $RegistryPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
    
    # Make sure the registry path exists
    if (-not (Test-Path $RegistryPath)) {
        New-Item -Path $RegistryPath -Force | Out-Null
    }
    
    # 1 = Transparency On, 0 = Transparency Off
    $StateValue = if ($State -eq 'On') { 1 } else { 0 }
    
    # Set transparency
    Set-ItemProperty -Path $RegistryPath -Name 'EnableTransparency' -Value $StateValue -Type Dword
    
    Write-Host "Windows transparency effects have been turned $State." -ForegroundColor Green
}

function Show-Menu {
    Clear-Host
    Write-Host "========================================"
    Write-Host "        Windows Customizer Menu         "
    Write-Host "========================================"
    Write-Host "1: Set Desktop Wallpaper"
    Write-Host "2: Set Dark Mode"
    Write-Host "3: Set Light Mode"
    Write-Host "4: Turn On Transparency Effects"
    Write-Host "5: Turn Off Transparency Effects"
    Write-Host "Q: Quit"
    Write-Host "========================================"
}

# Main menu logic
do {
    Show-Menu
    $selection = Read-Host "Please make a selection"
    
    switch ($selection) {
        '1' {
            Write-Host "Enter the full path to the wallpaper image:"
            $wallpaperPath = Read-Host
            
            Write-Host "Select the wallpaper style: (Fill, Fit, Stretch, Tile, Center, Span)"
            $wallpaperStyle = Read-Host
            
            if ([string]::IsNullOrEmpty($wallpaperStyle)) {
                $wallpaperStyle = 'Fill'
            }
            
            Set-Wallpaper -WallpaperPath $wallpaperPath -Style $wallpaperStyle
            
            pause
        }
        '2' {
            Set-WindowsTheme -Theme 'Dark'
            pause
        }
        '3' {
            Set-WindowsTheme -Theme 'Light'
            pause
        }
        '4' {
            Set-TransparencyEffects -State 'On'
            pause
        }
        '5' {
            Set-TransparencyEffects -State 'Off'
            pause
        }
    }
} until ($selection -eq 'q' -or $selection -eq 'Q') 