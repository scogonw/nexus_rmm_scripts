# Scogo.AI Nexus RMM Scripts

This repository contains a collection of scripts designed for remote management and monitoring (RMM) of Windows and Linux systems. These scripts automate common system administration tasks and can be deployed through Tactical RMM or other remote management platforms.

## Repository Structure

- **Linux_Scripts/** - Scripts for Linux systems
  - **Applications_Management/** - Control application installation and app store access
  - **Browser/** - Browser extension management
  - **Customizations/** - UI and experience customizations
    - **Wallpaper/** - Desktop wallpaper management
  - **Network_Management/** - Network configuration scripts
  - **User_Management/** - User account creation and management
  - **Misc/** - Miscellaneous utilities

- **windows_scripts/** - Scripts for Windows systems
  - **Customizations/** - UI and experience customizations
    - **Wallpaper/** - Desktop wallpaper management
  - **temp_files_cleanup/** - System cleanup utilities
  - **User_Management/** - User account creation and management
  - **Misc/** - Miscellaneous utilities

## Linux Scripts

### Applications Management

- **app_store_manager.sh** - Controls access to application stores on Linux systems
  - Enables or disables app stores across major Linux distributions
  - Supports Ubuntu Software Center, GNOME Software, KDE Discover, and more
  - Configurable to allow specific apps or categories
  - Prevents unauthorized software installation

### Browser Management

- **browser_extension_manager.sh** - Controls browser extensions on Linux systems
  - Blocks or allows specific browser extensions
  - Supports multiple browsers including Chrome, Firefox, and Chromium-based browsers
  - Configurable for different extension management policies

### Network Management

- **change_dns_server.sh** - Updates DNS nameservers across various Linux distributions
  - Works with NetworkManager, systemd-resolved, resolvconf, and legacy network configurations
  - Supports providing custom primary and secondary DNS nameservers
  - Creates backups of original configurations

### User Management

- **create_user_linux.sh** - Creates user accounts on Linux systems
  - Sets up accounts with proper security configurations
  - Forces password change at first login
  - Optional administrator privileges
  - Compatible with multiple Linux distributions

### Wallpaper Management

- **set_enforce_wallpaper.sh** - Deploys and enforces corporate wallpapers on Linux workstations
  - Works across multiple desktop environments (GNOME, KDE, Xfce, MATE, etc.)
  - Downloads wallpaper from specified URL or uses local file
  - Prevents users from changing the wallpaper

- **allow_changing_wallpaper.sh** - Restores user ability to change desktop wallpaper
  - Reverses settings that prevent wallpaper changes
  - Compatible with major Linux desktop environments

## Windows Scripts

### User Management

- **create_user_windows.ps1** and **create_user_windows.bat** - Creates user accounts on Windows systems
  - PowerShell implementation with batch wrapper to handle execution policies
  - Sets up accounts with proper security configurations
  - Forces password change at first login
  - Optional administrator privileges
  - Compatible with Windows 7 and later

### Wallpaper Management

- **set_wallpaper.ps1** and **run_wallpaper.bat** - Deploys and enforces corporate wallpapers on Windows workstations
  - Downloads wallpaper from specified URL or uses default
  - Sets wallpaper for all human users on the machine
  - Prevents users from changing the wallpaper
  - Works on Windows 7 and above
  - Handles domain-joined and workgroup computers

- **allow_changing_wallpaper.ps1** and **run_allow_changing_wallpaper.bat** - Restores user ability to change desktop wallpaper
  - Reverses registry settings that prevent wallpaper changes

### Temporary Files Cleanup

- **temporary_files_cleanup.ps1** and **run_cleanup.bat** - Cleans up temporary files on Windows systems
  - Removes unnecessary files to free up disk space
  - Targets Windows temporary directories, browser caches, and other common locations

## Usage

Each script directory contains its own detailed README file with:
- Specific usage instructions
- Command-line arguments
- Requirements
- Troubleshooting tips

For detailed documentation on a specific script, please navigate to its directory and read the associated README file.

## To-do List

- [ ] Script to block browser extensions on Windows machines

## Known Issues

- [ ] The Windows allow changing wallpaper script may encounter issues in some environments

## Contributing

If you'd like to contribute to this repository, please follow these steps:
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

All scripts in this repository are provided under the MIT License unless specified otherwise.

## Contact

For questions, issues, or contributions, please contact: karan@scogo.in
