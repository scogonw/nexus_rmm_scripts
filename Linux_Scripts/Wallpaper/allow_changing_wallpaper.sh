#!/bin/bash

# allow_changing_wallpaper.sh
# Script to remove wallpaper locks and allow users to change their wallpapers manually
# Must be run as root

# Print banner
echo "====================================================="
echo "  Unlock Wallpaper Settings - Allow Manual Changes   "
echo "====================================================="

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root. Please use sudo or switch to root."
    exit 1
fi

# Function to log messages
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log_message "Starting wallpaper unlock process..."

# ===== GNOME/Cinnamon/MATE/Budgie Desktop Environments =====
# These use dconf database for settings

# Check if dconf is installed
if command -v dconf &> /dev/null; then
    log_message "Removing dconf locks for GNOME/Cinnamon/MATE/Budgie..."
    
    # Remove GNOME/Ubuntu/Budgie locks
    if [ -f "/etc/dconf/db/local.d/locks/background" ]; then
        rm -f /etc/dconf/db/local.d/01-background /etc/dconf/db/local.d/locks/background
        log_message "GNOME/Ubuntu/Budgie wallpaper locks removed."
    fi
    
    # Remove Cinnamon locks (Linux Mint)
    if [ -f "/etc/dconf/db/local.d/locks/cinnamon-background" ]; then
        rm -f /etc/dconf/db/local.d/01-cinnamon-background /etc/dconf/db/local.d/locks/cinnamon-background
        log_message "Cinnamon wallpaper locks removed."
    fi
    
    # Remove MATE locks
    if [ -f "/etc/dconf/db/local.d/locks/mate-background" ]; then
        rm -f /etc/dconf/db/local.d/01-mate-background /etc/dconf/db/local.d/locks/mate-background
        log_message "MATE wallpaper locks removed."
    fi
    
    # Remove Budgie locks
    if [ -f "/etc/dconf/db/local.d/locks/budgie-background" ]; then
        rm -f /etc/dconf/db/local.d/01-budgie-background /etc/dconf/db/local.d/locks/budgie-background
        log_message "Budgie wallpaper locks removed."
    fi
    
    # Update dconf database
    log_message "Updating dconf database..."
    dconf update
else
    log_message "dconf not found. Skipping GNOME/Cinnamon/MATE/Budgie unlock."
fi

# ===== Process all user home directories =====
log_message "Processing user home directories..."
user_count=0
processed=0

# Get all home directories from /etc/passwd
while IFS=: read -r username _ uid _ _ homedir _; do
    # Process only normal users (UID >= 1000 and < 65534)
    if [ "$uid" -ge 1000 ] && [ "$uid" -lt 65534 ] && [ -d "$homedir" ]; then
        user_count=$((user_count + 1))
        
        log_message "Processing user: $username ($homedir)"
        
        # Remove autostart entry
        autostart_file="$homedir/.config/autostart/set-wallpaper.desktop"
        if [ -f "$autostart_file" ]; then
            rm -f "$autostart_file"
            log_message "Removed autostart entry for $username."
        fi
        
        # Process XFCE settings
        xfce_config="$homedir/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml"
        if [ -f "$xfce_config" ]; then
            chmod 644 "$xfce_config"
            chown "$username":"$username" "$xfce_config"
            log_message "Reset permissions for XFCE configuration for $username."
        fi
        
        # Process KDE Plasma settings
        kde_config="$homedir/.config/plasma-org.kde.plasma.desktop-appletsrc"
        if [ -f "$kde_config" ]; then
            chmod 644 "$kde_config"
            chown "$username":"$username" "$kde_config"
            
            # Remove lock directory if it exists
            kde_lock_dir="$homedir/.config/plasma-org.kde.plasma.desktop-appletsrc.lock"
            if [ -d "$kde_lock_dir" ]; then
                rm -rf "$kde_lock_dir"
                log_message "Removed KDE Plasma lock directory for $username."
            fi
            
            log_message "Reset permissions for KDE Plasma configuration for $username."
        fi
        
        # Process LXDE settings
        lxde_config="$homedir/.config/pcmanfm/LXDE/desktop-items-0.conf"
        if [ -f "$lxde_config" ]; then
            chmod 644 "$lxde_config"
            chown "$username":"$username" "$lxde_config"
            log_message "Reset permissions for LXDE configuration for $username."
        fi
        
        # Process LXQt settings
        lxqt_config="$homedir/.config/pcmanfm-qt/lxqt/settings.conf"
        if [ -f "$lxqt_config" ]; then
            chmod 644 "$lxqt_config"
            chown "$username":"$username" "$lxqt_config"
            log_message "Reset permissions for LXQt configuration for $username."
        fi
        
        processed=$((processed + 1))
    fi
done < /etc/passwd

log_message "Processed $processed out of $user_count user accounts."

# ===== Final cleanup =====

# Clean up any generic X11 setup files
for userdir in /home/*; do
    if [ -d "$userdir" ]; then
        username=$(basename "$userdir")
        
        # Clean up X11 helpers
        x11_helper="$userdir/.local/bin/set-wallpaper.sh"
        if [ -f "$x11_helper" ]; then
            rm -f "$x11_helper"
            log_message "Removed X11 wallpaper helper script for $username."
        fi
        
        # Check .xprofile and .xinitrc for wallpaper entries
        for profile_file in "$userdir/.xprofile" "$userdir/.xinitrc"; do
            if [ -f "$profile_file" ] && grep -q "set-wallpaper.sh" "$profile_file"; then
                # Create a backup of the file
                cp "$profile_file" "$profile_file.bak"
                
                # Remove the wallpaper setting line
                grep -v "set-wallpaper.sh" "$profile_file.bak" > "$profile_file"
                
                # Fix ownership
                chown "$username":"$username" "$profile_file"
                
                log_message "Removed wallpaper entry from $(basename "$profile_file") for $username."
            fi
        done
    fi
done

echo ""
echo "====================================================="
echo "  Wallpaper Unlock Process Complete                  "
echo "====================================================="
echo "All users should now be able to change their wallpapers manually."
echo "Changes will take effect after users log out and log back in."
echo "The custom wallpaper image is still available at: /usr/share/backgrounds/custom_wallpaper.jpg"
echo "=====================================================" 