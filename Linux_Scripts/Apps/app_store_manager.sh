#!/bin/bash

# app_store_manager.sh
# 
# This script manages app store access permissions for non-root users
# on Linux systems supporting various package managers and app stores.
#
# Author: Nexus RMM Team
# Created: $(date +"%Y-%m-%d")
# License: MIT

# Error codes
ERR_NOT_ROOT=1
ERR_INVALID_ARGS=2
ERR_UNSUPPORTED_SYSTEM=3

# Color codes for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
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
    echo "  --help            Display this help message"
    echo
    echo -e "${BLUE}Arguments:${NC}"
    echo "  USERNAME          Optional: Specify a user to modify. If omitted, applies to all non-root users."
    echo
    echo -e "${YELLOW}Note:${NC} This script must be run as root."
    echo
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

# Detect installed app stores/package managers
detect_app_stores() {
    log_info "Detecting installed package managers and app stores..."
    
    APP_STORES=()
    
    # Check for APT (Debian/Ubuntu)
    if command -v apt &> /dev/null; then
        APP_STORES+=("apt")
    fi
    
    # Check for DNF (Fedora/RHEL)
    if command -v dnf &> /dev/null; then
        APP_STORES+=("dnf")
    fi
    
    # Check for YUM (CentOS/RHEL)
    if command -v yum &> /dev/null; then
        APP_STORES+=("yum")
    fi
    
    # Check for Flatpak
    if command -v flatpak &> /dev/null; then
        APP_STORES+=("flatpak")
    fi
    
    # Check for Snap
    if command -v snap &> /dev/null; then
        APP_STORES+=("snap")
    fi
    
    # Check for GNOME Software
    if command -v gnome-software &> /dev/null; then
        APP_STORES+=("gnome-software")
    fi
    
    # Check for Discover (KDE)
    if command -v plasma-discover &> /dev/null; then
        APP_STORES+=("discover")
    fi
    
    # Check for AppImage support (basic check)
    if [ -d "/usr/local/bin" ]; then
        APP_STORES+=("appimage")
    fi
    
    # Check for Ubuntu Software Center
    if command -v software-center &> /dev/null || command -v ubuntu-software &> /dev/null; then
        APP_STORES+=("ubuntu-software")
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
    awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd
}

# Manage APT permissions
manage_apt_access() {
    local action=$1
    local user=$2
    
    if [ "$action" = "deny" ]; then
        # Create a sudoers rule to prevent apt/apt-get/aptitude commands
        local rule="$user ALL=(ALL) !NOPASSWD: /usr/bin/apt*, /usr/bin/apt-get*, /usr/bin/aptitude*"
        echo "$rule" > "/etc/sudoers.d/restrict-apt-$user"
        chmod 0440 "/etc/sudoers.d/restrict-apt-$user"
        log_info "Restricted APT access for user $user"
    elif [ "$action" = "allow" ]; then
        # Remove the restriction file if it exists
        if [ -f "/etc/sudoers.d/restrict-apt-$user" ]; then
            rm -f "/etc/sudoers.d/restrict-apt-$user"
            log_info "Allowed APT access for user $user"
        fi
    fi
}

# Manage DNF/YUM permissions
manage_dnf_yum_access() {
    local action=$1
    local user=$2
    local pkg_mgr=$3  # dnf or yum
    
    if [ "$action" = "deny" ]; then
        # Create a sudoers rule to prevent dnf/yum commands
        local rule="$user ALL=(ALL) !NOPASSWD: /usr/bin/$pkg_mgr*"
        echo "$rule" > "/etc/sudoers.d/restrict-$pkg_mgr-$user"
        chmod 0440 "/etc/sudoers.d/restrict-$pkg_mgr-$user"
        log_info "Restricted $pkg_mgr access for user $user"
    elif [ "$action" = "allow" ]; then
        # Remove the restriction file if it exists
        if [ -f "/etc/sudoers.d/restrict-$pkg_mgr-$user" ]; then
            rm -f "/etc/sudoers.d/restrict-$pkg_mgr-$user"
            log_info "Allowed $pkg_mgr access for user $user"
        fi
    fi
}

# Manage Flatpak permissions
manage_flatpak_access() {
    local action=$1
    local user=$2
    
    if [ "$action" = "deny" ]; then
        # Remove execute permissions from flatpak for the user group
        if getent group flatpak > /dev/null 2>&1; then
            gpasswd -d "$user" flatpak &> /dev/null || true
        else
            # Create a flatpak group if it doesn't exist
            groupadd flatpak
        fi
        
        # Change permissions on flatpak binary
        if [ -f "/usr/bin/flatpak" ]; then
            chown root:flatpak /usr/bin/flatpak
            chmod 750 /usr/bin/flatpak
            log_info "Restricted Flatpak access for user $user"
        fi
    elif [ "$action" = "allow" ]; then
        # Add user to flatpak group
        if getent group flatpak > /dev/null 2>&1; then
            gpasswd -a "$user" flatpak &> /dev/null
            log_info "Allowed Flatpak access for user $user"
        else
            log_warning "Flatpak group doesn't exist, creating and adding user"
            groupadd flatpak
            gpasswd -a "$user" flatpak &> /dev/null
        fi
    fi
}

# Manage Snap permissions
manage_snap_access() {
    local action=$1
    local user=$2
    
    if [ "$action" = "deny" ]; then
        # Create a sudoers rule to prevent snap commands
        local rule="$user ALL=(ALL) !NOPASSWD: /usr/bin/snap*"
        echo "$rule" > "/etc/sudoers.d/restrict-snap-$user"
        chmod 0440 "/etc/sudoers.d/restrict-snap-$user"
        
        # Restrict access to snap socket
        if [ -d "/var/lib/snapd/snap" ]; then
            setfacl -m "u:$user:r--" /var/lib/snapd/snap 2>/dev/null || chmod o-w /var/lib/snapd/snap
        fi
        log_info "Restricted Snap access for user $user"
    elif [ "$action" = "allow" ]; then
        # Remove the restriction file if it exists
        if [ -f "/etc/sudoers.d/restrict-snap-$user" ]; then
            rm -f "/etc/sudoers.d/restrict-snap-$user"
        fi
        
        # Restore access to snap socket if needed
        if [ -d "/var/lib/snapd/snap" ]; then
            setfacl -x "u:$user" /var/lib/snapd/snap 2>/dev/null || chmod o+w /var/lib/snapd/snap
        fi
        log_info "Allowed Snap access for user $user"
    fi
}

# Manage GNOME Software and Ubuntu Software Center
manage_gnome_software_access() {
    local action=$1
    local user=$2
    
    if [ "$action" = "deny" ]; then
        # Create dconf restriction for user
        mkdir -p "/etc/dconf/profile"
        echo "user-db:user" > "/etc/dconf/profile/$user"
        echo "system-db:local" >> "/etc/dconf/profile/$user"
        
        mkdir -p "/etc/dconf/db/local.d"
        cat > "/etc/dconf/db/local.d/00-restrict-software-${user}" << EOF
[org.gnome.software]
allow-updates=false
download-updates=false
allow-apps-install=false

[org.gnome.desktop.app-folders]
folder-children=['Utilities', 'YaST']
EOF
        
        dconf update
        log_info "Restricted GNOME Software/Ubuntu Software Center access for user $user"
    elif [ "$action" = "allow" ]; then
        # Remove restrictions
        if [ -f "/etc/dconf/db/local.d/00-restrict-software-${user}" ]; then
            rm -f "/etc/dconf/db/local.d/00-restrict-software-${user}"
            dconf update
            log_info "Allowed GNOME Software/Ubuntu Software Center access for user $user"
        fi
    fi
}

# Manage KDE Discover
manage_discover_access() {
    local action=$1
    local user=$2
    
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
        log_info "Restricted KDE Discover access for user $user"
    elif [ "$action" = "allow" ]; then
        # Remove restrictions
        if [ -f "/etc/polkit-1/rules.d/10-restrict-discover-${user}.rules" ]; then
            rm -f "/etc/polkit-1/rules.d/10-restrict-discover-${user}.rules"
            log_info "Allowed KDE Discover access for user $user"
        fi
    fi
}

# Manage AppImage execution permissions
manage_appimage_access() {
    local action=$1
    local user=$2
    
    # Get the numeric user ID
    local user_id=$(id -u "$user" 2>/dev/null)
    
    if [ "$action" = "deny" ]; then
        # Create a security module to prevent AppImage execution
        mkdir -p "/etc/apparmor.d/local"
        cat > "/etc/apparmor.d/local/restrict-appimage-${user}" << EOF
# Restrict AppImage execution for user $user
deny owner uid=$user_id /**/*.AppImage mrwklx,
EOF
        
        # Reload AppArmor if it's active
        if command -v apparmor_parser &> /dev/null; then
            apparmor_parser -r /etc/apparmor.d/local/restrict-appimage-${user} 2>/dev/null || true
            log_info "Restricted AppImage execution for user $user"
        else
            log_warning "AppArmor not found, cannot fully restrict AppImage for $user"
        fi
    elif [ "$action" = "allow" ]; then
        # Remove AppArmor restrictions
        if [ -f "/etc/apparmor.d/local/restrict-appimage-${user}" ]; then
            rm -f "/etc/apparmor.d/local/restrict-appimage-${user}"
            # Reload AppArmor if it's active
            if command -v apparmor_parser &> /dev/null; then
                apparmor_parser -r /etc/apparmor.d/* 2>/dev/null || true
                log_info "Allowed AppImage execution for user $user"
            fi
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
            gnome-software|ubuntu-software)
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
           [ -f "/etc/polkit-1/rules.d/10-restrict-discover-${user}.rules" ] || 
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
    done
    
    echo -e "\n${BLUE}Detected Package Managers:${NC}"
    echo "-------------------------"
    for app_store in "${APP_STORES[@]}"; do
        echo "$app_store"
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
        case "$1" in
            --allow)
                action="allow"
                if [ -n "$2" ]; then
                    specific_user="$2"
                fi
                ;;
            --deny)
                action="deny"
                if [ -n "$2" ]; then
                    specific_user="$2"
                fi
                ;;
            --status)
                detect_app_stores
                show_status
                exit 0
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
                # Assume the first argument is a username
                specific_user="$1"
                ;;
        esac
    fi
    
    # Detect app stores
    detect_app_stores
    
    if [ -n "$specific_user" ]; then
        # Apply action to specific user
        apply_action_to_user "$action" "$specific_user"
    else
        # Apply action to all non-root human users
        for user in $(get_human_users); do
            apply_action_to_user "$action" "$user"
        done
    fi
    
    log_info "Operation completed successfully."
}

# Run the main function with all arguments
main "$@" 