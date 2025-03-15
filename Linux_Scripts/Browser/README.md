# Browser Extension Manager for Linux

This script provides administrators with a tool to manage browser extensions for non-admin users on Linux systems. It allows restricting extension installation and creating whitelists of approved extensions.

## Features

- Root-only execution for security
- Automatic browser detection (Chrome, Chromium, Firefox, Edge, Opera)
- Extension installation control (enable/disable)
- Whitelist support for approved extensions
- Cross-distribution compatibility (Ubuntu, Debian, RHEL, etc.)
- List currently installed extensions

## Requirements

- Bash shell
- Root privileges

## Installation

1. Download the script to your preferred location:
   ```bash
   sudo cp browser_extension_manager.sh /usr/local/bin/
   sudo chmod +x /usr/local/bin/browser_extension_manager.sh
   ```

## Usage

```bash
sudo ./browser_extension_manager.sh [OPTIONS]
```

### Options

- `-h, --help`: Display help information
- `-w, --whitelist EXTENSIONS`: Comma-separated list of whitelisted extension IDs
- `-e, --enable`: Enable extension installation (default: disabled)
- `-d, --disable`: Disable extension installation
- `-l, --list`: List currently installed browser extensions

### Examples

#### Disable all extension installations

```bash
sudo ./browser_extension_manager.sh --disable
```

#### Allow only specific extensions

```bash
sudo ./browser_extension_manager.sh --whitelist 'extension_id_1,extension_id_2,extension_id_3'
```

#### Enable extension installation

```bash
sudo ./browser_extension_manager.sh --enable
```

#### List all installed extensions

```bash
sudo ./browser_extension_manager.sh --list
```

## Extension IDs vs. Extension Names

The script uses **extension IDs** rather than names because:

1. Extension IDs are unique identifiers that remain consistent
2. Many browsers internally use extension IDs for management
3. The same extension can have different names in different languages
4. Extension names can change with updates

### Finding Extension IDs

#### For Chrome/Chromium/Edge
1. Go to `chrome://extensions/` (or equivalent)
2. Enable "Developer mode"
3. The ID will be displayed under each extension

#### For Firefox
1. Go to `about:debugging#/runtime/this-firefox`
2. Click "Inspect" on an extension
3. The ID is in the URL or in the extension details

#### For Opera
1. Go to `opera://extensions/`
2. Enable "Developer mode"
3. The ID will be displayed under each extension

## How It Works

The script works by creating browser policies that control extension installation. These policies are stored in system-wide configuration directories that apply to all users:

- Chrome: `/etc/opt/chrome/policies/managed/extension_settings.json`
- Chromium: `/etc/chromium/policies/managed/extension_settings.json`
- Firefox: `/usr/lib/firefox/distribution/policies.json`
- Edge: `/etc/opt/edge/policies/managed/extension_settings.json`
- Opera: `/etc/opt/opera/policies/managed/extension_settings.json`

## Compatibility

This script works on most major Linux distributions, including:
- Ubuntu
- Debian
- RHEL/CentOS/Fedora
- openSUSE
- Arch Linux
- Linux Mint

## Troubleshooting

### The policy isn't applying

- Restart the browser(s) after applying policies
- Verify file permissions (should be 644)
- Check that the policy directories exist and are correctly configured
- Some browsers may need to be completely closed and reopened

### Extension whitelist not working

- Verify the extension IDs are correct
- Check the JSON syntax in the policy files
- Restart the browser
- Some browsers may cache policies; try clearing browser data

## License

- MIT License 

## Contributors

- karan@scogo.in 