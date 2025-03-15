#!/bin/bash

# browser_extension_manager.sh
# Script to manage browser extensions for non-admin users
# Created for Nexus RMM

# Function to display help information
display_help() {
    echo "Browser Extension Manager"
    echo "Usage: sudo $0 [OPTIONS]"
    echo
    echo "This script manages browser extensions for non-admin users."
    echo
    echo "Options:"
    echo "  -h, --help                  Display this help message"
    echo "  -w, --whitelist EXTENSIONS  Comma-separated list of whitelisted extension IDs"
    echo "  -e, --enable                Enable extension installation (default: disabled)"
    echo "  -d, --disable               Disable extension installation"
    echo "  -l, --list                  List currently installed browser extensions"
    echo
    echo "Examples:"
    echo "  sudo $0 --disable                     # Disable all extension installations"
    echo "  sudo $0 --whitelist 'ext1,ext2,ext3'  # Allow only specified extensions"
    echo "  sudo $0 --enable                      # Enable extension installation"
    echo
    echo "Note: This script must be run as root"
    exit 0
}

# Function to check if script is run as root
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "Error: This script must be run as root"
        echo "Please use: sudo $0"
        exit 1
    fi
}

# Function to parse command line arguments
parse_args() {
    WHITELIST=""
    ENABLE_EXTENSIONS=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                display_help
                ;;
            -w|--whitelist)
                WHITELIST="$2"
                shift 2
                ;;
            -e|--enable)
                ENABLE_EXTENSIONS=true
                shift
                ;;
            -d|--disable)
                ENABLE_EXTENSIONS=false
                shift
                ;;
            -l|--list)
                LIST_EXTENSIONS=true
                shift
                ;;
            *)
                echo "Error: Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
}

# Function to detect installed browsers
detect_browsers() {
    BROWSERS=()
    
    # Check for Chrome
    if command -v google-chrome &> /dev/null || command -v google-chrome-stable &> /dev/null; then
        BROWSERS+=("chrome")
    fi
    
    # Check for Chromium
    if command -v chromium &> /dev/null || command -v chromium-browser &> /dev/null; then
        BROWSERS+=("chromium")
    fi
    
    # Check for Firefox
    if command -v firefox &> /dev/null; then
        BROWSERS+=("firefox")
    fi
    
    # Check for Edge
    if command -v microsoft-edge &> /dev/null || command -v microsoft-edge-stable &> /dev/null; then
        BROWSERS+=("edge")
    fi
    
    # Check for Opera
    if command -v opera &> /dev/null; then
        BROWSERS+=("opera")
    fi

    if [ ${#BROWSERS[@]} -eq 0 ]; then
        echo "No supported browsers detected on this system."
        exit 1
    fi

    echo "Detected browsers: ${BROWSERS[*]}"
}

# Function to list installed extensions for each browser
list_extensions() {
    echo "Listing installed extensions:"
    
    for browser in "${BROWSERS[@]}"; do
        echo "[$browser]"
        case "$browser" in
            chrome|chromium|edge)
                list_chromium_extensions "$browser"
                ;;
            firefox)
                list_firefox_extensions
                ;;
            opera)
                list_opera_extensions
                ;;
        esac
        echo ""
    done
}

# List extensions for Chrome/Chromium/Edge
list_chromium_extensions() {
    local browser="$1"
    local browser_name
    
    case "$browser" in
        chrome) browser_name="Google Chrome" ;;
        chromium) browser_name="Chromium" ;;
        edge) browser_name="Microsoft Edge" ;;
    esac
    
    # Define extension directories for different browsers
    local extension_dirs=()
    
    # System-wide extensions
    if [ -d "/usr/share/$browser/extensions" ]; then
        extension_dirs+=("/usr/share/$browser/extensions")
    fi
    
    # User extensions
    for user_home in /home/*; do
        if [ -d "$user_home" ]; then
            username=$(basename "$user_home")
            
            case "$browser" in
                chrome)
                    if [ -d "$user_home/.config/google-chrome/Default/Extensions" ]; then
                        extension_dirs+=("$user_home/.config/google-chrome/Default/Extensions")
                    fi
                    ;;
                chromium)
                    if [ -d "$user_home/.config/chromium/Default/Extensions" ]; then
                        extension_dirs+=("$user_home/.config/chromium/Default/Extensions")
                    fi
                    ;;
                edge)
                    if [ -d "$user_home/.config/microsoft-edge/Default/Extensions" ]; then
                        extension_dirs+=("$user_home/.config/microsoft-edge/Default/Extensions")
                    fi
                    ;;
            esac
        fi
    done
    
    # List extensions
    for dir in "${extension_dirs[@]}"; do
        if [ -d "$dir" ]; then
            echo "Extensions in $dir:"
            for ext in "$dir"/*; do
                if [ -d "$ext" ]; then
                    ext_id=$(basename "$ext")
                    echo "  ID: $ext_id"
                fi
            done
        fi
    done
}

# List extensions for Firefox
list_firefox_extensions() {
    # For each user profile
    for user_home in /home/*; do
        if [ -d "$user_home" ]; then
            username=$(basename "$user_home")
            
            # Find Firefox profiles
            if [ -d "$user_home/.mozilla/firefox" ]; then
                echo "Firefox extensions for user $username:"
                
                # Look for each profile
                for profile in "$user_home/.mozilla/firefox/"*.default* "$user_home/.mozilla/firefox/"*.normal*; do
                    if [ -d "$profile/extensions" ]; then
                        echo "  Profile: $(basename "$profile")"
                        for ext in "$profile/extensions"/*; do
                            if [ -f "$ext" ] || [ -d "$ext" ]; then
                                ext_id=$(basename "$ext")
                                echo "    ID: $ext_id"
                            fi
                        done
                    fi
                done
            fi
        fi
    done
}

# List extensions for Opera
list_opera_extensions() {
    for user_home in /home/*; do
        if [ -d "$user_home" ]; then
            username=$(basename "$user_home")
            
            if [ -d "$user_home/.config/opera/Extensions" ]; then
                echo "Opera extensions for user $username:"
                for ext in "$user_home/.config/opera/Extensions"/*; do
                    if [ -d "$ext" ]; then
                        ext_id=$(basename "$ext")
                        echo "  ID: $ext_id"
                    fi
                done
            fi
        fi
    done
}

# Function to manage Chrome/Chromium/Edge extensions
manage_chromium_extensions() {
    local browser="$1"
    local browser_name
    local policies_dir
    local managed_policies_file
    
    case "$browser" in
        chrome)
            browser_name="Google Chrome"
            policies_dir="/etc/opt/chrome/policies/managed"
            managed_policies_file="$policies_dir/extension_settings.json"
            ;;
        chromium)
            browser_name="Chromium"
            policies_dir="/etc/chromium/policies/managed"
            managed_policies_file="$policies_dir/extension_settings.json"
            ;;
        edge)
            browser_name="Microsoft Edge"
            policies_dir="/etc/opt/edge/policies/managed"
            managed_policies_file="$policies_dir/extension_settings.json"
            ;;
    esac
    
    echo "Configuring $browser_name extensions..."
    
    # Create the policies directory if it doesn't exist
    mkdir -p "$policies_dir"
    
    # Determine policy based on input parameters
    if $ENABLE_EXTENSIONS; then
        echo "Enabling extension installation for $browser_name"
        cat > "$managed_policies_file" << EOF
{
    "ExtensionInstallBlocklist": [],
    "ExtensionInstallAllowlist": ["*"]
}
EOF
    else
        if [ -n "$WHITELIST" ]; then
            echo "Configuring whitelist for $browser_name: $WHITELIST"
            
            # Create JSON with whitelisted extensions
            echo "{" > "$managed_policies_file"
            echo "    \"ExtensionInstallBlocklist\": [\"*\"]," >> "$managed_policies_file"
            echo -n "    \"ExtensionInstallAllowlist\": [" >> "$managed_policies_file"
            
            # Convert comma-separated list to JSON array
            IFS=',' read -ra EXTS <<< "$WHITELIST"
            for i in "${!EXTS[@]}"; do
                if [ $i -gt 0 ]; then
                    echo -n ", " >> "$managed_policies_file"
                fi
                echo -n "\"${EXTS[$i]}\"" >> "$managed_policies_file"
            done
            
            echo "]" >> "$managed_policies_file"
            echo "}" >> "$managed_policies_file"
        else
            echo "Disabling all extension installations for $browser_name"
            cat > "$managed_policies_file" << EOF
{
    "ExtensionInstallBlocklist": ["*"],
    "ExtensionInstallAllowlist": []
}
EOF
        fi
    fi
    
    # Set correct permissions
    chmod 644 "$managed_policies_file"
    
    echo "Successfully configured $browser_name extension policies."
}

# Function to manage Firefox extensions
manage_firefox_extensions() {
    local policies_dir="/usr/lib/firefox/distribution"
    local managed_policies_file="$policies_dir/policies.json"
    
    echo "Configuring Firefox extensions..."
    
    # Create the policies directory if it doesn't exist
    mkdir -p "$policies_dir"
    
    # Determine policy based on input parameters
    if $ENABLE_EXTENSIONS; then
        echo "Enabling extension installation for Firefox"
        cat > "$managed_policies_file" << EOF
{
  "policies": {
    "ExtensionSettings": {
      "*": {
        "installation_mode": "allowed"
      }
    }
  }
}
EOF
    else
        if [ -n "$WHITELIST" ]; then
            echo "Configuring whitelist for Firefox: $WHITELIST"
            
            # Start JSON structure
            cat > "$managed_policies_file" << EOF
{
  "policies": {
    "ExtensionSettings": {
      "*": {
        "installation_mode": "blocked"
      },
EOF
            
            # Convert comma-separated list to JSON object entries
            IFS=',' read -ra EXTS <<< "$WHITELIST"
            for i in "${!EXTS[@]}"; do
                if [ $i -gt 0 ]; then
                    echo "      ," >> "$managed_policies_file"
                fi
                cat >> "$managed_policies_file" << EOF
      "${EXTS[$i]}": {
        "installation_mode": "allowed"
      }
EOF
            done
            
            # Close JSON structure
            cat >> "$managed_policies_file" << EOF
    }
  }
}
EOF
        else
            echo "Disabling all extension installations for Firefox"
            cat > "$managed_policies_file" << EOF
{
  "policies": {
    "ExtensionSettings": {
      "*": {
        "installation_mode": "blocked"
      }
    }
  }
}
EOF
        fi
    fi
    
    # Set correct permissions
    chmod 644 "$managed_policies_file"
    
    echo "Successfully configured Firefox extension policies."
}

# Function to manage Opera extensions
manage_opera_extensions() {
    local policies_dir="/etc/opt/opera/policies/managed"
    local managed_policies_file="$policies_dir/extension_settings.json"
    
    echo "Configuring Opera extensions..."
    
    # Create the policies directory if it doesn't exist
    mkdir -p "$policies_dir"
    
    # Determine policy based on input parameters
    if $ENABLE_EXTENSIONS; then
        echo "Enabling extension installation for Opera"
        cat > "$managed_policies_file" << EOF
{
    "ExtensionInstallBlocklist": [],
    "ExtensionInstallAllowlist": ["*"]
}
EOF
    else
        if [ -n "$WHITELIST" ]; then
            echo "Configuring whitelist for Opera: $WHITELIST"
            
            # Create JSON with whitelisted extensions
            echo "{" > "$managed_policies_file"
            echo "    \"ExtensionInstallBlocklist\": [\"*\"]," >> "$managed_policies_file"
            echo -n "    \"ExtensionInstallAllowlist\": [" >> "$managed_policies_file"
            
            # Convert comma-separated list to JSON array
            IFS=',' read -ra EXTS <<< "$WHITELIST"
            for i in "${!EXTS[@]}"; do
                if [ $i -gt 0 ]; then
                    echo -n ", " >> "$managed_policies_file"
                fi
                echo -n "\"${EXTS[$i]}\"" >> "$managed_policies_file"
            done
            
            echo "]" >> "$managed_policies_file"
            echo "}" >> "$managed_policies_file"
        else
            echo "Disabling all extension installations for Opera"
            cat > "$managed_policies_file" << EOF
{
    "ExtensionInstallBlocklist": ["*"],
    "ExtensionInstallAllowlist": []
}
EOF
        fi
    fi
    
    # Set correct permissions
    chmod 644 "$managed_policies_file"
    
    echo "Successfully configured Opera extension policies."
}

# Apply extension management to all detected browsers
apply_extension_management() {
    for browser in "${BROWSERS[@]}"; do
        case "$browser" in
            chrome)
                manage_chromium_extensions "chrome"
                ;;
            chromium)
                manage_chromium_extensions "chromium"
                ;;
            edge)
                manage_chromium_extensions "edge"
                ;;
            firefox)
                manage_firefox_extensions
                ;;
            opera)
                manage_opera_extensions
                ;;
        esac
    done
    
    echo "Extension management applied successfully to all detected browsers."
}

# Main execution
main() {
    check_root
    parse_args "$@"
    detect_browsers
    
    if [ "$LIST_EXTENSIONS" = true ]; then
        list_extensions
        exit 0
    fi
    
    apply_extension_management
}

main "$@" 