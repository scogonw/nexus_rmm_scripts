# Linux DNS Nameserver Changer

This script allows system administrators to update DNS nameservers on Linux machines across various distributions including Ubuntu, Debian, and RHEL-based systems (CentOS, Fedora, Rocky Linux, AlmaLinux).

## Features

- Works across major Linux distributions (Debian/Ubuntu and RHEL family)
- Supports providing one or two DNS nameservers as command-line arguments
- Uses default DNS server (20.244.41.36) if no arguments are provided
- Requires root privileges for execution (prevents regular users from modifying DNS)
- Makes permanent DNS changes that persist across reboots
- Creates backups of existing configurations before making changes
- Supports multiple DNS configuration methods:
  - NetworkManager
  - systemd-resolved
  - resolvconf
  - Legacy network scripts (RHEL/CentOS)
  - Direct /etc/resolv.conf editing as a fallback

## Usage

```bash
sudo ./change_dns_server.sh [primary_dns] [secondary_dns]
```

### Examples

1. Use default DNS server (20.244.41.36):
   ```bash
   sudo ./change_dns_server.sh
   ```

2. Specify a single primary DNS server:
   ```bash
   sudo ./change_dns_server.sh 8.8.8.8
   ```

3. Specify both primary and secondary DNS servers:
   ```bash
   sudo ./change_dns_server.sh 8.8.8.8 8.8.4.4
   ```

## How It Works

1. The script first checks if it's running with root privileges
2. Detects the Linux distribution type (Debian/Ubuntu or RHEL family)
3. Processes the provided DNS servers or uses the default if none are provided
4. Based on the distribution type, it selects the appropriate method to update DNS:
   - For Debian/Ubuntu: Tries resolvconf → systemd-resolved → NetworkManager → direct edit
   - For RHEL family: Tries NetworkManager → network scripts → direct edit
5. For unsupported distributions, falls back to directly editing /etc/resolv.conf
6. Makes DNS changes permanent using distribution-specific methods

## Implementation Details

The script handles various DNS configuration methods used by different Linux distributions:

- **Debian/Ubuntu Systems:**
  - Checks for resolvconf, systemd-resolved, and NetworkManager
  - Updates the appropriate configuration files and restarts services

- **RHEL/CentOS Systems:**
  - Works with NetworkManager and network scripts (/etc/sysconfig/network-scripts/)
  - Updates interface configuration files and restarts networking services

- **Fallback Method:**
  - For unsupported distributions, directly edits /etc/resolv.conf
  - Makes the file immutable using chattr to prevent overwriting

## Security Considerations

- The script requires root privileges to modify system configuration files
- Regular users are prevented from executing the script to make DNS changes
- Backups of existing configurations are created before making changes

## Troubleshooting

If the script fails to update DNS settings:

1. Check if you have root privileges (sudo)
2. Verify that the script has executable permissions (`chmod +x change_dns_server.sh`)
3. Check the output for any error messages related to your specific distribution
4. Verify that your network configuration is standard for your distribution
5. Check if the backup files were created and restore them if needed

## Limitations

- May not work on highly customized Linux installations
- Specific enterprise distributions might use custom network configuration methods
- Some cloud-based virtual machines might override DNS settings
- Container environments may have restricted networking capabilities

## License

- MIT License 

## Contributors

- karan@scogo.in 