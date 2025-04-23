#Requires -RunAsAdministrator
[CmdletBinding()]
param()

# --- Script Setup ---
$ErrorActionPreference = "Stop" # Stop script on terminating errors
# Ensure Information messages are visible on console
$InformationPreference = "Continue"
$VerbosePreference = "Continue"

# Setup timestamp function for logging
function Get-TimeStamp {
    return "[{0:yyyy-MM-dd HH:mm:ss}]" -f (Get-Date)
}

# Custom logging functions
function Write-LogInfo {
    param([string]$Message)
    Write-Information "$(Get-TimeStamp) [INFO] $Message"
}

function Write-LogSuccess {
    param([string]$Message)
    Write-Information "$(Get-TimeStamp) [SUCCESS] $Message" 
}

function Write-LogWarning {
    param([string]$Message)
    Write-Warning "$(Get-TimeStamp) [WARNING] $Message"
}

function Write-LogError {
    param([string]$Message)
    Write-Error "$(Get-TimeStamp) [ERROR] $Message"
}

function Write-LogSkipped {
    param([string]$Message)
    Write-Information "$(Get-TimeStamp) [SKIPPED] $Message"
}

Write-LogInfo "Starting System Hardening Script. Output will be displayed on the console."

# --- Function Definitions ---

# Function to create a local user and add to a group if specified
function Create-LocalUser {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$UserName,

        [Parameter(Mandatory=$true)]
        [string]$FullName,

        [Parameter(Mandatory=$true)]
        [string]$Password,

        [string]$GroupName,

        [bool]$UserMayNotChangePassword = $false
    )

    Write-Verbose "Attempting to create user account: $UserName"
    try {
        $securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
        Write-Verbose "Checking if user '$UserName' already exists..."
        if (Get-LocalUser -Name $UserName -ErrorAction SilentlyContinue) {
            Write-LogSkipped "User '$UserName' already exists. Skipping creation."
            # Optionally, update password or group membership here if needed
        } else {
            Write-LogInfo "Creating new local user: '$UserName' with FullName: '$FullName'"
            $user = New-LocalUser -Name $UserName -FullName $FullName -Password $securePassword -PasswordNeverExpires -UserMayNotChangePassword:$UserMayNotChangePassword -AccountNeverExpires
            Write-LogSuccess "Created user: $UserName"
        }

        # Ensure user exists before attempting to add to group
        $userPrincipal = Get-LocalUser -Name $UserName -ErrorAction SilentlyContinue
        if ($userPrincipal) {
            Write-Verbose "Ensuring user '$UserName' is enabled."
            Enable-LocalUser -Name $UserName
            Write-LogSuccess "Enabled user '$UserName'."
        } else {
             Write-LogError "User '$UserName' not found after creation attempt."
             # Decide how to handle this - maybe throw?
        }

        if ($GroupName -and $userPrincipal) {
            Write-Verbose "Checking if user '$($userPrincipal.Name)' (SID: $($userPrincipal.SID.Value)) is already a member of group '$GroupName'..."
            # Use SID for a more reliable membership check
            $isMember = Get-LocalGroupMember -Group $GroupName -Member $userPrincipal.SID.Value -ErrorAction SilentlyContinue

            if ($isMember) {
                 Write-LogSkipped "User '$UserName' is already a member of group '$GroupName'. Skipping add."
            } else {
                 # Check if Get-LocalGroupMember produced an error other than 'PrincipalNotFound'
                 if ($? -eq $false -and $Error[0].Exception.GetType().Name -ne 'PrincipalNotFoundException') {
                    # If another error occurred (e.g., group not found), re-throw it or handle specifically
                    Write-LogError "Failed to check membership for user '$UserName' in group '$GroupName': $($Error[0].Exception.Message)"
                    # Decide if script should halt
                    # throw $Error[0]
                 } else {
                    # User is not a member, proceed with adding
                    Write-LogInfo "Adding user '$UserName' to group: '$GroupName'"
                    Add-LocalGroupMember -Group $GroupName -Member $userPrincipal.Name # Use Name property for adding
                    Write-LogSuccess "Added '$UserName' to group '$GroupName'."
                 }
            }
        } elseif ($GroupName -and !$userPrincipal) {
             # This condition might be redundant now due to the check above, but kept for clarity
             Write-LogError "Cannot add user '$UserName' to group '$GroupName' because the user could not be found."
        }

    } catch {
        # Construct the error message without Out-String -NoNewline
        $groupInfo = if ($GroupName) { " (Group: '$GroupName')" } else { "" }
        Write-LogError "Operation failed for user '${UserName}'${groupInfo}: Error: $($_.Exception.Message)"
        # Consider if the script should stop entirely here or continue with other users.
        # throw $_ # Uncomment to stop script execution on failure within this function
    }
}

# --- Main Execution Block ---

$hostnameChanged = $false
$restartRequired = $false

# Wrap main logic in a try/catch for overall script error reporting
try {
    # --- User Creation ---
    Write-LogInfo "=== Starting User Account Configuration ==="
    Write-LogInfo "Starting user creation calls."
    
    Write-LogInfo "Processing user 'scogo'..."
    Create-LocalUser -UserName "scogo" -FullName "Scogo IT Support" -Password "Sc090@1947" -GroupName "Administrators"
    Write-LogInfo "Completed processing user 'scogo'."
    
    Write-LogInfo "Processing user 'apadmin'..."
    Create-LocalUser -UserName "apadmin" -FullName "Apni Pathshala Admin" -Password "@pathshala@1947" -GroupName "Administrators" -UserMayNotChangePassword:$true
    Write-LogInfo "Completed processing user 'apadmin'."
    
    Write-LogInfo "Processing user 'student'..."
    Create-LocalUser -UserName "student" -FullName "Apni Pathshala Student" -Password "Ap@india@1947" -GroupName "Users" -UserMayNotChangePassword:$true
    Write-LogInfo "Completed processing user 'student'."
    
    Write-LogInfo "Finished all user creation calls."
    Write-LogSuccess "=== Completed User Account Configuration ==="

    # --- Hostname Configuration ---
    Write-LogInfo "=== Starting Hostname Configuration ==="
    Write-Verbose "Fetching system serial number..."
    try {
        $serialNumber = (Get-CimInstance -ClassName Win32_BIOS).SerialNumber
        $currentHostname = $env:COMPUTERNAME
        Write-LogInfo "Retrieved system information successfully."

        if (-not [string]::IsNullOrWhiteSpace($serialNumber)) {
            Write-Verbose "Retrieved Serial Number: '$serialNumber'"
            Write-Verbose "Current Hostname: '$currentHostname'"
            Write-LogSuccess "Successfully retrieved Serial Number: '$serialNumber' and Current Hostname: '$currentHostname'"
            
            if ($currentHostname -ne $serialNumber) {
                Write-LogInfo "Setting hostname to serial number: '$serialNumber'"
                try {
                    Rename-Computer -NewName $serialNumber -Force
                    Write-LogSuccess "Hostname change initiated to '$serialNumber'."
                    $hostnameChanged = $true
                    $restartRequired = $true
                }
                catch {
                    Write-LogError "Failed to rename computer to '$serialNumber': $($_.Exception.Message)"
                }
            } else {
                Write-LogSkipped "Hostname is already set to the serial number ('$serialNumber'). No change needed."
            }
        } else {
            Write-LogWarning "Could not retrieve a valid system serial number. Skipping hostname change."
        }
    }
    catch {
        Write-LogError "Failed to retrieve system information: $($_.Exception.Message)"
    }
    Write-LogInfo "=== Completed Hostname Configuration ==="

} catch {
    Write-LogError "A critical error halted script execution in the main block: $($_.Exception.Message) | Error details: $_"
    # The script will stop due to $ErrorActionPreference = "Stop"
}

# --- Script Completion ---
Write-LogInfo "Script execution finished."

# Create summary report
Write-LogInfo "=== System Hardening Summary ==="
if ($hostnameChanged) {
    Write-LogSuccess "Hostname changed to system serial number."
} else {
    if ([string]::IsNullOrWhiteSpace($serialNumber)) {
        Write-LogWarning "Hostname not changed - Could not retrieve system serial number."
    } else {
        Write-LogInfo "Hostname already matched system serial number. No change required."
    }
}

if ($restartRequired) {
    Write-LogWarning "IMPORTANT: A system restart is required for the hostname change to take effect."
} else {
    Write-LogInfo "No restart required based on script actions."
}
Write-LogInfo "=== End of System Hardening Summary ==="
