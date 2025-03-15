# Scogo.AI Nexus RMM Scripts

This repository contains a collection of scripts designed for remote management and monitoring (RMM) of Windows and Linux systems. These scripts automate common system administration tasks and can be deployed through Tactical RMM or other remote management platforms.

## Repository Structure

- **Linux_Scripts/** - Scripts for Linux systems
  - **Network/** - Network configuration scripts
  - **Browser/** - Browser extension management
  - **Wallpaper/** - Desktop wallpaper management
  - **App_Store/** - Application store access control

- **windows_scripts/** - Scripts for Windows systems
  - **Wallpaper/** - Desktop wallpaper management and customization
  - **temp_files_cleanup/** - System cleanup utilities

## Linux Scripts

### Network Management

- **change_dns_server.sh** - Updates DNS nameservers across various Linux distributions including Ubuntu, Debian, and RHEL-based systems
  - Works with NetworkManager, systemd-resolved, resolvconf, and legacy network configurations
  - Supports providing custom primary and secondary DNS nameservers
  - Creates backups of original configurations

### Browser Management

- **browser_extension_manager.sh** - Controls browser extensions on Linux systems
  - Blocks or allows specific browser extensions
  - Supports multiple browsers including Chrome, Firefox, and Chromium-based browsers
  - Configurable for different extension management policies

### Wallpaper Management

- Utilities for setting and managing desktop wallpapers on Linux systems
  - Enforces corporate wallpaper standards
  - Prevents end-users from changing wallpapers

### App Store Management

- Scripts to control access to application stores on Linux systems
  - Prevents unauthorized software installation
  - Configurable to allow specific apps or categories

## Windows Scripts

### Wallpaper Management

- **set_wallpaper.ps1** - Deploys and enforces corporate wallpapers on Windows workstations
  - Downloads wallpaper from specified URL or uses default
  - Sets wallpaper for all human users on the machine
  - Prevents users from changing the wallpaper
  - Works on Windows 7 and above
  - Handles domain-joined and workgroup computers

- **allow_changing_wallpaper.ps1** - Restores user ability to change desktop wallpaper
  - Reverses registry settings that prevent wallpaper changes
  - _Note: Currently experiencing issues that need to be fixed_

### Temporary Files Cleanup

- **temporary_files_cleanup.ps1** - Cleans up temporary files on Windows systems
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

- [ ] Script to update DNS on Windows machines
- [ ] Script to block browser extensions on Windows machines
- [ ] Script to block app store apps on Windows machines

## Known Issues

- [ ] The Windows allow changing wallpaper script is not working as expected

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
