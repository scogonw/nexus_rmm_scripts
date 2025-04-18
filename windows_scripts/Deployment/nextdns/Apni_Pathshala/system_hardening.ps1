#Requires -RunAsAdministrator
[CmdletBinding()]
param()

# --- Script Setup ---
$ErrorActionPreference = "Stop" # Stop script on terminating errors
$LogBaseName = "SystemHardening_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
$LogPath = Join-Path -Path $PSScriptRoot -ChildPath "$($LogBaseName).log"

Start-Transcript -Path $LogPath -Append
Write-Information "Starting System Hardening Script. Log file: $LogPath"

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

        [string]$GroupName
    )

    Write-Verbose "Attempting to create user account: $UserName"
    try {
        $securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
        Write-Verbose "Checking if user '$UserName' already exists..."
        if (Get-LocalUser -Name $UserName -ErrorAction SilentlyContinue) {
            Write-Warning "User '$UserName' already exists. Skipping creation."
            # Optionally, update password or group membership here if needed
        } else {
            Write-Information "Creating new local user: '$UserName' with FullName: '$FullName'"
            $user = New-LocalUser -Name $UserName -FullName $FullName -Password $securePassword -PasswordNeverExpires -UserMayNotChangePassword:$false -AccountNeverExpires
            Write-Information "Successfully created user: $UserName"
        }

        # Ensure user exists before attempting to add to group
        $userPrincipal = Get-LocalUser -Name $UserName -ErrorAction SilentlyContinue
        if ($userPrincipal) {
            Write-Verbose "Ensuring user '$UserName' is enabled."
            Enable-LocalUser -Name $UserName
        } else {
             Write-Error "User '$UserName' not found after creation attempt."
             # Decide how to handle this - maybe throw?
        }

        if ($GroupName -and $userPrincipal) {
            Write-Verbose "Checking if user '$($userPrincipal.Name)' (SID: $($userPrincipal.SID.Value)) is already a member of group '$GroupName'..."
            # Use SID for a more reliable membership check
            $isMember = Get-LocalGroupMember -Group $GroupName -Member $userPrincipal.SID.Value -ErrorAction SilentlyContinue

            if ($isMember) {
                 Write-Warning "User '$UserName' is already a member of group '$GroupName'. Skipping add."
            } else {
                 # Check if Get-LocalGroupMember produced an error other than 'PrincipalNotFound'
                 if ($? -eq $false -and $Error[0].Exception.GetType().Name -ne 'PrincipalNotFoundException') {
                    # If another error occurred (e.g., group not found), re-throw it or handle specifically
                    Write-Error "Failed to check membership for user '$UserName' in group '$GroupName': $($Error[0].Exception.Message)"
                    # Decide if script should halt
                    # throw $Error[0]
                 } else {
                    # User is not a member, proceed with adding
                    Write-Information "Adding user '$UserName' to group: '$GroupName'"
                    Add-LocalGroupMember -Group $GroupName -Member $userPrincipal.Name # Use Name property for adding
                    Write-Information "Successfully added '$UserName' to group '$GroupName'."
                 }
            }
        } elseif ($GroupName -and !$userPrincipal) {
             # This condition might be redundant now due to the check above, but kept for clarity
             Write-Error "Cannot add user '$UserName' to group '$GroupName' because the user could not be found."
        }

    } catch {
        # Construct the error message without Out-String -NoNewline
        $groupInfo = if ($GroupName) { " (Group: '$GroupName')" } else { "" }
        Write-Error "Operation failed for user '${UserName}'${groupInfo}: Error: $($_.Exception.Message)"
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
    Write-Information "--- Starting User Account Configuration ---"
    Create-LocalUser -UserName "scogo" -FullName "Scogo IT Support" -Password "Sc090@1947" -GroupName "Administrators"
    Create-LocalUser -UserName "apadmin" -FullName "Apni Pathshala Admin" -Password "@pathshal@1947" -GroupName "Administrators"
    Create-LocalUser -UserName "student" -FullName "Apni Pathshala Student" -Password "Ap@india@1947"
    Write-Information "--- Completed User Account Configuration ---"

    # --- Hostname Configuration ---
    Write-Information "--- Starting Hostname Configuration ---"
    Write-Verbose "Fetching system serial number..."
    $serialNumber = (Get-CimInstance -ClassName Win32_BIOS).SerialNumber
    $currentHostname = $env:COMPUTERNAME

    if (-not [string]::IsNullOrWhiteSpace($serialNumber)) {
        Write-Verbose "Retrieved Serial Number: '$serialNumber'"
        Write-Verbose "Current Hostname: '$currentHostname'"
        if ($currentHostname -ne $serialNumber) {
            Write-Information "Setting hostname to serial number: '$serialNumber'"
            Rename-Computer -NewName $serialNumber -Force
            Write-Information "Hostname change initiated."
            $hostnameChanged = $true
            $restartRequired = $true
        } else {
            Write-Information "Hostname is already set to the serial number ('$serialNumber'). No change needed."
        }
    } else {
        Write-Warning "Could not retrieve a valid system serial number. Skipping hostname change."
    }
    Write-Information "--- Completed Hostname Configuration ---"

} catch {
    Write-Error "An unexpected error occurred during script execution: $($_.Exception.Message)"
    # The script will stop due to $ErrorActionPreference = "Stop"
}

# --- Script Completion ---
Write-Information "Script execution finished."
if ($restartRequired) {
    Write-Warning "IMPORTANT: A system restart is required for the hostname change to take effect."
} else {
    Write-Information "No restart required based on script actions."
}

Stop-Transcript
