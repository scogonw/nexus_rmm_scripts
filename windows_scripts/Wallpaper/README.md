# Corporate Wallpaper Deployment Script

This set of scripts allows you to automatically deploy and enforce a corporate wallpaper across all Windows workstations in your organization. The scripts are designed to be used with Tactical RMM or any other remote management solution.

## Features

- Downloads wallpaper from a specified URL or uses a default corporate wallpaper
- Sets the wallpaper for all human users on the machine (excludes system accounts)
- Prevents users from changing the wallpaper through multiple registry enforcement methods
- Works on Windows 7 and above with special handling for different Windows versions
- Provides detailed status information during execution
- Runs with administrative privileges automatically
- Creates a startup script to ensure wallpaper is set at each login
- Handles both domain-joined and workgroup computers
- Special handling for currently logged-in users
- Validates downloaded image files for security
- Robust error handling and recovery mechanisms

## Files

- `run_wallpaper.bat` - The main batch script that downloads and runs the PowerShell script
- `set_wallpaper.ps1` - PowerShell script that handles downloading and setting the wallpaper

## Usage

### Basic Usage

1. Download the `run_wallpaper.bat` file to the target machine
2. Run the batch file with administrative privileges:

```
run_wallpaper.bat
```

This will use the default wallpaper URL.

### Custom Wallpaper

To use a custom wallpaper, provide the URL as an argument:

```
run_wallpaper.bat https://example.com/path/to/wallpaper.jpg
```

### Custom Wallpaper with Style

To specify both a custom wallpaper and style:

```
run_wallpaper.bat https://example.com/path/to/wallpaper.jpg Fit
```

Available styles are:
- Fill - Resizes the image to fill the screen while maintaining aspect ratio (may crop)
- Fit - Resizes the image to fit the screen while maintaining aspect ratio (may have black bars)
- Stretch - Stretches the image to fill the screen (may distort)
- Tile - Tiles the image across the screen
- Center - Centers the image on screen without resizing
- Span - Spans the image across multiple monitors (default)

### Tactical RMM Integration

1. Upload these scripts to your Tactical RMM script repository
2. Create a new script in Tactical RMM that runs `run_wallpaper.bat`
3. Schedule the script to run on all workstations or add it to your onboarding process

For Tactical RMM deployment, you can use the following command:

```
cmd.exe /c "%ProgramData%\Tactical RMM\temp\run_wallpaper.bat" "https://your-image-url.jpg" "Span"
```

## Technical Details

### Wallpaper Enforcement

The script uses multiple registry settings to prevent users from changing the wallpaper:

- `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop\NoChangingWallPaper`
- `HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization\PreventChangingWallPaper`
- `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\NoDispBackgroundPage`
- `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer\NoActiveDesktopChanges`
- Individual user registry settings are also configured

The script also applies these settings to the Default User profile, ensuring new users who log in will also have the wallpaper locked.

### User Profile Detection

The script identifies human users by examining the `ProfileList` registry key and excluding common system accounts:

- systemprofile
- LocalService
- NetworkService
- defaultuser0
- Administrator
- Default
- Public
- All Users
- DefaultAccount
- WDAGUtilityAccount
- Guest

### Fallback Methods

The script includes multiple methods to set the wallpaper to ensure compatibility with different Windows versions:

1. Windows API via `SystemParametersInfo` - Primary method for immediate effect
2. Registry modification for each user profile - For persistence across sessions
3. Direct manipulation for currently logged-in users (using PsExec if available)
4. Startup script to ensure settings persist after reboot
5. Scheduled task for Windows 7 compatibility

### Error Handling

The script includes robust error handling:

- URL validation and fallback to default URL if invalid
- Image file validation (checks file headers)
- Registry hive handling with proper locking/unlocking
- Multiple fallback methods for script retrieval
- Detailed logging with status messages
- Exit code reporting for monitoring systems

## Compatibility

The script is compatible with:

- Windows 7, 8, 8.1, 10, and 11
- Both 32-bit and 64-bit versions
- Domain-joined and workgroup computers
- Systems with multiple users
- Systems with or without internet access (if script is available locally)

## Customization

### Adding Additional Excluded Users

To exclude additional user profiles from receiving the wallpaper, modify the `$excludedUsers` array in the PowerShell script:

```powershell
$excludedUsers = @(
    "systemprofile", "LocalService", "NetworkService", 
    "defaultuser0", "Administrator", "Default", 
    "Public", "All Users", "DefaultAccount", 
    "WDAGUtilityAccount", "Guest", "YourCustomExcludedUser"
)
```

### Changing Default Wallpaper URL

To change the default wallpaper URL, modify this line in both scripts:

```powershell
# In set_wallpaper.ps1
param([string]$ImageUrl = "https://your-default-url.jpg", [string]$Style = "Span")
```

```batch
:: In run_wallpaper.bat
set "IMAGE_URL=https://your-default-url.jpg"
```

### Customizing Registry Enforcement

If you need to adjust how wallpaper changes are blocked, modify the `Block-WallpaperChanges` function in the PowerShell script.

## Troubleshooting

### Script Fails to Run

- Ensure you have administrative privileges
- Check your internet connection
- Verify the PowerShell execution policy allows script execution
- Try running with the local script by placing `set_wallpaper.ps1` in the same directory

### Wallpaper Not Applied

- Check that the URL points to a valid image file
- Ensure the image format is supported (JPG, PNG, BMP, or GIF)
- Verify the downloaded image in `C:\ProgramData\Scogo\Wallpaper`
- Check for errors in the script output
- For Windows 7, check if the scheduled task was created successfully

### Registry Errors

If you see registry-related errors:
- Ensure no registry editing tools are running
- Check if any users have open registry editors
- Verify the script is running with administrative privileges
- In extreme cases, a system restart may be needed to unlock registry hives

## Security Considerations

- The script requires administrative privileges to modify registry settings
- Scripts are downloaded from a trusted repository with HTTPS
- TLS 1.2 is used for secure downloads
- Downloaded images are validated before being applied
- The script runs with minimum required privileges
- No sensitive information is collected or transmitted

## Deployment Options

### Manual Deployment

1. Copy both scripts to a USB drive or network share
2. Run `run_wallpaper.bat` on each workstation

### Group Policy Deployment

Create a Group Policy Object that:
1. Copies the scripts to `%ProgramData%\Scogo\Wallpaper`
2. Creates a scheduled task to run `run_wallpaper.bat` at startup or user logon

### Remote Management Deployment

For RMM tools, create a script that:
1. Downloads `run_wallpaper.bat` from your repository
2. Executes it with the appropriate parameters

## License

- MIT License

## Contributors

- karan@scogo.in 

## Version History

- v1.0.0: Initial release
- v1.1.0: Added improved error handling, domain support, and Windows version detection