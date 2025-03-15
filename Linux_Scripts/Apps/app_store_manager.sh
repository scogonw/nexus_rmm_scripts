#!/bin/bash

# app_store_manager.sh
# 
# This script manages app store access permissions for non-root users
# on Linux systems supporting various package managers and app stores.
#
# Author: Nexus RMM Team
# Created: $(date +"%Y-%m-%d")
# License: MIT
#
# Note on Zorin OS and other Ubuntu derivatives:
# Some distributions like Zorin OS require additional PolicyKit rules
# beyond just dconf settings to properly restrict GNOME Software.
# The --debug flag can be used to diagnose issues with the script
# and determine which specific restrictions are not being applied correctly.
# If the script doesn't restrict installation on a particular system,
# running with --debug will show detailed information to help identify the issue.

# Error codes
ERR_NOT_ROOT=1
ERR_INVALID_ARGS=2
ERR_UNSUPPORTED_SYSTEM=3

# Global flags
DEBUG_MODE=false

# Color codes for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Print usage information
print_usage() {
    echo -e "${BLUE}Usage:${NC} $0 [OPTION] [USERNAME]"
    echo 
    echo "Manage app store access permissions for non-root users."
    echo
    echo -e "${BLUE}Options:${NC}"
    echo "  --allow           Allow app store access for specified user or all non-root users"
    echo "  --deny            Deny app store access for specified user or all non-root users (default)"
    echo "  --status          Show current access status for all users"
    echo "  --debug           Enable verbose debug output"
    echo "  --help            Display this help message"
    echo
    echo -e "${BLUE}Arguments:${NC}"
    echo "  USERNAME          Optional: Specify a user to modify. If omitted, applies to all non-root users."
    echo
    echo -e "${YELLOW}Note:${NC} This script must be run as root."
    echo
}

# Debug logging
log_debug() {
    if [ "$DEBUG_MODE" = true ]; then
        echo -e "${CYAN}[DEBUG]${NC} $1"
    fi
}

# Check if user is root
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${RED}Error:${NC} This script must be run as root." >&2
        exit $ERR_NOT_ROOT
    fi
}

# Log messages
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Get system information for debugging
collect_system_info() {
    log_debug "Collecting system information..."
    
    local os_info=$(cat /etc/os-release 2>/dev/null || echo "OS information not available")
    log_debug "OS Info: $os_info"
    
    local kernel_info=$(uname -a)
    log_debug "Kernel: $kernel_info"
    
    # Check for specific distributions
    if grep -q "zorin" /etc/os-release 2>/dev/null; then
        log_debug "Detected Zorin OS - applying specific configurations"
    fi
    
    # List important directories for package management
    for dir in "/etc/apt" "/var/lib/dpkg" "/usr/share/polkit-1" "/var/lib/snapd" "/var/lib/flatpak"; do
        if [ -d "$dir" ]; then
            log_debug "Directory exists: $dir"
        else
            log_debug "Directory missing: $dir"
        fi
    done
}

# Detect installed app stores/package managers
detect_app_stores() {
    log_info "Detecting installed package managers and app stores..."
    
    APP_STORES=()
    
    # Check for APT (Debian/Ubuntu)
    if command -v apt &> /dev/null; then
        APP_STORES+=("apt")
        log_debug "Found apt package manager"
    fi
    
    # Check for DNF (Fedora/RHEL)
    if command -v dnf &> /dev/null; then
        APP_STORES+=("dnf")
        log_debug "Found dnf package manager"
    fi
    
    # Check for YUM (CentOS/RHEL)
    if command -v yum &> /dev/null; then
        APP_STORES+=("yum")
        log_debug "Found yum package manager"
    fi
    
    # Check for Flatpak
    if command -v flatpak &> /dev/null; then
        APP_STORES+=("flatpak")
        log_debug "Found flatpak package manager"
        log_debug "Flatpak location: $(which flatpak)"
        log_debug "Flatpak version: $(flatpak --version 2>/dev/null || echo 'unknown')"
    fi
    
    # Check for Snap
    if command -v snap &> /dev/null; then
        APP_STORES+=("snap")
        log_debug "Found snap package manager"
        log_debug "Snap location: $(which snap)"
        log_debug "Snap version: $(snap version 2>/dev/null || echo 'unknown')"
    fi
    
    # Check for GNOME Software
    if command -v gnome-software &> /dev/null; then
        APP_STORES+=("gnome-software")
        log_debug "Found GNOME Software"
        log_debug "GNOME Software location: $(which gnome-software)"
        log_debug "PackageKit status: $(systemctl status packagekit 2>&1 || echo 'PackageKit not found')"
    fi
    
    # Check for Discover (KDE)
    if command -v plasma-discover &> /dev/null; then
        APP_STORES+=("discover")
        log_debug "Found KDE Discover"
    fi
    
    # Check for AppImage support (basic check)
    if [ -d "/usr/local/bin" ]; then
        APP_STORES+=("appimage")
        log_debug "Added AppImage support (basic check)"
    fi
    
    # Check for Ubuntu Software Center
    if command -v software-center &> /dev/null || command -v ubuntu-software &> /dev/null; then
        APP_STORES+=("ubuntu-software")
        log_debug "Found Ubuntu Software Center"
        
        if command -v ubuntu-software &> /dev/null; then
            log_debug "Ubuntu Software location: $(which ubuntu-software)"
        fi
        if command -v software-center &> /dev/null; then
            log_debug "Software Center location: $(which software-center)"
        fi
    fi
    
    # Check for Zorin specific app stores
    if grep -q "zorin" /etc/os-release 2>/dev/null; then
        if [ -f "/usr/bin/zorin-software" ] || [ -f "/usr/bin/software-store" ]; then
            APP_STORES+=("zorin-software")
            log_debug "Found Zorin OS Software application"
        fi
    fi
    
    if [ ${#APP_STORES[@]} -eq 0 ]; then
        log_warning "No supported package managers or app stores detected."
        return 1
    else
        log_info "Detected app stores: ${APP_STORES[*]}"
        return 0
    fi
}

# Get all human users (UID >= 1000, excluding system users)
get_human_users() {
    local users=$(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd)
    log_debug "Detected human users: $users"
    echo "$users"
}

# Manage APT permissions
manage_apt_access() {
    local action=$1
    local user=$2
    
    log_debug "Managing APT access for user $user: $action"
    
    if [ "$action" = "deny" ]; then
        # Create a sudoers rule to prevent apt/apt-get/aptitude commands
        local rule="$user ALL=(ALL) !NOPASSWD: /usr/bin/apt*, /usr/bin/apt-get*, /usr/bin/aptitude*"
        echo "$rule" > "/etc/sudoers.d/restrict-apt-$user"
        chmod 0440 "/etc/sudoers.d/restrict-apt-$user"
        
        log_debug "Created sudoers rule: $rule"
        log_debug "Rule file: /etc/sudoers.d/restrict-apt-$user"
        
        log_info "Restricted APT access for user $user"
    elif [ "$action" = "allow" ]; then
        # Remove the restriction file if it exists
        if [ -f "/etc/sudoers.d/restrict-apt-$user" ]; then
            rm -f "/etc/sudoers.d/restrict-apt-$user"
            log_debug "Removed APT restriction file: /etc/sudoers.d/restrict-apt-$user"
            log_info "Allowed APT access for user $user"
        else
            log_debug "No APT restriction file found for user $user"
        fi
    fi
}

# Manage DNF/YUM permissions
manage_dnf_yum_access() {
    local action=$1
    local user=$2
    local pkg_mgr=$3  # dnf or yum
    
    log_debug "Managing $pkg_mgr access for user $user: $action"
    
    if [ "$action" = "deny" ]; then
        # Create a sudoers rule to prevent dnf/yum commands
        local rule="$user ALL=(ALL) !NOPASSWD: /usr/bin/$pkg_mgr*"
        echo "$rule" > "/etc/sudoers.d/restrict-$pkg_mgr-$user"
        chmod 0440 "/etc/sudoers.d/restrict-$pkg_mgr-$user"
        
        log_debug "Created sudoers rule: $rule"
        log_debug "Rule file: /etc/sudoers.d/restrict-$pkg_mgr-$user"
        
        log_info "Restricted $pkg_mgr access for user $user"
    elif [ "$action" = "allow" ]; then
        # Remove the restriction file if it exists
        if [ -f "/etc/sudoers.d/restrict-$pkg_mgr-$user" ]; then
            rm -f "/etc/sudoers.d/restrict-$pkg_mgr-$user"
            log_debug "Removed $pkg_mgr restriction file: /etc/sudoers.d/restrict-$pkg_mgr-$user"
            log_info "Allowed $pkg_mgr access for user $user"
        else
            log_debug "No $pkg_mgr restriction file found for user $user"
        fi
    fi
}

# Manage Flatpak permissions
manage_flatpak_access() {
    local action=$1
    local user=$2
    
    log_debug "Managing Flatpak access for user $user: $action"
    
    if [ "$action" = "deny" ]; then
        # Remove execute permissions from flatpak for the user group
        if getent group flatpak > /dev/null 2>&1; then
            log_debug "Flatpak group exists, removing user from group"
            gpasswd -d "$user" flatpak &> /dev/null || true
        else
            # Create a flatpak group if it doesn't exist
            log_debug "Creating flatpak group"
            groupadd flatpak
        fi
        
        # Change permissions on flatpak binary
        if [ -f "/usr/bin/flatpak" ]; then
            log_debug "Setting permissions on flatpak binary"
            chown root:flatpak /usr/bin/flatpak
            chmod 750 /usr/bin/flatpak
            log_debug "Flatpak binary permissions: $(ls -la /usr/bin/flatpak)"
            log_info "Restricted Flatpak access for user $user"
        else
            log_debug "Flatpak binary not found at /usr/bin/flatpak"
            # Try to find flatpak
            local flatpak_path=$(which flatpak 2>/dev/null)
            if [ -n "$flatpak_path" ]; then
                log_debug "Found flatpak at $flatpak_path"
                chown root:flatpak "$flatpak_path"
                chmod 750 "$flatpak_path"
                log_debug "Flatpak binary permissions: $(ls -la "$flatpak_path")"
            else
                log_warning "Could not find flatpak binary, cannot restrict access"
            fi
        fi
        
        # Add PolicyKit rules for Flatpak
        mkdir -p "/etc/polkit-1/rules.d"
        cat > "/etc/polkit-1/rules.d/20-restrict-flatpak-${user}.rules" << EOF
polkit.addRule(function(action, subject) {
    if ((action.id.indexOf("org.freedesktop.Flatpak.") === 0) &&
        subject.user === "$user") {
        return polkit.Result.AUTH_ADMIN;
    }
});
EOF
        log_debug "Created PolicyKit rules for Flatpak at /etc/polkit-1/rules.d/20-restrict-flatpak-${user}.rules"
        
    elif [ "$action" = "allow" ]; then
        # Add user to flatpak group
        if getent group flatpak > /dev/null 2>&1; then
            log_debug "Adding user to flatpak group"
            gpasswd -a "$user" flatpak &> /dev/null
            log_info "Allowed Flatpak access for user $user"
        else
            log_warning "Flatpak group doesn't exist, creating and adding user"
            groupadd flatpak
            gpasswd -a "$user" flatpak &> /dev/null
        fi
        
        # Remove PolicyKit restrictions if they exist
        if [ -f "/etc/polkit-1/rules.d/20-restrict-flatpak-${user}.rules" ]; then
            rm -f "/etc/polkit-1/rules.d/20-restrict-flatpak-${user}.rules"
            log_debug "Removed Flatpak PolicyKit rules"
        fi
    fi
}

# Manage Snap permissions
manage_snap_access() {
    local action=$1
    local user=$2
    
    log_debug "Managing Snap access for user $user: $action"
    
    if [ "$action" = "deny" ]; then
        # Create a sudoers rule to prevent snap commands
        local rule="$user ALL=(ALL) !NOPASSWD: /usr/bin/snap*"
        echo "$rule" > "/etc/sudoers.d/restrict-snap-$user"
        chmod 0440 "/etc/sudoers.d/restrict-snap-$user"
        log_debug "Created sudoers rule: $rule"
        
        # Restrict access to snap socket
        if [ -d "/var/lib/snapd/snap" ]; then
            log_debug "Setting ACLs on /var/lib/snapd/snap"
            setfacl -m "u:$user:r--" /var/lib/snapd/snap 2>/dev/null
            if [ $? -ne 0 ]; then
                log_debug "setfacl failed, using chmod instead"
                chmod o-w /var/lib/snapd/snap
            fi
            log_debug "Snap directory permissions: $(ls -la /var/lib/snapd/snap)"
        else
            log_debug "Snap directory /var/lib/snapd/snap not found"
        fi
        
        # Add PolicyKit rules for Snap
        mkdir -p "/etc/polkit-1/rules.d"
        cat > "/etc/polkit-1/rules.d/20-restrict-snap-${user}.rules" << EOF
polkit.addRule(function(action, subject) {
    if ((action.id.indexOf("io.snapcraft.") === 0) &&
        subject.user === "$user") {
        return polkit.Result.AUTH_ADMIN;
    }
});
EOF
        log_debug "Created PolicyKit rules for Snap"
        
        log_info "Restricted Snap access for user $user"
    elif [ "$action" = "allow" ]; then
        # Remove the restriction file if it exists
        if [ -f "/etc/sudoers.d/restrict-snap-$user" ]; then
            rm -f "/etc/sudoers.d/restrict-snap-$user"
            log_debug "Removed Snap sudoers restriction"
        fi
        
        # Restore access to snap socket if needed
        if [ -d "/var/lib/snapd/snap" ]; then
            log_debug "Removing ACLs from /var/lib/snapd/snap"
            setfacl -x "u:$user" /var/lib/snapd/snap 2>/dev/null
            if [ $? -ne 0 ]; then
                log_debug "setfacl remove failed, using chmod instead"
                chmod o+w /var/lib/snapd/snap
            fi
        fi
        
        # Remove PolicyKit restrictions
        if [ -f "/etc/polkit-1/rules.d/20-restrict-snap-${user}.rules" ]; then
            rm -f "/etc/polkit-1/rules.d/20-restrict-snap-${user}.rules"
            log_debug "Removed Snap PolicyKit rules"
        fi
        
        log_info "Allowed Snap access for user $user"
    fi
}

# Enhanced GNOME Software restriction (with Zorin OS support)
manage_gnome_software_access() {
    local action=$1
    local user=$2
    
    log_debug "Managing GNOME Software/Ubuntu Software Center access for user $user: $action"
    
    if [ "$action" = "deny" ]; then
        # Create dconf restriction for user
        mkdir -p "/etc/dconf/profile"
        echo "user-db:user" > "/etc/dconf/profile/$user"
        echo "system-db:local" >> "/etc/dconf/profile/$user"
        log_debug "Created dconf profile for user $user"
        
        mkdir -p "/etc/dconf/db/local.d"
        cat > "/etc/dconf/db/local.d/00-restrict-software-${user}" << EOF
[org.gnome.software]
allow-updates=false
download-updates=false
allow-apps-install=false

[org.gnome.desktop.app-folders]
folder-children=['Utilities', 'YaST']
EOF
        log_debug "Created dconf restriction file: /etc/dconf/db/local.d/00-restrict-software-${user}"
        
        # Add locks to ensure settings can't be changed by the user
        mkdir -p "/etc/dconf/db/local.d/locks"
        cat > "/etc/dconf/db/local.d/locks/software-locks" << EOF
/org/gnome/software/allow-updates
/org/gnome/software/download-updates
/org/gnome/software/allow-apps-install
EOF
        log_debug "Created dconf locks for software settings"
        
        # Add PolicyKit rules for PackageKit and GNOME Software
        mkdir -p "/etc/polkit-1/rules.d"
        cat > "/etc/polkit-1/rules.d/10-restrict-software-${user}.rules" << EOF
polkit.addRule(function(action, subject) {
    if ((action.id.indexOf("org.freedesktop.packagekit.") === 0 ||
         action.id.indexOf("org.gnome.software.") === 0 ||
         action.id.indexOf("org.gnome.install.") === 0) &&
        subject.user === "$user") {
        return polkit.Result.AUTH_ADMIN;
    }
});
EOF
        log_debug "Created PolicyKit rules for GNOME Software and PackageKit"
        
        # Update dconf database
        dconf update
        log_debug "Updated dconf database with new settings"
        
        # For Zorin OS, add specific restrictions if needed
        if grep -q "zorin" /etc/os-release 2>/dev/null; then
            log_debug "Applying Zorin OS specific restrictions"
            
            # Additional policy rules for Zorin OS
            cat > "/etc/polkit-1/rules.d/11-restrict-zorin-software-${user}.rules" << EOF
polkit.addRule(function(action, subject) {
    if ((action.id.indexOf("com.ubuntu.") === 0 ||
         action.id.indexOf("com.zorin.") === 0 ||
         action.id.indexOf("org.gnome.installer.") === 0) &&
        subject.user === "$user") {
        return polkit.Result.AUTH_ADMIN;
    }
});
EOF
            log_debug "Created Zorin OS specific PolicyKit rules"
        fi
        
        log_info "Restricted GNOME Software/Ubuntu Software Center access for user $user"
    elif [ "$action" = "allow" ]; then
        # Remove restrictions
        if [ -f "/etc/dconf/db/local.d/00-restrict-software-${user}" ]; then
            rm -f "/etc/dconf/db/local.d/00-restrict-software-${user}"
            log_debug "Removed dconf restriction file"
            
            # Remove locks
            rm -f "/etc/dconf/db/local.d/locks/software-locks"
            log_debug "Removed dconf software locks"
            
            # Update dconf database
            dconf update
            log_debug "Updated dconf database after removing restrictions"
        else
            log_debug "No dconf restriction file found for user $user"
        fi
        
        # Remove PolicyKit restrictions
        if [ -f "/etc/polkit-1/rules.d/10-restrict-software-${user}.rules" ]; then
            rm -f "/etc/polkit-1/rules.d/10-restrict-software-${user}.rules"
            log_debug "Removed GNOME Software PolicyKit rules"
        fi
        
        # Remove Zorin-specific restrictions
        if [ -f "/etc/polkit-1/rules.d/11-restrict-zorin-software-${user}.rules" ]; then
            rm -f "/etc/polkit-1/rules.d/11-restrict-zorin-software-${user}.rules"
            log_debug "Removed Zorin OS specific PolicyKit rules"
        fi
        
        log_info "Allowed GNOME Software/Ubuntu Software Center access for user $user"
    fi
}

# Manage KDE Discover
manage_discover_access() {
    local action=$1
    local user=$2
    
    log_debug "Managing KDE Discover access for user $user: $action"
    
    if [ "$action" = "deny" ]; then
        # Create a policy file to restrict access
        mkdir -p "/etc/polkit-1/rules.d"
        cat > "/etc/polkit-1/rules.d/10-restrict-discover-${user}.rules" << EOF
polkit.addRule(function(action, subject) {
    if ((action.id.indexOf("org.freedesktop.packagekit.") === 0 ||
         action.id.indexOf("org.kde.discover.") === 0) &&
        subject.user === "$user") {
        return polkit.Result.AUTH_ADMIN;
    }
});
EOF
        log_debug "Created PolicyKit rules for KDE Discover: /etc/polkit-1/rules.d/10-restrict-discover-${user}.rules"
        log_info "Restricted KDE Discover access for user $user"
    elif [ "$action" = "allow" ]; then
        # Remove restrictions
        if [ -f "/etc/polkit-1/rules.d/10-restrict-discover-${user}.rules" ]; then
            rm -f "/etc/polkit-1/rules.d/10-restrict-discover-${user}.rules"
            log_debug "Removed KDE Discover PolicyKit rules"
            log_info "Allowed KDE Discover access for user $user"
        else
            log_debug "No KDE Discover restriction file found"
        fi
    fi
}

# Manage AppImage execution permissions
manage_appimage_access() {
    local action=$1
    local user=$2
    
    log_debug "Managing AppImage access for user $user: $action"
    
    # Get the numeric user ID
    local user_id=$(id -u "$user" 2>/dev/null)
    log_debug "User ID for $user: $user_id"
    
    if [ "$action" = "deny" ]; then
        # Create a security module to prevent AppImage execution
        mkdir -p "/etc/apparmor.d/local"
        cat > "/etc/apparmor.d/local/restrict-appimage-${user}" << EOF
# Restrict AppImage execution for user $user
deny owner uid=$user_id /**/*.AppImage mrwklx,
EOF
        log_debug "Created AppArmor profile: /etc/apparmor.d/local/restrict-appimage-${user}"
        
        # Reload AppArmor if it's active
        if command -v apparmor_parser &> /dev/null; then
            log_debug "Reloading AppArmor profile"
            apparmor_parser -r /etc/apparmor.d/local/restrict-appimage-${user} 2>/dev/null || true
            log_info "Restricted AppImage execution for user $user"
        else
            log_warning "AppArmor not found, cannot fully restrict AppImage for $user"
            log_debug "Attempting alternative restriction method for AppImage"
            
            # Alternative approach: Create a wrapper script for common AppImage extensions
            if [ -d "/usr/local/bin" ]; then
                cat > "/usr/local/bin/appimage-blocker-${user}" << EOF
#!/bin/bash
# Block AppImage execution for user $user
if [ "\$(id -u)" -eq "$user_id" ]; then
    echo "Error: AppImage execution is restricted for this user." >&2
    exit 1
fi
exec "\$@"
EOF
                chmod +x "/usr/local/bin/appimage-blocker-${user}"
                log_debug "Created AppImage blocking script"
            fi
        fi
    elif [ "$action" = "allow" ]; then
        # Remove AppArmor restrictions
        if [ -f "/etc/apparmor.d/local/restrict-appimage-${user}" ]; then
            log_debug "Removing AppArmor restrictions for AppImage"
            rm -f "/etc/apparmor.d/local/restrict-appimage-${user}"
            # Reload AppArmor if it's active
            if command -v apparmor_parser &> /dev/null; then
                log_debug "Reloading AppArmor profiles"
                apparmor_parser -r /etc/apparmor.d/* 2>/dev/null || true
                log_info "Allowed AppImage execution for user $user"
            fi
        else
            log_debug "No AppArmor restriction file found"
        fi
        
        # Remove alternative blocker if it exists
        if [ -f "/usr/local/bin/appimage-blocker-${user}" ]; then
            rm -f "/usr/local/bin/appimage-blocker-${user}"
            log_debug "Removed AppImage blocking script"
        fi
    fi
}

# Apply action to all detected app stores for the specified user
apply_action_to_user() {
    local action=$1
    local user=$2
    
    # Skip if user doesn't exist
    if ! id "$user" &>/dev/null; then
        log_error "User $user does not exist. Skipping."
        return 1
    fi
    
    log_info "Applying $action for user: $user"
    
    for app_store in "${APP_STORES[@]}"; do
        case "$app_store" in
            apt)
                manage_apt_access "$action" "$user"
                ;;
            dnf)
                manage_dnf_yum_access "$action" "$user" "dnf"
                ;;
            yum)
                manage_dnf_yum_access "$action" "$user" "yum"
                ;;
            flatpak)
                manage_flatpak_access "$action" "$user"
                ;;
            snap)
                manage_snap_access "$action" "$user"
                ;;
            gnome-software|ubuntu-software|zorin-software)
                manage_gnome_software_access "$action" "$user"
                ;;
            discover)
                manage_discover_access "$action" "$user"
                ;;
            appimage)
                manage_appimage_access "$action" "$user"
                ;;
        esac
    done
}

# Show current status for all users
show_status() {
    log_info "Current app store access status:"
    
    # List all human users
    local users=$(get_human_users)
    
    echo -e "\n${BLUE}User Access Status:${NC}"
    echo "-------------------"
    
    for user in $users; do
        local status="Allowed"
        
        # Check for any restriction files/settings
        if [ -f "/etc/sudoers.d/restrict-apt-$user" ] || 
           [ -f "/etc/sudoers.d/restrict-dnf-$user" ] || 
           [ -f "/etc/sudoers.d/restrict-yum-$user" ] || 
           [ -f "/etc/sudoers.d/restrict-snap-$user" ] || 
           [ -f "/etc/dconf/db/local.d/00-restrict-software-${user}" ] || 
           [ -f "/etc/polkit-1/rules.d/10-restrict-software-${user}.rules" ] || 
           [ -f "/etc/polkit-1/rules.d/10-restrict-discover-${user}.rules" ] || 
           [ -f "/etc/polkit-1/rules.d/11-restrict-zorin-software-${user}.rules" ] || 
           [ -f "/etc/polkit-1/rules.d/20-restrict-flatpak-${user}.rules" ] || 
           [ -f "/etc/polkit-1/rules.d/20-restrict-snap-${user}.rules" ] || 
           [ -f "/etc/apparmor.d/local/restrict-appimage-${user}" ]; then
            status="Restricted"
        fi
        
        if [ "$user" = "root" ]; then
            echo -e "${user}: ${GREEN}Always Allowed${NC} (root user)"
        else
            if [ "$status" = "Allowed" ]; then
                echo -e "${user}: ${GREEN}$status${NC}"
            else
                echo -e "${user}: ${RED}$status${NC}"
            fi
        fi
        
        if [ "$DEBUG_MODE" = true ]; then
            # Show detailed restriction information
            echo -e "  ${CYAN}Restrictions:${NC}"
            for check in "/etc/sudoers.d/restrict-apt-$user" \
                        "/etc/sudoers.d/restrict-dnf-$user" \
                        "/etc/sudoers.d/restrict-yum-$user" \
                        "/etc/sudoers.d/restrict-snap-$user" \
                        "/etc/dconf/db/local.d/00-restrict-software-${user}" \
                        "/etc/polkit-1/rules.d/10-restrict-software-${user}.rules" \
                        "/etc/polkit-1/rules.d/10-restrict-discover-${user}.rules" \
                        "/etc/polkit-1/rules.d/11-restrict-zorin-software-${user}.rules" \
                        "/etc/polkit-1/rules.d/20-restrict-flatpak-${user}.rules" \
                        "/etc/polkit-1/rules.d/20-restrict-snap-${user}.rules" \
                        "/etc/apparmor.d/local/restrict-appimage-${user}"; do
                if [ -f "$check" ]; then
                    echo -e "    - ${check} ${GREEN}[exists]${NC}"
                else
                    echo -e "    - ${check} ${RED}[missing]${NC}"
                fi
            done
        fi
    done
    
    echo -e "\n${BLUE}Detected Package Managers:${NC}"
    echo "-------------------------"
    for app_store in "${APP_STORES[@]}"; do
        echo "$app_store"
    done
    
    if [ "$DEBUG_MODE" = true ]; then
        echo -e "\n${BLUE}System Information:${NC}"
        echo "-------------------------"
        collect_system_info
        
        echo -e "\n${BLUE}PackageKit Status:${NC}"
        echo "-------------------------"
        systemctl status packagekit 2>&1 || echo "PackageKit service not found"
        
        echo -e "\n${BLUE}PolicyKit Configuration:${NC}"
        echo "-------------------------"
        ls -la /etc/polkit-1/rules.d/ 2>&1 || echo "No PolicyKit rules found"
    fi
}

# Verify that restrictions are applied correctly
verify_restrictions() {
    local user=$1
    
    log_debug "Verifying restrictions for user $user"
    
    # Check dconf settings
    if command -v dconf &> /dev/null; then
        local dconf_value=$(sudo -u "$user" dconf read /org/gnome/software/allow-apps-install 2>/dev/null)
        log_debug "dconf value for allow-apps-install: $dconf_value"
        
        if [ "$dconf_value" = "false" ]; then
            log_debug "GNOME Software installation restriction verified via dconf"
        else
            log_warning "GNOME Software restriction via dconf may not be effective"
        fi
    fi
    
    # Check PolicyKit rules
    for rule_file in "/etc/polkit-1/rules.d/10-restrict-software-${user}.rules" \
                    "/etc/polkit-1/rules.d/11-restrict-zorin-software-${user}.rules"; do
        if [ -f "$rule_file" ]; then
            log_debug "PolicyKit rule file exists: $rule_file"
        else
            log_warning "Expected PolicyKit rule file not found: $rule_file"
        fi
    done
}

# Main function
main() {
    check_root
    
    # Default values
    local action="deny"
    local specific_user=""
    
    # Parse command line arguments
    if [ $# -eq 0 ]; then
        # Default behavior: deny access to all non-root users
        action="deny"
    else
        while [ $# -gt 0 ]; do
            case "$1" in
                --allow)
                    action="allow"
                    shift
                    ;;
                --deny)
                    action="deny"
                    shift
                    ;;
                --status)
                    detect_app_stores
                    show_status
                    exit 0
                    ;;
                --debug)
                    DEBUG_MODE=true
                    log_debug "Debug mode enabled"
                    shift
                    ;;
                --help)
                    print_usage
                    exit 0
                    ;;
                -*)
                    log_error "Unknown option: $1"
                    print_usage
                    exit $ERR_INVALID_ARGS
                    ;;
                *)
                    # Assume the argument is a username
                    specific_user="$1"
                    shift
                    ;;
            esac
        done
    fi
    
    # If debug mode is enabled, collect system information
    if [ "$DEBUG_MODE" = true ]; then
        collect_system_info
    fi
    
    # Detect app stores
    detect_app_stores
    
    if [ -n "$specific_user" ]; then
        # Apply action to specific user
        apply_action_to_user "$action" "$specific_user"
        
        # Verify restrictions if in debug mode
        if [ "$DEBUG_MODE" = true ] && [ "$action" = "deny" ]; then
            verify_restrictions "$specific_user"
        fi
    else
        # Apply action to all non-root human users
        for user in $(get_human_users); do
            apply_action_to_user "$action" "$user"
            
            # Verify restrictions if in debug mode
            if [ "$DEBUG_MODE" = true ] && [ "$action" = "deny" ]; then
                verify_restrictions "$user"
            fi
        done
    fi
    
    log_info "Operation completed successfully."
    
    if [ "$DEBUG_MODE" = true ]; then
        log_debug "Running final verification checks..."
        
        # Additional checks for potential issues
        if grep -q "zorin" /etc/os-release 2>/dev/null; then
            log_debug "Zorin OS detected, checking specific configurations"
            
            # Check if additional services need to be restarted
            for service in "packagekit" "polkit"; do
                if systemctl is-active "$service" &>/dev/null; then
                    log_debug "Restarting $service service"
                    systemctl restart "$service" || log_warning "Failed to restart $service"
                fi
            done
        fi
    fi
}

# Run the main function with all arguments
main "$@" 