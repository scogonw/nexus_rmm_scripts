# App Store Manager

A bash script for controlling non-root user access to software installation mechanisms on Linux systems.

## Overview

The `app_store_manager.sh` script allows system administrators to control which users can install software on Linux systems. It supports multiple package managers and app stores, including:

- APT (Debian/Ubuntu)
- DNF (Fedora/RHEL)
- YUM (CentOS/RHEL)
- Flatpak
- Snap
- GNOME Software
- Ubuntu Software Center
- KDE Discover
- AppImage

## Features

- **Root-only execution**: Only root users can run this script
- **Auto-detection**: Automatically detects package managers and app stores installed on the system
- **Flexible control**: Can be applied to all non-root users or specific users
- **Toggle permissions**: Easily allow or deny software installation permissions
- **Status checking**: View current permission status for all users
- **Preserves browsing**: Users can still browse available software, but cannot install without permission

## Requirements

- Root access to the system
- Linux distribution with one or more of the supported package managers/app stores
- Bash shell
- Standard Linux utilities (awk, chmod, etc.)

## Installation

1. Copy the script to a location accessible by the root user
2. Make the script executable: `chmod +x app_store_manager.sh`
3. Run the script as root

## Usage

```
sudo ./app_store_manager.sh [OPTION] [USERNAME]
```

### Options

- `--allow`: Allow app store access for specified user or all non-root users
- `--deny`: Deny app store access for specified user or all non-root users (default)
- `--status`: Show current access status for all users
- `--help`: Display usage information

### Arguments

- `USERNAME`: Optional: Specify a user to modify. If omitted, applies to all non-root users.

## Examples

### Deny installation access for all users (default)

```
sudo ./app_store_manager.sh
```

### Allow a specific user to install software

```
sudo ./app_store_manager.sh --allow username
```

### Deny a specific user from installing software

```
sudo ./app_store_manager.sh --deny username
```

### Check current status

```
sudo ./app_store_manager.sh --status
```

## How It Works

The script uses different methods to restrict software installation based on the package manager:

- **APT/DNF/YUM**: Uses sudoers rules to prevent execution of package management commands
- **Flatpak**: Controls access via group permissions
- **Snap**: Restricts access to the snap binary and socket
- **GNOME Software/Ubuntu Software Center**: Uses dconf settings to disable installation capabilities
- **KDE Discover**: Uses PolicyKit rules to require admin authentication
- **AppImage**: Uses AppArmor profiles to prevent execution of AppImage files

Users can still browse and view software in graphical app stores, but will be unable to complete installation without admin privileges.

## Limitations

- Some restrictions might not work on all Linux distributions due to differences in system configuration
- The script needs to be run as root
- AppArmor-based restrictions for AppImage only work on systems with AppArmor enabled

## Troubleshooting

### Permission denied errors

Make sure you are running the script as root:

```
sudo ./app_store_manager.sh [options]
```

### Command not found errors

Make sure the script is executable:

```
chmod +x app_store_manager.sh
```

### No effect on some package managers

Some distributions may use different paths or methods for package management. Check the script output for any warnings.

## License

- MIT License 

## Contributors

- karan@scogo.in 

## Version History

- v1.0.0: Initial release
