# Linux User Management Script

## Overview
This script provides functionality to create user accounts on Linux systems with proper security configurations, including password expiration and optional administrator privileges.

## Features
- Creates a local user account with a specified username
- Sets a default password (`scogo@007`) for all new user accounts
- Sets up proper home directory with Bash as default shell
- Forces password change at first login for better security
- Adds full name information to the user account (optional)
- Can grant administrative privileges by adding user to sudo/wheel group (optional)
- Compatible with multiple Linux distributions
- Includes robust error handling and input validation
- Logs all operations for security auditing

## Requirements
- Root or sudo privileges
- Bash shell
- Standard Linux user management utilities (useradd, passwd, usermod)
- Supported Linux distributions:
  - Ubuntu/Debian-based distributions
  - Red Hat/Fedora-based distributions (RHEL, CentOS, Rocky Linux, etc.)
  - Other distributions with standard user management utilities

## Usage

### Basic Command Syntax
```bash
sudo ./create_user_linux.sh [OPTIONS]
```

### Command Line Options
- `-u, --username USERNAME` : Username for the new account (required)
- `-f, --fullname "FULL NAME"` : Full name for the user (optional)
- `-a, --admin` : Add user to sudo/wheel group (optional)
- `-h, --help` : Display help information

### Examples

1. Create a basic user:
```bash
sudo ./create_user_linux.sh -u jsmith
```

2. Create a user with full name:
```bash
sudo ./create_user_linux.sh -u jsmith -f "John Smith"
```

3. Create an administrator user with full name:
```bash
sudo ./create_user_linux.sh -u jsmith -f "John Smith" -a
```

## Password Security
- The script sets a default password of `scogo@007` for all new user accounts
- Password is automatically expired, forcing user to change it at first login
- The user will need to enter the default password once, then immediately set a new secure password

## Distribution Compatibility
The script automatically detects the Linux distribution and assigns the appropriate administrative group:
- Ubuntu/Debian: `sudo` group
- RHEL/CentOS/Fedora: `wheel` group
- Others: Attempts to detect the appropriate group, defaults to `sudo`

## Logging
All operations are logged to `/var/log/nexus_rmm/user_management.log` with timestamps and operation results. The log includes:
- Script invocation details
- User creation events
- Errors or warnings that occur during execution
- Success confirmations

## Troubleshooting
If you encounter issues:
1. Ensure you are running the script with sudo or as root
2. Check the log file for detailed error messages
3. Verify that the username follows the allowed format (alphanumeric and underscore only)
4. Ensure the user doesn't already exist on the system

## Security Considerations
- All users are created with the same default password (`scogo@007`)
- Users are required to change the password at first login
- The script validates input to prevent command injection attacks
- All sensitive operations are logged for audit purposes 