# Windows 11 Security Update Scripts

This repository contains two scripts designed to automate the installation of Windows 11 security updates:
1. `UpdateSecurity.ps1` - PowerShell script
2. `UpdateSecurity.bat` - Batch script

## Features

- Automated detection and installation of security updates
- Multiple update methods for enhanced reliability
- Comprehensive logging system
- Administrator privilege checking
- Automatic reboot handling
- User-friendly interface with status messages
- Error handling and reporting

## Prerequisites

- Windows 11 operating system
- Administrator privileges (recommended)
- PowerShell 5.1 or higher (for PowerShell script)
- Internet connection for downloading updates

## Installation

1. Download the scripts to your computer
2. Place them in a directory of your choice
3. Ensure you have administrator privileges

## Usage

### PowerShell Script (UpdateSecurity.ps1)

1. Right-click on `UpdateSecurity.ps1`
2. Select "Run with PowerShell as Administrator"
3. Follow the on-screen prompts

### Batch Script (UpdateSecurity.bat)

1. Right-click on `UpdateSecurity.bat`
2. Select "Run as Administrator"
3. Follow the on-screen prompts

## Script Details

### PowerShell Script Features
- Uses Windows Update API for reliable update detection
- Detailed logging with timestamps
- Progress tracking for each update
- Automatic EULA acceptance
- Smart reboot handling
- Error handling with detailed reporting

### Batch Script Features
- Multiple update methods for compatibility
- Built-in logging system
- Progress tracking
- Automatic reboot detection
- User-friendly prompts
- Fallback methods if primary method fails

## Logging

Both scripts create detailed logs in:
```
C:\Logs\Windows11_Security_Updates_[timestamp].log
```

Logs include:
- Script start and end times
- Update detection results
- Installation progress
- Error messages
- Reboot status

## Safety Features

- Administrator privilege checking
- Update verification before installation
- Safe reboot handling
- Error recovery
- Multiple update methods for reliability

## Common Issues and Solutions

1. **Script won't run**
   - Ensure you're running as Administrator
   - Check if PowerShell execution policy allows script running
   - Verify Windows 11 compatibility

2. **Updates not installing**
   - Check internet connection
   - Verify administrator privileges
   - Check Windows Update service status

3. **Reboot issues**
   - Save all work before running
   - Choose manual reboot if needed
   - Check log file for specific errors

## Best Practices

1. Always run as Administrator
2. Save all work before running
3. Check logs after completion
4. Restart computer if prompted
5. Keep scripts updated

## Support

For issues or questions:
1. Check the log files
2. Verify administrator privileges
3. Ensure Windows 11 compatibility
4. Check internet connectivity

## Disclaimer

These scripts are provided as-is without warranty. Always:
- Back up important data before running
- Review the script contents
- Run with administrator privileges
- Monitor the process

## License

This project is open source and available under the MIT License.

## Contributing

Feel free to submit issues and enhancement requests! 