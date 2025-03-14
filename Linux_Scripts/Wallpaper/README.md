# Linux Wallpaper Script Documentation

## Overview

The `set_wallpaper.sh` script is designed to set and lock a custom wallpaper on Linux systems across all user accounts. This script supports various desktop environments and distributions, making it a versatile solution for system administrators who need to enforce a specific desktop background across an organization.

## Features

- Downloads and sets a custom wallpaper from a URL
- Sets the wallpaper for all human users (UID ≥ 1000)
- Locks the wallpaper to prevent users from changing it
- Works across multiple desktop environments (GNOME, KDE, XFCE, etc.)
- Compatible with major Linux distributions (Debian/Ubuntu, RHEL/CentOS, Fedora, Arch, openSUSE)
- Handles both X11 and Wayland display servers
- Supports multi-monitor setups
- Automatically installs required dependencies
- Persists settings across user logins
- Provides informative status messages during execution

## Requirements

- Root privileges (sudo/su access)
- Internet connection (to download the wallpaper)
- Bash shell
- One of the supported desktop environments

## Usage

### Basic Usage

```bash
sudo ./set_wallpaper.sh
```

This will download the default wallpaper and set it for all users.

### Custom Wallpaper URL

```bash
sudo ./set_wallpaper.sh "https://example.com/path/to/custom_wallpaper.jpg"
```

This will use the specified URL to download and set the custom wallpaper.

## How It Works

The script follows this general workflow:

1. Checks for root privileges
2. Processes arguments (wallpaper URL)
3. Installs required dependencies
4. Downloads the wallpaper
5. Detects and processes each human user
6. For each user, detects their desktop environment
7. Applies desktop-specific settings to set and lock the wallpaper
8. Creates autostart entries for persistence

## Detailed Component Explanation

### 1. Package Management

The script includes a flexible package management system that works across different Linux distributions:

```bash
install_package_if_missing() {
    local package_name=$1
    # Distribution-specific package management...
}
```

This function detects the system's package manager (apt, yum, dnf, pacman, or zypper) and installs required packages if they're missing.

### 2. Directory Management

```bash
create_directory_with_owner() {
    local dir_path=$1
    local owner=$2
    # Directory creation with proper permissions...
}
```

This utility function creates directories with appropriate ownership and permissions.

### 3. Wallpaper Download

The script handles downloading the wallpaper with appropriate error handling and retry logic:

```bash
if ! wget -q --timeout=30 --tries=3 -O "$WALLPAPER_PATH" "$WALLPAPER_URL"; then
    # Error handling and retry logic...
fi
```

### 4. Session Detection

```bash
is_wayland() {
    # Wayland session detection logic...
}

get_dbus_address() {
    # DBUS address detection for user sessions...
}
```

These functions detect if users are running Wayland sessions and locate the correct DBUS address for communicating with the user's session.

### 5. Desktop Environment Detection and Configuration

The script contains specialized sections for each supported desktop environment:

- **GNOME/Cinnamon**: Uses `gsettings` and `dconf` to set and lock wallpaper
- **XFCE**: Uses XML configuration and `xfconf-query`
- **KDE Plasma**: Uses `plasma-apply-wallpaperimage` and `kwriteconfig5`
- **MATE**: Uses `gsettings` and `dconf`
- **LXDE/LXQt**: Configures `pcmanfm` settings
- **Budgie**: Uses GNOME settings backend
- **Generic X11**: Fallback using `feh` or `nitrogen`

### 6. Autostart Configuration

```bash
create_autostart_file() {
    # Creates desktop entry for autostart...
}
```

This function creates desktop entries that reapply the wallpaper settings on login, ensuring persistence.

## Supported Desktop Environments

- GNOME (Ubuntu, Fedora, Pop!_OS)
- Cinnamon (Linux Mint)
- XFCE (Xubuntu, Manjaro XFCE)
- KDE Plasma (Kubuntu, KDE Neon, openSUSE KDE)
- MATE (Ubuntu MATE)
- LXDE
- LXQt
- Budgie
- Generic X11 (with fallback support)

## Supported Linux Distributions

- Debian-based: Debian, Ubuntu, Linux Mint, Pop!_OS
- Red Hat-based: RHEL, CentOS, Fedora
- Arch-based: Arch Linux, Manjaro
- SUSE-based: openSUSE, SUSE Linux Enterprise
- Others with compatible package managers

## Directory Structure

Important paths used by the script:

- `/usr/share/backgrounds/custom_wallpaper.jpg`: Default location for the wallpaper
- `/etc/dconf/profile/user`: dconf profile for GNOME-based environments
- `/etc/dconf/db/local.d/`: dconf database configuration
- `~/.config/autostart/`: User-specific autostart entries
- `~/.local/bin/`: User-specific scripts for fallback methods

## Reverting Changes

If you need to allow users to change their wallpapers again after running this script, use the following commands based on the desktop environment (must be run as root):

### GNOME/Ubuntu/Budgie
```bash
# Quick method - just removes the lock
rm -f /etc/dconf/db/local.d/locks/background && dconf update

# Complete method - removes both configuration and lock
rm -f /etc/dconf/db/local.d/01-background /etc/dconf/db/local.d/locks/background && dconf update
```

### Cinnamon (Linux Mint)
```bash
rm -f /etc/dconf/db/local.d/01-cinnamon-background /etc/dconf/db/local.d/locks/cinnamon-background && dconf update
```

### MATE
```bash
rm -f /etc/dconf/db/local.d/01-mate-background /etc/dconf/db/local.d/locks/mate-background && dconf update
```

### XFCE
```bash
# Find all users and restore file permissions
for userdir in /home/*; do
  username=$(basename "$userdir")
  config_file="$userdir/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml"
  if [ -f "$config_file" ]; then
    chmod 644 "$config_file"
    chown "$username":"$username" "$config_file"
  fi
done
```

### KDE Plasma
```bash
# Find all users and restore file permissions
for userdir in /home/*; do
  username=$(basename "$userdir")
  config_file="$userdir/.config/plasma-org.kde.plasma.desktop-appletsrc"
  if [ -f "$config_file" ]; then
    chmod 644 "$config_file"
    chown "$username":"$username" "$config_file"
    # Remove lock directory
    rm -rf "$userdir/.config/plasma-org.kde.plasma.desktop-appletsrc.lock"
  fi
done
```

### LXDE/LXQt
```bash
# For LXDE
for userdir in /home/*; do
  username=$(basename "$userdir")
  config_file="$userdir/.config/pcmanfm/LXDE/desktop-items-0.conf"
  if [ -f "$config_file" ]; then
    chmod 644 "$config_file"
    chown "$username":"$username" "$config_file"
  fi
done

# For LXQt
for userdir in /home/*; do
  username=$(basename "$userdir")
  config_file="$userdir/.config/pcmanfm-qt/lxqt/settings.conf"
  if [ -f "$config_file" ]; then
    chmod 644 "$config_file"
    chown "$username":"$username" "$config_file"
  fi
done
```

### Generic/All Users (Complete Cleanup)
```bash
# Complete cleanup script for all methods
# Must be run as root
#!/bin/bash

# Remove dconf settings and locks
rm -f /etc/dconf/db/local.d/01-background
rm -f /etc/dconf/db/local.d/01-cinnamon-background
rm -f /etc/dconf/db/local.d/01-mate-background
rm -f /etc/dconf/db/local.d/01-budgie-background
rm -f /etc/dconf/db/local.d/locks/background
rm -f /etc/dconf/db/local.d/locks/cinnamon-background
rm -f /etc/dconf/db/local.d/locks/mate-background
rm -f /etc/dconf/db/local.d/locks/budgie-background
dconf update

# Remove autostart entries and restore file permissions for all users
for userdir in /home/*; do
  username=$(basename "$userdir")
  
  # Remove autostart entry
  rm -f "$userdir/.config/autostart/set-wallpaper.desktop"
  
  # XFCE permissions
  config_file="$userdir/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml"
  if [ -f "$config_file" ]; then
    chmod 644 "$config_file"
    chown "$username":"$username" "$config_file"
  fi
  
  # KDE permissions
  config_file="$userdir/.config/plasma-org.kde.plasma.desktop-appletsrc"
  if [ -f "$config_file" ]; then
    chmod 644 "$config_file"
    chown "$username":"$username" "$config_file"
    rm -rf "$userdir/.config/plasma-org.kde.plasma.desktop-appletsrc.lock"
  fi
  
  # LXDE permissions
  config_file="$userdir/.config/pcmanfm/LXDE/desktop-items-0.conf"
  if [ -f "$config_file" ]; then
    chmod 644 "$config_file"
    chown "$username":"$username" "$config_file"
  fi
  
  # LXQt permissions
  config_file="$userdir/.config/pcmanfm-qt/lxqt/settings.conf"
  if [ -f "$config_file" ]; then
    chmod 644 "$config_file"
    chown "$username":"$username" "$config_file"
  fi
done

echo "Wallpaper locks have been removed for all users and all desktop environments."
```

## Extending the Script

### Supporting New Desktop Environments

To add support for a new desktop environment:

1. Add detection logic in the `set_wallpaper_and_lock` function
2. Install required packages in the `check_and_install_de_packages` function
3. Implement the appropriate wallpaper setting method
4. Implement a locking mechanism

Example template:

```bash
# New desktop environment
elif command -v new-desktop-session &> /dev/null; then
    echo "Detected New Desktop environment for user: $username"
    
    # Install any required packages
    install_package_if_missing new-desktop-pkg
    
    # Create configuration directories
    create_directory_with_owner "$user_home/.config/new-desktop" "$username"
    
    # Set wallpaper for current session (if user is logged in)
    if [ -d "/run/user/$uid" ]; then
        sudo -u "$username" DISPLAY=:0 new-desktop-command --set-wallpaper "$WALLPAPER_PATH" || true
    }
    
    # Lock settings
    # (Desktop-specific locking mechanism)
    
    # Configure for persistence across logins
    # (Desktop-specific persistence method)
}
```

### Supporting New Linux Distributions

To add support for a new Linux distribution:

1. Add the package manager detection in the `install_package_if_missing` function:

```bash
elif command -v new-pkg-manager &> /dev/null; then
    if ! new-pkg-check "$package_name" &> /dev/null; then
        echo "Installing missing package: $package_name"
        new-pkg-manager install "$package_name"
    fi
```

### Modifying Autostart Behavior

The autostart behavior can be modified by changing the `create_autostart_file` function. This allows you to customize what happens when a user logs in.

## Troubleshooting

### Common Issues

1. **Wallpaper not downloading**
   - Check internet connectivity
   - Verify URL accessibility
   - Check disk space in `/usr/share/backgrounds/`

2. **Wallpaper not applying**
   - Verify the script is run with root privileges
   - Check for error messages during execution
   - Verify desktop environment detection 

3. **Wallpaper not locked**
   - Some desktop environments have limited locking capabilities
   - Check specific DE documentation for alternative locking methods

### Debugging

For more verbose output, you can modify the script to enable debugging:

```bash
# Add at the beginning of the script
set -x  # Enable debug mode
```

## Limitations

- **Tiling Window Managers**: Window managers like i3, dwm, and awesome use non-standard wallpaper mechanisms and may require custom configurations.
- **Remote/Headless Systems**: Systems without a graphical environment may not apply wallpaper settings correctly.
- **Exotic/Custom Desktops**: Very specialized or heavily customized desktop environments may require manual adjustments.
- **User Experience**: Some users may find locked backgrounds restrictive and might attempt workarounds.

## Security Considerations

- The script runs with root privileges, so ensure it comes from a trusted source
- Be cautious about the wallpaper URL source
- Consider restricting script modifications to privileged users

## License

- MIT License 

## Contributors

- karan@scogo.in 

## Version History

- v1.0.0: Initial release