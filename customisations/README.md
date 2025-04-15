# Windows Customization Scripts

A collection of PowerShell and Batch scripts for customizing Windows appearance including:
- Changing desktop wallpaper
- Switching between dark and light mode
- Toggling transparency effects

## Requirements

- Windows 10/11
- PowerShell 5.1 or higher
- Administrator privileges (for some operations)

## Usage

### Option 1: All-in-One Menu

#### Using PowerShell Script
1. Right-click on `WindowsCustomizer.ps1` and select "Run with PowerShell" (or "Run as Administrator" for full functionality)
2. Follow the on-screen menu to select desired customizations

#### Using Batch Script
1. Right-click on `WindowsCustomizer.bat` and select "Run as administrator"
2. Follow the on-screen menu to select desired customizations

### Option 2: Individual Scripts

#### Changing Wallpaper

**PowerShell:**
```powershell
# Change wallpaper with default 'Fill' style
.\Set-Wallpaper.ps1 -WallpaperPath "C:\path\to\image.jpg"

# Change wallpaper with specific style
.\Set-Wallpaper.ps1 -WallpaperPath "C:\path\to\image.jpg" -Style "Stretch"
```

**Batch:**
1. Run `SetWallpaper.bat`
2. Enter the full path to the image when prompted
3. Choose a style or press Enter for default (Fill)

**Supported Styles:**
- Fill (default)
- Fit
- Stretch
- Tile
- Center
- Span

#### Setting Dark/Light Mode

**PowerShell:**
```powershell
# Set dark mode
.\Set-WindowsTheme.ps1 -Theme "Dark"

# Set light mode
.\Set-WindowsTheme.ps1 -Theme "Light"
```

**Batch:**
- Run `SetDarkMode.bat` to enable dark mode
- Run `SetLightMode.bat` to enable light mode

#### Toggle Transparency Effects

**PowerShell:**
```powershell
# Enable transparency
.\Set-TransparencyEffects.ps1 -State "On"

# Disable transparency
.\Set-TransparencyEffects.ps1 -State "Off"
```

**Batch:**
- Run `EnableTransparency.bat` to turn on transparency effects
- Run `DisableTransparency.bat` to turn off transparency effects

## Notes

1. Some operations require administrator privileges for full functionality
2. Changes to transparency effects will restart Windows Explorer to apply changes
3. File paths with spaces should be enclosed in quotes

## Examples

```powershell
# Example 1: Set a scenic wallpaper with Fill style
.\Set-Wallpaper.ps1 -WallpaperPath "C:\Users\Username\Pictures\scenic.jpg" -Style "Fill"

# Example 2: Enable dark mode and transparency for a sleek look
.\Set-WindowsTheme.ps1 -Theme "Dark"
.\Set-TransparencyEffects.ps1 -State "On"

# Example 3: Set light mode with no transparency for a clean interface
.\Set-WindowsTheme.ps1 -Theme "Light"
.\Set-TransparencyEffects.ps1 -State "Off"
```

## Troubleshooting

### Issues with Wallpaper:
- Ensure the path to the wallpaper image is correct
- Check that the image file exists and is not corrupted
- Try different styles if the wallpaper doesn't display as expected

### Issues with Theme/Transparency:
- Run the scripts as Administrator
- If changes don't apply, restart Windows Explorer or reboot your system

## License

These scripts are provided as-is under the MIT License. Feel free to modify and distribute as needed. 