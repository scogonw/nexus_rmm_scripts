# Airplane Mode Toggle Script

This script package provides functionality to toggle the "Airplane Mode" state on Windows systems by enabling or disabling network adapters (Wi-Fi and Bluetooth). It's designed to work both interactively and via RMM deployments.

## Files Included

- `Airplanemode.bat` - Batch file launcher that can be run directly by users
- `Airplanemode.ps1` - PowerShell script that handles the actual functionality

## Features

- Toggle Airplane Mode on/off (disables/enables wireless adapters)
- Check current Airplane Mode status
- Works in both interactive and non-interactive modes
- Built-in error handling
- Administrator privileges enforcement
- Compatible with RMM deployment

## Requirements

- Windows operating system
- Administrator privileges
- PowerShell 3.0 or higher

## Usage

### Interactive Mode

1. Double-click the `Airplanemode.bat` file
2. The script will request administrator privileges if needed
3. Follow the on-screen prompts to toggle Airplane Mode

### Command Line Usage

You can also run the PowerShell script directly with parameters:

```powershell
# To toggle Airplane Mode ON (disable wireless adapters)
powershell -ExecutionPolicy Bypass -File "Airplanemode.ps1" on

# To toggle Airplane Mode OFF (enable wireless adapters)
powershell -ExecutionPolicy Bypass -File "Airplanemode.ps1" off

# To toggle between ON and OFF
powershell -ExecutionPolicy Bypass -File "Airplanemode.ps1" toggle

# To just check current status
powershell -ExecutionPolicy Bypass -File "Airplanemode.ps1" status
```

### RMM Deployment

For RMM deployment, use the PowerShell script with appropriate parameters. The script will:
- Return exit code 0 for successful operations
- Return exit code 1 for failures

Example RMM command:
```
powershell -ExecutionPolicy Bypass -File "C:\Path\To\Airplanemode.ps1" toggle
```

## How It Works

The script functions by:
1. Checking for administrator privileges
2. Finding wireless network adapters (Wi-Fi and Bluetooth)
3. Either enabling or disabling these adapters based on the requested action
4. Reporting the status change

Note that this script emulates Airplane Mode by controlling network adapters. On systems with hardware airplane mode switches or additional wireless hardware, those may need to be controlled separately.

## Troubleshooting

- **Script fails to run**: Ensure you have administrator privileges
- **Adapters not detected**: The script looks for adapters with "Wi-Fi", "Wireless" or "Bluetooth" in their names. If your adapters use different naming, you may need to modify the script.
- **Status reporting incorrect**: If the script reports status incorrectly, check if there are other wireless adapters in your system not being detected by the script.

## License

This script is provided "as is" without warranty of any kind. 