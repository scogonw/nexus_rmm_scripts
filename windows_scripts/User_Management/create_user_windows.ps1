#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Creates a new local user account on Windows systems with proper security settings.

.DESCRIPTION
    This script creates a new local user account with options to set full name and add
    the user to the local administrators group. The password will be configured to require
    a change at the first login for better security.

.PARAMETER Username
    The username for the new account (required).

.PARAMETER FullName
    The full name for the user account (optional).

.PARAMETER IsAdmin
    Switch parameter to add the user to the local administrators group (optional).

.NOTES
    Filename:       create_user_windows.ps1
    Author:         Nexus RMM Team
    Date:           $(Get-Date -Format "yyyy-MM-dd")
    Version:        1.0
    Requirements:   - Windows 7 or later
                    - Administrator privileges
                    - PowerShell 3.0 or later

.EXAMPLE
    .\create_user_windows.ps1 -Username jsmith -FullName "John Smith"

.EXAMPLE
    .\create_user_windows.ps1 -Username jsmith -FullName "John Smith" -IsAdmin
#>

# Script parameters
param(
    [Parameter(Mandatory = $true, HelpMessage = "Username for the new account")]
    [ValidatePattern("^[a-zA-Z0-9_]+$")]
    [string]$Username,

    [Parameter(Mandatory = $false, HelpMessage = "Full name for the user")]
    [string]$FullName = "",

    [Parameter(Mandatory = $false, HelpMessage = "Add user to administrators group")]
    [switch]$IsAdmin = $false
)

# Setup logging
$LogDir = "$env:ProgramData\Nexus_RMM\Logs"
$LogFile = "$LogDir\user_management.log"

# Ensure log directory exists
if (-not (Test-Path -Path $LogDir)) {
    try {
        New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
    } catch {
        Write-Warning "Failed to create log directory. Logs will be written to temp directory."
        $LogDir = $env:TEMP
        $LogFile = "$LogDir\nexus_user_management.log"
    }
}

# Function for logging
function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Type,
        
        [Parameter(Mandatory = $true)]
        [string]$Message
    )
    
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "$Timestamp [$Type] $Message"
    
    # Write to log file
    try {
        Add-Content -Path $LogFile -Value $LogEntry -ErrorAction Stop
    } catch {
        # If can't write to file, output to console
        Write-Warning "Could not write to log file. Logging to console only."
    }
    
    # Also write to console with appropriate color
    switch ($Type) {
        "ERROR" {
            Write-Host $LogEntry -ForegroundColor Red
        }
        "WARNING" {
            Write-Host $LogEntry -ForegroundColor Yellow
        }
        "INFO" {
            Write-Host $LogEntry -ForegroundColor Green
        }
        default {
            Write-Host $LogEntry
        }
    }
}

# Check if running with admin privileges
$CurrentUserIsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $CurrentUserIsAdmin) {
    Write-Log "ERROR" "This script must be run with administrator privileges."
    Write-Host "ERROR: This script must be run with administrator privileges." -ForegroundColor Red
    exit 1
}

# Check Windows version
$OSVersion = [System.Environment]::OSVersion.Version
$WindowsVersion = $OSVersion.Major * 10 + $OSVersion.Minor
if ($WindowsVersion -lt 61) { # Windows 7 is 6.1
    Write-Log "ERROR" "This script requires Windows 7 or later (detected version: $($OSVersion.ToString()))"
    Write-Host "ERROR: This script requires Windows 7 or later." -ForegroundColor Red
    exit 1
}

# Log script invocation
Write-Log "INFO" "Starting user creation process for username: $Username"

# Check if user already exists
try {
    $UserExists = Get-LocalUser -Name $Username -ErrorAction SilentlyContinue
    if ($UserExists) {
        Write-Log "ERROR" "User '$Username' already exists"
        Write-Host "ERROR: User '$Username' already exists." -ForegroundColor Red
        exit 1
    }
} catch {
    # This catch is for older systems where Get-LocalUser might not be available
    $UserExists = $null
    try {
        $ADSI = [ADSI]"WinNT://$env:COMPUTERNAME"
        $UserExists = $ADSI.Children | Where-Object { $_.SchemaClassName -eq 'user' -and $_.Name -eq $Username }
        if ($UserExists) {
            Write-Log "ERROR" "User '$Username' already exists"
            Write-Host "ERROR: User '$Username' already exists." -ForegroundColor Red
            exit 1
        }
    } catch {
        Write-Log "WARNING" "Error checking if user exists: $_"
    }
}

# Set default password
$DefaultPassword = "scogo@007"
$SecurePassword = ConvertTo-SecureString $DefaultPassword -AsPlainText -Force
Write-Log "INFO" "Using default password for new user $Username"

# Try to determine which method to use for user creation
$UseNewLocalUser = $true
try {
    # Test if New-LocalUser cmdlet is available
    Get-Command New-LocalUser -ErrorAction Stop | Out-Null
} catch {
    $UseNewLocalUser = $false
    Write-Log "INFO" "New-LocalUser cmdlet not available, using ADSI instead"
}

# Create the user account
if ($UseNewLocalUser) {
    # Modern approach
    try {
        $NewUserParams = @{
            Name = $Username
            Password = $SecurePassword
            Description = "Created by Nexus RMM"
            PasswordNeverExpires = $false
            AccountNeverExpires = $true
            UserMayNotChangePassword = $false
            ErrorAction = "Stop"
        }
        
        # Only add FullName if it's provided
        if ($FullName -ne "") {
            $NewUserParams.Add("FullName", $FullName)
        }
        
        Write-Log "INFO" "Creating user $Username with New-LocalUser cmdlet"
        $User = New-LocalUser @NewUserParams
    } catch {
        Write-Log "ERROR" "Failed to create user with New-LocalUser: $_"
        $UseNewLocalUser = $false
    }
}

# Fallback to ADSI if New-LocalUser failed or isn't available
if (-not $UseNewLocalUser) {
    try {
        Write-Log "INFO" "Creating user $Username with ADSI (legacy method)"
        $Computer = [ADSI]"WinNT://$env:COMPUTERNAME,computer"
        $User = $Computer.Create("user", $Username)
        
        # Set the password
        $User.SetPassword($DefaultPassword)
        
        # Different ways to set the full name (for compatibility)
        if ($FullName -ne "") {
            try {
                # Method 1: Using net user command
                Start-Process -FilePath "net" -ArgumentList "user $Username /fullname:`"$FullName`"" -NoNewWindow -Wait
                Write-Log "INFO" "Set fullname using net user command"
            } catch {
                Write-Log "WARNING" "Could not set fullname using net user: $_"
                
                try {
                    # Method 2: Using Put method (safer than direct property assignment)
                    $User.Put("FullName", $FullName)
                    Write-Log "INFO" "Set fullname using Put method"
                } catch {
                    Write-Log "WARNING" "Could not set fullname using Put method: $_"
                }
            }
        }
        
        # Set description and commit changes
        $User.Description = "Created by Nexus RMM"
        $User.SetInfo()
        
        Write-Log "INFO" "User created using legacy WinNT provider"
    } catch {
        Write-Log "ERROR" "Failed to create user $Username : $_"
        Write-Host "ERROR: Failed to create user $Username. See log for details." -ForegroundColor Red
        exit 1
    }
}

# Set password to expire immediately (force change at next login)
try {
    if ($UseNewLocalUser) {
        # Method 1: Using built-in cmdlet (newer systems)
        Set-LocalUser -Name $Username -PasswordNeverExpires $false -ErrorAction SilentlyContinue
    }
    
    # Method 2: Using WinNT provider (works on all systems)
    $UserAccount = [ADSI]"WinNT://$env:COMPUTERNAME/$Username,user"
    $UserAccount.PasswordExpired = 1
    $UserAccount.SetInfo()
    
    # Method 3: Using net user command (most reliable)
    Start-Process -FilePath "net" -ArgumentList "user $Username /logonpasswordchg:yes" -NoNewWindow -Wait
    
    Write-Log "INFO" "Password set to expire - user must change at next login"
} catch {
    Write-Log "WARNING" "Could not set password to expire: $_"
    Write-Host "WARNING: Could not configure password expiration for $Username." -ForegroundColor Yellow
}

# Add user to administrators group if requested
if ($IsAdmin) {
    $AdminAddSuccess = $false
    
    try {
        # Method 1: Using built-in cmdlet (newer systems)
        if ($UseNewLocalUser) {
            Add-LocalGroupMember -Group "Administrators" -Member $Username -ErrorAction Stop
            $AdminAddSuccess = $true
            Write-Log "INFO" "Added user to Administrators group using Add-LocalGroupMember"
        }
    } catch {
        Write-Log "WARNING" "Could not add to Administrators using Add-LocalGroupMember: $_"
    }
    
    if (-not $AdminAddSuccess) {
        try {
            # Method 2: Using WinNT provider
            $Group = [ADSI]"WinNT://$env:COMPUTERNAME/Administrators,group"
            $Group.Add("WinNT://$env:COMPUTERNAME/$Username,user")
            $AdminAddSuccess = $true
            Write-Log "INFO" "Added user to Administrators group using ADSI"
        } catch {
            Write-Log "WARNING" "Could not add to Administrators using ADSI: $_"
        }
    }
    
    if (-not $AdminAddSuccess) {
        try {
            # Method 3: Using net localgroup command (most reliable)
            Start-Process -FilePath "net" -ArgumentList "localgroup Administrators $Username /add" -NoNewWindow -Wait
            $AdminAddSuccess = $true
            Write-Log "INFO" "Added user to Administrators group using net localgroup"
        } catch {
            Write-Log "WARNING" "Failed to add user $Username to Administrators group: $_"
            Write-Host "WARNING: Failed to add user $Username to Administrators group." -ForegroundColor Yellow
        }
    }
}

# Verify user was created
$UserCreated = $false
try {
    # Try modern method first
    Get-LocalUser -Name $Username -ErrorAction Stop | Out-Null
    $UserCreated = $true
} catch {
    # Fall back to net user
    try {
        $NetUserResult = (net user $Username 2>&1)
        if ($NetUserResult -match $Username) {
            $UserCreated = $true
        }
    } catch {
        Write-Log "WARNING" "Could not verify user creation: $_"
    }
}

if ($UserCreated) {
    # Output results
    Write-Host "`nSUCCESS: User $Username created successfully." -ForegroundColor Green
    Write-Log "INFO" "User $Username created successfully"
    
    # Display summary
    Write-Host "User details:" -ForegroundColor Cyan
    Write-Host "  Username: $Username"
    if ($FullName -ne "") {
        Write-Host "  Full name: $FullName"
    }
    if ($IsAdmin) {
        Write-Host "  Admin privileges: Yes (Administrators group)"
    } else {
        Write-Host "  Admin privileges: No"
    }
    Write-Host "  Password: Default password set (scogo@007)"
    Write-Host "  Password status: Must be changed at first login"
} else {
    Write-Host "WARNING: User creation could not be verified." -ForegroundColor Yellow
    Write-Log "WARNING" "User creation could not be verified"
} 