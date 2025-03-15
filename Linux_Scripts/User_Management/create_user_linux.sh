#!/bin/bash

# ===================================================================
# Create User Script for Linux
# ===================================================================
# Description: Creates a new user account on Linux systems with proper
#              security settings and configuration options.
# Author: Nexus RMM Team
# Date: $(date +%Y-%m-%d)
# Version: 1.0
# ===================================================================

# Log file setup
LOG_DIR="/var/log/nexus_rmm"
LOG_FILE="$LOG_DIR/user_management.log"

# Function for logging
log() {
    local log_type="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Create log directory if it doesn't exist
    if [ ! -d "$LOG_DIR" ]; then
        mkdir -p "$LOG_DIR" >/dev/null 2>&1
        if [ $? -ne 0 ]; then
            echo "ERROR: Cannot create log directory. Logging to stdout only."
            LOG_FILE="/dev/stdout"
        fi
    fi
    
    echo "$timestamp [$log_type] $message" | tee -a "$LOG_FILE"
}

# Check if running with root privileges
if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: This script must be run as root or with sudo privileges."
    log "ERROR" "Script execution attempted without root privileges"
    exit 1
fi

# Display usage information
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Creates a new user account with the specified settings"
    echo
    echo "Options:"
    echo "  -u, --username USERNAME     Username for the new account (required)"
    echo "  -f, --fullname \"FULL NAME\"  Full name for the user (optional)"
    echo "  -a, --admin                 Add user to sudo group (optional)"
    echo "  -h, --help                  Display this help and exit"
    echo
    echo "Example:"
    echo "  $0 -u jdoe -f \"John Doe\" -a"
    exit 1
}

# Parse command line arguments
username=""
fullname=""
admin_user=false

# Improved parameter parsing - more robust handling
while [ $# -gt 0 ]; do
    case "$1" in
        -u|--username)
            if [ -n "$2" ] && [ "${2:0:1}" != "-" ]; then
                username="$2"
                shift 2
            else
                echo "ERROR: Option -u|--username requires an argument."
                log "ERROR" "Missing argument for -u|--username option"
                usage
            fi
            ;;
        -f|--fullname)
            if [ -n "$2" ]; then
                fullname="$2"
                shift 2
            else
                echo "ERROR: Option -f|--fullname requires an argument."
                log "ERROR" "Missing argument for -f|--fullname option"
                usage
            fi
            ;;
        -a|--admin)
            admin_user=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        -*)
            echo "ERROR: Unknown option: $1"
            log "ERROR" "Unknown option: $1"
            usage
            ;;
        *)
            echo "ERROR: Unknown argument: $1"
            log "ERROR" "Unknown argument: $1"
            usage
            ;;
    esac
done

# Validate required parameters
if [ -z "$username" ]; then
    echo "ERROR: Username is required"
    log "ERROR" "Username not provided"
    usage
fi

# Validate username format (only allow alphanumeric and underscore)
if ! [[ "$username" =~ ^[a-zA-Z0-9_]+$ ]]; then
    echo "ERROR: Username can only contain letters, numbers, and underscores"
    log "ERROR" "Invalid username format: $username"
    exit 1
fi

# Check if user already exists
if id "$username" >/dev/null 2>&1; then
    echo "ERROR: User '$username' already exists"
    log "ERROR" "Attempted to create duplicate user: $username"
    exit 1
fi

# Set default password
password="scogo@007"
log "INFO" "Using default password for new user $username"

# Detect Linux distribution for group differences
if [ -f /etc/os-release ]; then
    . /etc/os-release
    distro="$ID"
else
    distro="unknown"
fi

# Determine admin group based on distribution
admin_group=""
case "$distro" in
    ubuntu|debian|linuxmint)
        admin_group="sudo"
        ;;
    fedora|rhel|centos|rocky|almalinux)
        admin_group="wheel"
        ;;
    *)
        # Try to detect common groups
        if grep -q "^sudo:" /etc/group; then
            admin_group="sudo"
        elif grep -q "^wheel:" /etc/group; then
            admin_group="wheel"
        else
            log "WARNING" "Could not determine admin group for distribution: $distro"
            admin_group="sudo"  # Default fallback
        fi
        ;;
esac

# Create user with home directory and bash shell
if [ -n "$fullname" ]; then
    log "INFO" "Creating user $username with full name: $fullname"
    useradd -m -s /bin/bash -c "$fullname" "$username"
else
    log "INFO" "Creating user $username"
    useradd -m -s /bin/bash "$username"
fi

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to create user $username"
    log "ERROR" "User creation failed: $username"
    exit 1
fi

# Set the password
echo "$username:$password" | chpasswd
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to set password for user $username"
    log "ERROR" "Password setup failed for user: $username"
    exit 1
fi

# Force password change on first login
passwd -e "$username"
if [ $? -ne 0 ]; then
    echo "WARNING: Failed to expire password for user $username"
    log "WARNING" "Password expiration failed for user: $username"
fi

# Add to admin group if requested
if [ "$admin_user" = true ]; then
    usermod -aG "$admin_group" "$username"
    if [ $? -ne 0 ]; then
        echo "WARNING: Failed to add user $username to $admin_group group"
        log "WARNING" "Failed to add user $username to $admin_group group"
    else
        log "INFO" "Added user $username to $admin_group group"
    fi
fi

echo "SUCCESS: User $username created successfully."
log "INFO" "User $username created successfully with home directory /home/$username"

# Display summary
echo "User details:"
echo "  Username: $username"
echo "  Home directory: /home/$username"
echo "  Shell: /bin/bash"
if [ "$admin_user" = true ]; then
    echo "  Admin privileges: Yes ($admin_group group)"
else
    echo "  Admin privileges: No"
fi
echo "  Password: Default password set (scogo@007)"
echo "  Password status: Must be changed at first login" 