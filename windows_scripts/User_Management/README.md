# Windows User Management Scripts

## Overview
This directory contains scripts for creating user accounts on Windows systems with proper security configurations, including password expiration and optional administrator privileges. The implementation uses:

1. PowerShell Script (`create_user_windows.ps1`) - Core functionality
2. Batch Wrapper Script (`create_user_windows.bat`) - Execution wrapper that handles PowerShell execution policy

## Architecture

The solution follows a wrapper pattern:
- The batch file acts as a user-friendly wrapper that handles execution policies
- The batch file copies or downloads the PowerShell script to a temporary location
- The PowerShell script contains all the core user creation functionality
- Parameters are passed from the batch script to the PowerShell script

This approach ensures users can execute the script without manually adjusting PowerShell execution policies.

## Features

- Creates a local user account with a specified username
- Sets a default password (`scogo@007`) for all new user accounts
- Forces password change at first login for better security
- Adds full name information to the user account (optional)
- Can grant administrative privileges by adding user to the Administrators group (optional)
- Compatible with Windows 7 and above
- Includes robust error handling and input validation
- Logs all operations for security auditing
- **No need to manually set PowerShell execution policy**

## Requirements

- Windows 7 or later
- Administrator privileges
- PowerShell 3.0 or later (automatically handled by the batch wrapper)

## Usage

The scripts are designed to be user-friendly. Simply run the batch file with appropriate parameters:

```batch
create_user_windows.bat -u <username> [-f <full_name>] [-a]
```

### Parameters
- `-u, --username USERNAME` : Username for the new account (required)
- `-f, --fullname "FULL NAME"` : Full name for the user (optional)
- `-a, --admin` : Add user to Administrators group (optional)
- `-h, --help` : Display help information

### Examples

1. Create a basic user:
```
create_user_windows.bat -u jsmith
```

2. Create a user with full name:
```
create_user_windows.bat -u jsmith -f "John Smith"
```

3. Create an administrator user with full name:
```
create_user_windows.bat -u jsmith -f "John Smith" -a
```

## How It Works

1. The batch file checks for administrator privileges
2. It creates a temporary working directory
3. It copies the PowerShell script to the temporary location (or optionally downloads it from a repository)
4. It executes the PowerShell script with `-ExecutionPolicy Bypass` to avoid execution policy restrictions
5. It passes all parameters to the PowerShell script
6. It cleans up temporary files after execution

## Password Security
- All users are created with the same default password (`scogo@007`)
- The password is automatically expired, forcing users to change it at first login
- The user will need to enter the default password once, then immediately set a new secure password

## Logging
All operations are logged to `%ProgramData%\Nexus_RMM\Logs\user_management.log` with timestamps and operation results.

If the standard log location is not writable, the scripts will fall back to logging in the system temp directory.

## Troubleshooting
If you encounter issues:
1. Ensure you are running the script with administrator privileges
2. Check the log file for detailed error messages
3. Verify that the username follows the allowed format (alphanumeric and underscore only)
4. Ensure the user doesn't already exist on the system

## Security Considerations
- All users are created with the same default password (`scogo@007`)
- Users are required to change the password at first login
- Input validation prevents injection attacks
- Administrator privileges verification is enforced
- All sensitive operations are logged for audit purposes

## Centralized Deployment Option

For centralized management, you can configure the batch script to download the most recent version of the PowerShell script from a centralized repository. To enable this:

1. Uncomment and update the URL in the batch file:
```batch
set "PS_URL=https://raw.githubusercontent.com/YOUR_ORG/nexus_rmm_scripts/main/Windows_Scripts/User_Management/create_user_windows.ps1"
```

2. Uncomment the download section:
```batch
echo Downloading user management script...
powershell -Command "(New-Object Net.WebClient).DownloadFile('%PS_URL%', '%PS_SCRIPT%')"
```

This allows you to update the PowerShell script in the repository without needing to redeploy the batch file to endpoints. 