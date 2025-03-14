# Wallpaper Restriction Removal Tool

This tool allows users to change their desktop wallpaper by removing the restrictions set by the corporate wallpaper deployment script.

## Overview

The Scogo Nexus RMM Wallpaper Restriction Removal Tool removes registry restrictions that prevent users from changing their desktop wallpaper. It is designed to work alongside the Wallpaper Deployment Tool, giving administrators the flexibility to enable or disable wallpaper changes as needed.

## Features

- Removes registry restrictions that prevent wallpaper changes
- Works for all user profiles on the system
- Removes startup scripts that reset the wallpaper at logon
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

The script performs the following actions:

1. Removes registry keys that block wallpaper changes from machine-wide policies:
   - `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop\NoChangingWallPaper`
   - `HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization\PreventChangingWallPaper`
   - `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\NoDispBackgroundPage`
   - `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer\NoActiveDesktopChanges`

2. Removes similar restrictions from all user profiles

3. Removes the startup script that reapplies the corporate wallpaper at login

4. Refreshes desktop settings to apply changes immediately

## After Running the Tool

After running this tool:

1. Users will be able to change their desktop wallpaper through Windows Settings or Control Panel
2. The corporate wallpaper will remain until a user decides to change it
3. The corporate wallpaper will no longer be reapplied at login

## Troubleshooting

If the script fails to remove restrictions:

1. Ensure you're running it with administrative privileges
2. Check if any third-party software is enforcing wallpaper policies
3. Try rebooting the computer after running the script
4. Check for errors in the console output

## Reapplying Restrictions

If you need to reapply wallpaper restrictions, simply run the corporate wallpaper deployment tool again:

```
run_wallpaper.bat
```

## Version History

- **v1.0.0**: Initial release 