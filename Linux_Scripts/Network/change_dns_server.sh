#!/bin/bash

# change_dns_server.sh - Script to change/update DNS nameservers on Linux machines
# This script works across Ubuntu, Debian, and RHEL distributions
# 
# Usage: ./change_dns_server.sh [primary_dns] [secondary_dns]
# Example: ./change_dns_server.sh 8.8.8.8 8.8.4.4

# Default DNS server if none provided
DEFAULT_DNS="20.244.41.36"

# Function to display usage information
usage() {
    echo "Usage: $0 [primary_dns] [secondary_dns]"
    echo "If no DNS servers are provided, $DEFAULT_DNS will be used."
    echo "If only one DNS server is provided, it will be used as the primary DNS."
    exit 1
}

# Function to check if script is running as root
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "Error: This script must be run as root (sudo)."
        exit 1
    fi
}

# Function to detect the Linux distribution
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
        DISTRO_FAMILY=$(echo $ID_LIKE | tr ' ' '\n' | grep -E 'debian|rhel' | head -1)
        
        if [ -z "$DISTRO_FAMILY" ]; then
            if echo "$DISTRO" | grep -qE 'debian|ubuntu'; then
                DISTRO_FAMILY="debian"
            elif echo "$DISTRO" | grep -qE 'centos|rhel|fedora|rocky|alma'; then
                DISTRO_FAMILY="rhel"
            else
                DISTRO_FAMILY="unknown"
            fi
        fi
    else
        DISTRO="unknown"
        DISTRO_FAMILY="unknown"
    fi
    
    echo "Detected Linux distribution: $DISTRO (Family: $DISTRO_FAMILY)"
}

# Function to update DNS on Debian/Ubuntu systems
update_dns_debian() {
    local primary_dns=$1
    local secondary_dns=$2
    
    # Check if resolv.conf is managed by resolvconf
    if [ -f /etc/resolvconf/resolv.conf.d/base ]; then
        # Backup existing configuration
        if [ -f /etc/resolvconf/resolv.conf.d/base ]; then
            cp /etc/resolvconf/resolv.conf.d/base /etc/resolvconf/resolv.conf.d/base.bak
        fi
        
        # Update DNS in resolvconf
        echo -n > /etc/resolvconf/resolv.conf.d/base
        echo "nameserver $primary_dns" >> /etc/resolvconf/resolv.conf.d/base
        if [ -n "$secondary_dns" ]; then
            echo "nameserver $secondary_dns" >> /etc/resolvconf/resolv.conf.d/base
        fi
        
        # Apply changes
        resolvconf -u
        echo "DNS servers updated using resolvconf."
    # Check if systemd-resolved is being used
    elif [ -f /etc/systemd/resolved.conf ] && systemctl is-active systemd-resolved >/dev/null 2>&1; then
        # Backup existing configuration
        if [ -f /etc/systemd/resolved.conf ]; then
            cp /etc/systemd/resolved.conf /etc/systemd/resolved.conf.bak
        fi
        
        # Update DNS in systemd-resolved
        if [ -n "$secondary_dns" ]; then
            sed -i '/^DNS=/d' /etc/systemd/resolved.conf
            echo "DNS=$primary_dns $secondary_dns" >> /etc/systemd/resolved.conf
        else
            sed -i '/^DNS=/d' /etc/systemd/resolved.conf
            echo "DNS=$primary_dns" >> /etc/systemd/resolved.conf
        fi
        
        # Apply changes
        systemctl restart systemd-resolved
        echo "DNS servers updated in systemd-resolved."
    # Check if NetworkManager is being used
    elif command -v nmcli >/dev/null 2>&1; then
        # Get the active connection
        CONNECTION=$(nmcli -t -f NAME,DEVICE,STATE c show --active | grep activated | head -1 | cut -d':' -f1)
        
        if [ -n "$CONNECTION" ]; then
            # Update DNS using NetworkManager
            if [ -n "$secondary_dns" ]; then
                nmcli connection modify "$CONNECTION" ipv4.dns "$primary_dns $secondary_dns"
            else
                nmcli connection modify "$CONNECTION" ipv4.dns "$primary_dns"
            fi
            
            # Apply changes
            nmcli connection up "$CONNECTION"
            echo "DNS servers updated using NetworkManager."
        else
            echo "Error: Could not find an active NetworkManager connection."
            return 1
        fi
    # Fallback to direct resolv.conf edit
    else
        # Backup existing configuration
        if [ -f /etc/resolv.conf ]; then
            cp /etc/resolv.conf /etc/resolv.conf.bak
        fi
        
        # Remove any symlink if exists
        if [ -L /etc/resolv.conf ]; then
            rm /etc/resolv.conf
        fi
        
        # Create new resolv.conf
        echo -n > /etc/resolv.conf
        echo "nameserver $primary_dns" >> /etc/resolv.conf
        if [ -n "$secondary_dns" ]; then
            echo "nameserver $secondary_dns" >> /etc/resolv.conf
        fi
        
        # Make resolv.conf immutable to prevent overwriting
        chattr +i /etc/resolv.conf
        echo "DNS servers updated in /etc/resolv.conf and file made immutable."
    fi
}

# Function to update DNS on RHEL/CentOS systems
update_dns_rhel() {
    local primary_dns=$1
    local secondary_dns=$2
    
    # Check if NetworkManager is being used
    if command -v nmcli >/dev/null 2>&1; then
        # Get the active connection
        CONNECTION=$(nmcli -t -f NAME,DEVICE,STATE c show --active | grep activated | head -1 | cut -d':' -f1)
        
        if [ -n "$CONNECTION" ]; then
            # Update DNS using NetworkManager
            if [ -n "$secondary_dns" ]; then
                nmcli connection modify "$CONNECTION" ipv4.dns "$primary_dns $secondary_dns"
            else
                nmcli connection modify "$CONNECTION" ipv4.dns "$primary_dns"
            fi
            
            # Make sure DNS is used by NetworkManager
            nmcli connection modify "$CONNECTION" ipv4.ignore-auto-dns yes
            
            # Apply changes
            nmcli connection up "$CONNECTION"
            echo "DNS servers updated using NetworkManager."
        else
            echo "Error: Could not find an active NetworkManager connection."
            return 1
        fi
    # Check for legacy network scripts (RHEL/CentOS 7 and earlier)
    elif [ -d /etc/sysconfig/network-scripts/ ]; then
        # Find the active interface
        INTERFACE=$(ip -o -4 route show to default | awk '{print $5}' | head -1)
        
        if [ -n "$INTERFACE" ]; then
            IFCFG_FILE="/etc/sysconfig/network-scripts/ifcfg-$INTERFACE"
            
            # Backup existing configuration
            if [ -f "$IFCFG_FILE" ]; then
                cp "$IFCFG_FILE" "$IFCFG_FILE.bak"
            else
                echo "Error: Could not find configuration file for interface $INTERFACE."
                return 1
            fi
            
            # Remove existing DNS entries
            sed -i '/^DNS[0-9]*=/d' "$IFCFG_FILE"
            
            # Add new DNS entries
            echo "DNS1=$primary_dns" >> "$IFCFG_FILE"
            if [ -n "$secondary_dns" ]; then
                echo "DNS2=$secondary_dns" >> "$IFCFG_FILE"
            fi
            
            # Set PEERDNS to no to prevent overwriting
            sed -i '/^PEERDNS=/d' "$IFCFG_FILE"
            echo "PEERDNS=no" >> "$IFCFG_FILE"
            
            # Restart network or reload the interface
            if systemctl is-active NetworkManager >/dev/null 2>&1; then
                systemctl restart NetworkManager
            else
                if systemctl is-active network >/dev/null 2>&1; then
                    systemctl restart network
                else
                    ifdown "$INTERFACE" && ifup "$INTERFACE"
                fi
            fi
            echo "DNS servers updated in network-scripts for interface $INTERFACE."
        else
            echo "Error: Could not find active network interface."
            return 1
        fi
    # Fallback to direct resolv.conf edit
    else
        # Backup existing configuration
        if [ -f /etc/resolv.conf ]; then
            cp /etc/resolv.conf /etc/resolv.conf.bak
        fi
        
        # Remove any symlink if exists
        if [ -L /etc/resolv.conf ]; then
            rm /etc/resolv.conf
        fi
        
        # Create new resolv.conf
        echo -n > /etc/resolv.conf
        echo "nameserver $primary_dns" >> /etc/resolv.conf
        if [ -n "$secondary_dns" ]; then
            echo "nameserver $secondary_dns" >> /etc/resolv.conf
        fi
        
        # Make resolv.conf immutable to prevent overwriting
        chattr +i /etc/resolv.conf
        echo "DNS servers updated in /etc/resolv.conf and file made immutable."
    fi
}

# Main script execution starts here
check_root
detect_distro

# Process command line arguments
PRIMARY_DNS=${1:-$DEFAULT_DNS}
SECONDARY_DNS=$2

echo "Updating DNS servers..."
echo "Primary DNS: $PRIMARY_DNS"
if [ -n "$SECONDARY_DNS" ]; then
    echo "Secondary DNS: $SECONDARY_DNS"
fi

# Update DNS based on distribution family
case "$DISTRO_FAMILY" in
    debian)
        update_dns_debian "$PRIMARY_DNS" "$SECONDARY_DNS"
        ;;
    rhel)
        update_dns_rhel "$PRIMARY_DNS" "$SECONDARY_DNS"
        ;;
    *)
        echo "Unsupported Linux distribution: $DISTRO (Family: $DISTRO_FAMILY)"
        echo "Falling back to generic method..."
        
        # Backup existing configuration
        if [ -f /etc/resolv.conf ]; then
            cp /etc/resolv.conf /etc/resolv.conf.bak
        fi
        
        # Remove any symlink if exists
        if [ -L /etc/resolv.conf ]; then
            rm /etc/resolv.conf
        fi
        
        # Create new resolv.conf
        echo -n > /etc/resolv.conf
        echo "nameserver $PRIMARY_DNS" >> /etc/resolv.conf
        if [ -n "$SECONDARY_DNS" ]; then
            echo "nameserver $SECONDARY_DNS" >> /etc/resolv.conf
        fi
        
        # Make resolv.conf immutable to prevent overwriting
        chattr +i /etc/resolv.conf
        echo "DNS servers updated in /etc/resolv.conf and file made immutable."
        ;;
esac

echo "DNS server update completed."
exit 0 