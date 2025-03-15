# Wallpaper Restriction Removal Tool

This tool allows users to change their desktop wallpaper by removing the restrictions set by the corporate wallpaper deployment script.

## Overview

The Scogo Nexus RMM Wallpaper Restriction Removal Tool removes registry restrictions that prevent users from changing their desktop wallpaper. It is designed to work alongside the Wallpaper Deployment Tool, giving administrators the flexibility to enable or disable wallpaper changes as needed.

## Features

- Removes registry restrictions that prevent wallpaper changes
- Works for all user profiles on the system
- Removes startup scripts that reset the wallpaper at logon
- Restarts Windows Explorer to apply changes without requiring a reboot
- Resets Active Desktop and personalization settings
- Checks for and updates Group Policy settings
- Compatible with Windows 7 and later versions
- Includes comprehensive error handling and reporting

## Files

- `allow_changing_wallpaper.ps1`: PowerShell script that removes wallpaper restrictions
- `run_allow_changing_wallpaper.bat`: Batch file wrapper that runs the PowerShell script with administrative privileges

## Usage

### Using the Batch File (Recommended)

1. Right-click on `run_allow_changing_wallpaper.bat` and select "Run as administrator", or double-click it to allow automatic elevation
2. The script will automatically remove all wallpaper restrictions and notify you when complete

### Using the PowerShell Script Directly

```powershell
# Run with administrative privileges
powershell -ExecutionPolicy Bypass -File "allow_changing_wallpaper.ps1"
```

## How It Works

The script performs the following comprehensive actions to ensure wallpaper restrictions are completely removed:

1. Removes registry keys that block wallpaper changes from machine-wide policies:
   - `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop\NoChangingWallPaper`
   - `HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization\PreventChangingWallPaper`
   - `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\NoDispBackgroundPage`
   - `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer\NoActiveDesktopChanges`
   - And several additional related keys

2. Removes similar restrictions from all user profiles (individual user registry hives)

3. Applies special changes to the current user's profile to ensure immediate effect

4. Removes the startup script that reapplies the corporate wallpaper at login

5. Resets Active Desktop settings which can sometimes lock wallpaper settings

6. Refreshes desktop settings to apply changes immediately

7. Restarts Windows Explorer to ensure all changes take effect without requiring a reboot

8. Updates Group Policy settings if needed

## After Running the Tool

After running this tool:

1. Users will be able to change their desktop wallpaper through Windows Settings or Control Panel
2. The corporate wallpaper will remain until a user decides to change it
3. The corporate wallpaper will no longer be reapplied at login
4. All wallpaper customization options should be available

## Troubleshooting

If the script reports success but you still cannot change your wallpaper:

1. Try restarting your computer to fully apply all registry changes
2. Check if you're using an image format supported by Windows (JPG, PNG, BMP)
3. Try changing the wallpaper through different methods:
   - Right-click on an image and select "Set as desktop background"
   - Use Windows Settings app: Personalization > Background
   - Use Control Panel: Appearance and Personalization > Personalization
4. Check for any third-party software that might be controlling the wallpaper
5. Run the script again with administrative privileges

## Reapplying Restrictions

If you need to reapply wallpaper restrictions, simply run the corporate wallpaper deployment tool again:

```
run_wallpaper.bat
```

## Version History

- **v1.0.1**: Enhanced restriction removal, resets Explorer, improved compatibility
- **v1.0.0**: Initial release 