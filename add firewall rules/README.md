# Add Firewall Rules

This folder contains scripts to automate the process of adding Windows Firewall rules for all executables in a specified directory. The scripts require administrator privileges to run.

## Files

- **addfirewall.bat**: Batch file to launch the PowerShell script with administrator privileges.
- **addfirewall.ps1**: PowerShell script that adds firewall rules for all `.exe` files in a given directory.

## Prerequisites
- Windows operating system
- Administrator privileges
- PowerShell

## Usage

1. **Double-click `addfirewall.bat`**
   - The batch file checks for administrator privileges. If not already running as admin, it will prompt for elevation.
   - It then runs the PowerShell script.

2. **Follow the prompts**
   - You will be asked to enter the path to the folder containing the executables (`.exe` files) for which you want to add firewall rules.
   - The script will add rules for each executable found in the specified directory.

3. **Optional Parameters (Advanced)**
   - You can run the PowerShell script directly with parameters:
     ```powershell
     powershell -ExecutionPolicy Bypass -File addfirewall.ps1 -PathToExecutables "C:\Path\To\Folder" -Direction Outbound -FirewallProfile Public
     ```
   - **PathToExecutables**: Path to the folder containing `.exe` files.
   - **Direction**: 'Inbound' (default) or 'Outbound'.
   - **FirewallProfile**: 'Domain', 'Private', or 'Public'. Can specify multiple (e.g., `-FirewallProfile Domain,Private`).

## Example
```
powershell -ExecutionPolicy Bypass -File addfirewall.ps1 -PathToExecutables "C:\MyApp\bin" -Direction Outbound -FirewallProfile Private
```

## Notes
- The script will display a warning if no executables are found in the specified directory.
- All created firewall rules will allow traffic for the specified executables.
- Author: Markus Fleschutz | License: CC0 