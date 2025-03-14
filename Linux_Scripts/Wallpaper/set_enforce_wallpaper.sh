#!/bin/bash

# Default wallpaper URL
DEFAULT_WALLPAPER_URL="https://triton-media.s3.ap-south-1.amazonaws.com/media/logos/wallpaper-scogo.jpg"

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root. Exiting."
    exit 1
fi

# Use provided URL or default
WALLPAPER_URL="${1:-$DEFAULT_WALLPAPER_URL}"
WALLPAPER_PATH="/usr/share/backgrounds/custom_wallpaper.jpg"

# Function to check and install missing packages
install_package_if_missing() {
    local package_name=$1
    if command -v apt-get &> /dev/null; then
        if ! dpkg -s "$package_name" &> /dev/null; then
            echo "Installing missing package: $package_name"
            apt-get update -qq && apt-get install -y "$package_name"
        fi
    elif command -v yum &> /dev/null; then
        if ! rpm -q "$package_name" &> /dev/null; then
            echo "Installing missing package: $package_name"
            yum install -y "$package_name"
        fi
    elif command -v dnf &> /dev/null; then
        if ! rpm -q "$package_name" &> /dev/null; then
            echo "Installing missing package: $package_name"
            dnf install -y "$package_name"
        fi
    elif command -v pacman &> /dev/null; then
        if ! pacman -Qi "$package_name" &> /dev/null; then
            echo "Installing missing package: $package_name"
            pacman -Sy --noconfirm "$package_name"
        fi
    elif command -v zypper &> /dev/null; then
        if ! rpm -q "$package_name" &> /dev/null; then
            echo "Installing missing package: $package_name"
            zypper --non-interactive install "$package_name"
        fi
    else
        echo "Unsupported package manager. Please install $package_name manually."
        return 1
    fi
    return 0
}

# Create directories with proper permissions
create_directory_with_owner() {
    local dir_path=$1
    local owner=$2
    
    if [ ! -d "$dir_path" ]; then
        mkdir -p "$dir_path"
    fi
    
    chown "$owner":"$owner" "$dir_path"
    chmod 755 "$dir_path"
}

# Ensure required tools are installed
echo "Checking for required packages..."
install_package_if_missing wget

# Create backgrounds directory if it doesn't exist
mkdir -p "$(dirname "$WALLPAPER_PATH")"

# Download the wallpaper
echo "Downloading wallpaper from $WALLPAPER_URL..."
if ! wget -q --timeout=30 --tries=3 -O "$WALLPAPER_PATH" "$WALLPAPER_URL"; then
    echo "Failed to download the wallpaper. Checking if URL is accessible..."
    if wget -q --spider --timeout=10 "$WALLPAPER_URL"; then
        echo "URL is accessible but download failed. Trying one more time..."
        if ! wget -q --timeout=30 --tries=3 -O "$WALLPAPER_PATH" "$WALLPAPER_URL"; then
            echo "Download failed again. Exiting."
            exit 1
        fi
    else
        echo "URL is not accessible. Exiting."
        exit 1
    fi
fi
echo "Wallpaper downloaded to $WALLPAPER_PATH."
chmod 644 "$WALLPAPER_PATH"

# Check if we're in a graphical environment at all
if ! command -v Xorg &> /dev/null && ! command -v wayland &> /dev/null && \
   ! [ -d "/usr/share/xsessions" ] && ! [ -d "/usr/share/wayland-sessions" ]; then
    echo "Warning: No graphical environment detected. The script may not work as expected."
fi

# Detect if we're dealing with Wayland
is_wayland() {
    local username=$1
    local uid=$(id -u "$username")
    if [ -n "$(ps -u "$username" | grep -i wayland)" ]; then
        return 0
    elif [ -f "/run/user/$uid/wayland-0" ]; then
        return 0
    else
        return 1
    fi
}

# Function to get DBUS address for a user
get_dbus_address() {
    local username=$1
    local uid=$(id -u "$username")
    
    if [ -f "/run/user/$uid/bus" ]; then
        echo "unix:path=/run/user/$uid/bus"
    elif [ -f "/run/user/$uid/dbus-session" ]; then
        cat "/run/user/$uid/dbus-session" | grep DBUS_SESSION_BUS_ADDRESS | cut -d= -f2-
    else
        # Fallback method
        echo "unix:path=/run/user/$uid/bus"
    fi
}

# Check desktop environment packages and install if needed
check_and_install_de_packages() {
    local username=$1
    local user_home=$2
    
    # Check and install desktop-specific packages
    if [[ -n "$(command -v gnome-session)" || -n "$(command -v gnome-shell)" ]]; then
        install_package_if_missing dconf-cli
        install_package_if_missing gsettings-desktop-schemas
    elif [[ -n "$(command -v xfce4-session)" ]]; then
        install_package_if_missing xfconf
    elif [[ -n "$(command -v plasmashell)" ]]; then
        install_package_if_missing plasma-workspace
    elif [[ -n "$(command -v cinnamon-session)" ]]; then
        install_package_if_missing dconf-cli
    elif [[ -n "$(command -v mate-session)" ]]; then
        install_package_if_missing dconf-cli
        install_package_if_missing mate-desktop
    elif [[ -n "$(command -v lxsession)" ]]; then
        install_package_if_missing pcmanfm
    elif [[ -n "$(command -v lxqt-session)" ]]; then
        install_package_if_missing pcmanfm-qt
    elif [ -f "$user_home/.xinitrc" ]; then
        # For generic X11 environments
        install_package_if_missing feh || install_package_if_missing nitrogen
    fi
}

# Create a desktop autostart file for persistence across logins
create_autostart_file() {
    local username=$1
    local user_home=$2
    local script_path="$user_home/.config/autostart/set-wallpaper.desktop"
    
    # Create autostart directory with proper permissions
    create_directory_with_owner "$user_home/.config/autostart" "$username"
    
    # Create autostart desktop file
    cat > "$script_path" << EOF
[Desktop Entry]
Type=Application
Name=Set Wallpaper
Exec=/bin/sh -c "if [ -f $WALLPAPER_PATH ]; then gsettings set org.gnome.desktop.background picture-uri 'file://$WALLPAPER_PATH' 2>/dev/null || xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitor0/image-path -s '$WALLPAPER_PATH' 2>/dev/null || true; fi"
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
StartupNotify=false
Terminal=false
EOF
    
    # Set ownership and permissions
    chown "$username":"$username" "$script_path"
    chmod 644 "$script_path"
}

# Function to set wallpaper and lock the setting
set_wallpaper_and_lock() {
    local username=$1
    local user_home=$2
    
    echo "Setting wallpaper for user: $username"
    
    # Check and install required packages for detected desktop environment
    check_and_install_de_packages "$username" "$user_home"
    
    # Get user's UID
    local uid=$(id -u "$username")
    local dbus_address=$(get_dbus_address "$username")
    
    # Check if we're in a Wayland session
    local is_wayland_session=0
    if is_wayland "$username"; then
        echo "Detected Wayland session for user: $username"
        is_wayland_session=1
    fi
    
    # Skip if the user is not logged in or dbus isn't running
    if [ ! -d "/run/user/$uid" ]; then
        echo "User $username is not logged in. Configuring for next login."
    fi
    
    # Create autostart file for persistence
    create_autostart_file "$username" "$user_home"
    
    # GNOME/GNOME-based (Ubuntu, Fedora, Pop!_OS, etc.)
    if command -v gsettings &> /dev/null && [ -n "$(sudo -u "$username" gsettings list-schemas 2>/dev/null | grep -E 'org.gnome.desktop.background|org.cinnamon.desktop.background')" ]; then
        echo "Detected GNOME-based desktop environment for user: $username"
        
        # For GNOME Shell
        if sudo -u "$username" DBUS_SESSION_BUS_ADDRESS="$dbus_address" gsettings list-schemas 2>/dev/null | grep -q "org.gnome.desktop.background"; then
            # Make sure gsettings can run
            if [ -d "/run/user/$uid" ]; then
                sudo -u "$username" DBUS_SESSION_BUS_ADDRESS="$dbus_address" gsettings set org.gnome.desktop.background picture-uri "file://$WALLPAPER_PATH" || true
                sudo -u "$username" DBUS_SESSION_BUS_ADDRESS="$dbus_address" gsettings set org.gnome.desktop.background picture-options 'stretched' || true
                
                # Support for dark mode in newer GNOME versions
                if sudo -u "$username" DBUS_SESSION_BUS_ADDRESS="$dbus_address" gsettings get org.gnome.desktop.background picture-uri-dark &>/dev/null; then
                    sudo -u "$username" DBUS_SESSION_BUS_ADDRESS="$dbus_address" gsettings set org.gnome.desktop.background picture-uri-dark "file://$WALLPAPER_PATH" || true
                fi
                
                # Lock settings
                sudo -u "$username" DBUS_SESSION_BUS_ADDRESS="$dbus_address" gsettings set org.gnome.desktop.background show-desktop-icons false || true
            fi
            
            # Create dconf profile to lock settings
            mkdir -p /etc/dconf/profile
            echo "user-db:user
system-db:local" > /etc/dconf/profile/user
            
            mkdir -p /etc/dconf/db/local.d
            echo "[org/gnome/desktop/background]
picture-uri='file://$WALLPAPER_PATH'
picture-options='stretched'
picture-uri-dark='file://$WALLPAPER_PATH'" > /etc/dconf/db/local.d/01-background
            
            mkdir -p /etc/dconf/db/local.d/locks
            echo "/org/gnome/desktop/background/picture-uri
/org/gnome/desktop/background/picture-options
/org/gnome/desktop/background/picture-uri-dark" > /etc/dconf/db/local.d/locks/background
            
            dconf update || true
        fi
        
        # For Cinnamon
        if sudo -u "$username" DBUS_SESSION_BUS_ADDRESS="$dbus_address" gsettings list-schemas 2>/dev/null | grep -q "org.cinnamon.desktop.background"; then
            if [ -d "/run/user/$uid" ]; then
                sudo -u "$username" DBUS_SESSION_BUS_ADDRESS="$dbus_address" gsettings set org.cinnamon.desktop.background picture-uri "file://$WALLPAPER_PATH" || true
                sudo -u "$username" DBUS_SESSION_BUS_ADDRESS="$dbus_address" gsettings set org.cinnamon.desktop.background picture-options 'stretched' || true
            fi
            
            # Lock settings for Cinnamon
            mkdir -p /etc/dconf/db/local.d
            echo "[org/cinnamon/desktop/background]
picture-uri='file://$WALLPAPER_PATH'
picture-options='stretched'" > /etc/dconf/db/local.d/01-cinnamon-background
            
            mkdir -p /etc/dconf/db/local.d/locks
            echo "/org/cinnamon/desktop/background/picture-uri
/org/cinnamon/desktop/background/picture-options" > /etc/dconf/db/local.d/locks/cinnamon-background
            
            dconf update || true
        fi
        
    # XFCE
    elif command -v xfconf-query &> /dev/null; then
        echo "Detected XFCE desktop environment for user: $username"
        
        # Create xfce config directory with proper permissions
        create_directory_with_owner "$user_home/.config/xfce4/xfconf/xfce-perchannel-xml" "$username"
        
        # Create xfce settings (works for logged-in and future logins)
        cat > "$user_home/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-desktop" version="1.0">
  <property name="backdrop" type="empty">
    <property name="screen0" type="empty">
      <property name="monitor0" type="empty">
        <property name="image-path" type="string" value="$WALLPAPER_PATH"/>
        <property name="image-style" type="int" value="3"/>
        <property name="image-show" type="bool" value="true"/>
      </property>
      <property name="monitor1" type="empty">
        <property name="image-path" type="string" value="$WALLPAPER_PATH"/>
        <property name="image-style" type="int" value="3"/>
        <property name="image-show" type="bool" value="true"/>
      </property>
      <property name="monitorHDMI" type="empty">
        <property name="image-path" type="string" value="$WALLPAPER_PATH"/>
        <property name="image-style" type="int" value="3"/>
        <property name="image-show" type="bool" value="true"/>
      </property>
      <property name="monitorVGA" type="empty">
        <property name="image-path" type="string" value="$WALLPAPER_PATH"/>
        <property name="image-style" type="int" value="3"/>
        <property name="image-show" type="bool" value="true"/>
      </property>
    </property>
  </property>
</channel>
EOF
        # Make the file read-only
        chown "$username":"$username" "$user_home/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml"
        chmod 444 "$user_home/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml"
        
        # Try to set for current session if user is logged in
        if [ -d "/run/user/$uid" ]; then
            # Try setting for multiple monitors
            for monitor in monitor0 monitor1 monitorHDMI monitorVGA; do
                DISPLAY=:0 sudo -u "$username" xfconf-query -c xfce4-desktop -p /backdrop/screen0/$monitor/image-path -s "$WALLPAPER_PATH" 2>/dev/null || true
                DISPLAY=:0 sudo -u "$username" xfconf-query -c xfce4-desktop -p /backdrop/screen0/$monitor/image-style -s 3 2>/dev/null || true
            done
        fi
        
    # KDE Plasma
    elif command -v plasma-apply-wallpaperimage &> /dev/null || [ -d "$user_home/.kde" ] || [ -d "$user_home/.kde4" ]; then
        echo "Detected KDE Plasma desktop environment for user: $username"
        
        # Create plasma config directory with proper permissions
        create_directory_with_owner "$user_home/.config" "$username"
        
        # For Plasma 5.x and above
        if command -v plasma-apply-wallpaperimage &> /dev/null && [ -d "/run/user/$uid" ]; then
            sudo -u "$username" DBUS_SESSION_BUS_ADDRESS="$dbus_address" plasma-apply-wallpaperimage "$WALLPAPER_PATH" || true
        fi
        
        # Create/modify plasmarc to prevent changes
        mkdir -p "$user_home/.config/plasma-org.kde.plasma.desktop-appletsrc.lock"
        chown -R "$username":"$username" "$user_home/.config/plasma-org.kde.plasma.desktop-appletsrc.lock"
        
        # For containment wallpaper configurations
        kwriteconfig5_path=$(which kwriteconfig5 2>/dev/null)
        if [ -n "$kwriteconfig5_path" ]; then
            for containment_id in {1..10}; do
                sudo -u "$username" "$kwriteconfig5_path" --file "$user_home/.config/plasma-org.kde.plasma.desktop-appletsrc" --group Containments --group $containment_id --group Wallpaper --group org.kde.image --group General --key Image "file://$WALLPAPER_PATH" 2>/dev/null || true
            done
        fi
        
        # Lock screen changes by making the wallpaper config read-only
        if [ -f "$user_home/.config/plasma-org.kde.plasma.desktop-appletsrc" ]; then
            chmod 444 "$user_home/.config/plasma-org.kde.plasma.desktop-appletsrc" || true
        fi
        
    # MATE Desktop
    elif command -v mate-session &> /dev/null || [ -d "/usr/share/mate" ]; then
        echo "Detected MATE desktop environment for user: $username"
        
        if [ -d "/run/user/$uid" ]; then
            sudo -u "$username" DBUS_SESSION_BUS_ADDRESS="$dbus_address" gsettings set org.mate.background picture-filename "$WALLPAPER_PATH" || true
            sudo -u "$username" DBUS_SESSION_BUS_ADDRESS="$dbus_address" gsettings set org.mate.background picture-options 'stretched' || true
        fi
        
        # Lock settings
        mkdir -p /etc/dconf/db/local.d
        echo "[org/mate/desktop/background]
picture-filename='$WALLPAPER_PATH'
picture-options='stretched'" > /etc/dconf/db/local.d/01-mate-background
        
        mkdir -p /etc/dconf/db/local.d/locks
        echo "/org/mate/desktop/background/picture-filename
/org/mate/desktop/background/picture-options" > /etc/dconf/db/local.d/locks/mate-background
        
        dconf update || true
        
    # LXDE
    elif command -v lxsession &> /dev/null; then
        echo "Detected LXDE desktop environment for user: $username"
        
        # Create directory with proper permissions
        create_directory_with_owner "$user_home/.config/pcmanfm/LXDE" "$username"
        
        cat > "$user_home/.config/pcmanfm/LXDE/desktop-items-0.conf" << EOF
[*]
wallpaper_mode=stretch
wallpaper=$WALLPAPER_PATH
EOF
        chown -R "$username":"$username" "$user_home/.config/pcmanfm"
        chmod 444 "$user_home/.config/pcmanfm/LXDE/desktop-items-0.conf"
        
        # Try to set for current session
        if [ -d "/run/user/$uid" ]; then
            sudo -u "$username" DISPLAY=:0 pcmanfm --set-wallpaper="$WALLPAPER_PATH" 2>/dev/null || true
        fi
        
    # LXQt
    elif command -v lxqt-session &> /dev/null; then
        echo "Detected LXQt desktop environment for user: $username"
        
        # Create directory with proper permissions
        create_directory_with_owner "$user_home/.config/pcmanfm-qt/lxqt" "$username"
        
        cat > "$user_home/.config/pcmanfm-qt/lxqt/settings.conf" << EOF
[Desktop]
WallpaperMode=stretch
Wallpaper=$WALLPAPER_PATH
EOF
        chown -R "$username":"$username" "$user_home/.config/pcmanfm-qt"
        chmod 444 "$user_home/.config/pcmanfm-qt/lxqt/settings.conf"
        
        # Try to set for current session
        if [ -d "/run/user/$uid" ]; then
            sudo -u "$username" DISPLAY=:0 pcmanfm-qt --set-wallpaper="$WALLPAPER_PATH" 2>/dev/null || true
        fi
        
    # Budgie Desktop
    elif command -v budgie-desktop &> /dev/null; then
        echo "Detected Budgie desktop environment for user: $username"
        
        if [ -d "/run/user/$uid" ]; then
            sudo -u "$username" DBUS_SESSION_BUS_ADDRESS="$dbus_address" gsettings set org.gnome.desktop.background picture-uri "file://$WALLPAPER_PATH" || true
            sudo -u "$username" DBUS_SESSION_BUS_ADDRESS="$dbus_address" gsettings set org.gnome.desktop.background picture-options 'stretched' || true
        fi
        
        # Lock settings (same method as GNOME)
        mkdir -p /etc/dconf/db/local.d
        echo "[org/gnome/desktop/background]
picture-uri='file://$WALLPAPER_PATH'
picture-options='stretched'" > /etc/dconf/db/local.d/01-budgie-background
        
        mkdir -p /etc/dconf/db/local.d/locks
        echo "/org/gnome/desktop/background/picture-uri
/org/gnome/desktop/background/picture-options" > /etc/dconf/db/local.d/locks/budgie-background
        
        dconf update || true
        
    else
        echo "Warning: Unsupported desktop environment detected for user: $username"
        echo "Attempting generic X11 method for wallpaper setting."
        
        # Install feh or nitrogen for generic wallpaper setting
        install_package_if_missing feh || install_package_if_missing nitrogen
        
        # Create directory with proper permissions
        create_directory_with_owner "$user_home/.local/bin" "$username"
        
        # Create script for feh/nitrogen to set wallpaper
        cat > "$user_home/.local/bin/set-wallpaper.sh" << EOF
#!/bin/bash
if command -v feh &> /dev/null; then
    feh --bg-scale $WALLPAPER_PATH
elif command -v nitrogen &> /dev/null; then
    nitrogen --set-scaled --save $WALLPAPER_PATH
fi
EOF
        chmod +x "$user_home/.local/bin/set-wallpaper.sh"
        chown "$username":"$username" "$user_home/.local/bin/set-wallpaper.sh"
        
        # Add to user's .xprofile or .xinitrc if they don't call the script already
        for profile_file in "$user_home/.xprofile" "$user_home/.xinitrc"; do
            if [ -f "$profile_file" ]; then
                if ! grep -q "set-wallpaper.sh" "$profile_file"; then
                    echo "$user_home/.local/bin/set-wallpaper.sh" >> "$profile_file"
                    chown "$username":"$username" "$profile_file"
                fi
            fi
        done
        
        # If neither exist, create .xprofile
        if [ ! -f "$user_home/.xprofile" ] && [ ! -f "$user_home/.xinitrc" ]; then
            echo "#!/bin/bash" > "$user_home/.xprofile"
            echo "$user_home/.local/bin/set-wallpaper.sh" >> "$user_home/.xprofile"
            chmod +x "$user_home/.xprofile"
            chown "$username":"$username" "$user_home/.xprofile"
        fi
        
        # Try to set wallpaper for current session
        if [ -d "/run/user/$uid" ]; then
            sudo -u "$username" DISPLAY=:0 "$user_home/.local/bin/set-wallpaper.sh" 2>/dev/null || true
        fi
    fi
    
    echo "Wallpaper set and locked for user: $username"
}

# Iterate over all human users
echo "Processing user directories..."
awk -F: '{ if ($3 >= 1000 && $3 < 65534) print $1 ":" $6 }' /etc/passwd | while IFS=: read -r username user_home; do
    if [ -d "$user_home" ]; then
        set_wallpaper_and_lock "$username" "$user_home"
    fi
done

echo "Wallpaper has been set for all users."
echo "Script completed successfully."
