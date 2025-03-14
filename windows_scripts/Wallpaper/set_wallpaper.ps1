<#
.SYNOPSIS
	Sets the given image URL as desktop wallpaper for all users
.DESCRIPTION
	This PowerShell script downloads an image from a URL and sets it as desktop wallpaper for all human users (.JPG or .PNG supported)
.PARAMETER ImageUrl
	Specifies the URL to the image file
.PARAMETER Style
        Specifies either Fill, Fit, Stretch, Tile, Center, or Span (default)
.EXAMPLE
	PS> ./set_wallpaper.ps1 https://example.com/image.jpg
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Karan Singh | License: MIT
	Modified for Scogo Nexus RMM
	Version: 1.1.2
#>

param([string]$ImageUrl = "https://triton-media.s3.ap-south-1.amazonaws.com/media/logos/wallpaper-scogo.jpg", [string]$Style = "Center")

function SetWallPaperWithFallback {
    param (
        [Parameter(Mandatory=$true)]
        [string]$ImagePath,
        
        [ValidateSet('Fill', 'Fit', 'Stretch', 'Tile', 'Center', 'Span')]
        [string]$Style = "Center"
    )

    # Map style names to values
    $WallpaperStyle = switch($Style) {
        "Fill"    {"10"}
        "Fit"     {"6"}
        "Stretch" {"2"}
        "Tile"    {"0"}
        "Center"  {"0"}
        "Span"    {"22"}
    }

    # Set registry values for the style - suppressing output
    if ($Style -eq "Tile") {
        New-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name WallpaperStyle -PropertyType String -Value $WallpaperStyle -Force | Out-Null
        New-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name TileWallpaper -PropertyType String -Value 1 -Force | Out-Null
    } else {
        New-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name WallpaperStyle -PropertyType String -Value $WallpaperStyle -Force | Out-Null
        New-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name TileWallpaper -PropertyType String -Value 0 -Force | Out-Null
    }

    # Try method 1: Using Windows API
    try {
        Add-Type -TypeDefinition @"
        using System;
        using System.Runtime.InteropServices;
        using System.IO;

        public class Wallpaper {
            [DllImport("user32.dll", CharSet = CharSet.Auto)]
            public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
        }
"@
        # Ensure we use a properly formatted absolute path
        $ImagePath = [System.IO.Path]::GetFullPath($ImagePath)
        Write-Verbose "Setting wallpaper using SystemParametersInfo with path: $ImagePath"
        
        $SPI_SETDESKWALLPAPER = 0x0014
        $UpdateIniFile = 0x01
        $SendChangeEvent = 0x02
        $fWinIni = $UpdateIniFile -bor $SendChangeEvent
        
        $result = [Wallpaper]::SystemParametersInfo($SPI_SETDESKWALLPAPER, 0, $ImagePath, $fWinIni)
        
        if ($result -ne 0) {
            Write-Verbose "Successfully set wallpaper using SystemParametersInfo"
            return $true
        } else {
            Write-Verbose "SystemParametersInfo failed with code 0, trying fallback method"
        }
    } catch {
        Write-Verbose "Exception during API call: $_"
    }

    # Try method 2: Using .NET as fallback
    try {
        Write-Verbose "Using .NET fallback method to set wallpaper"
        Add-Type -TypeDefinition @"
        using System;
        using System.Runtime.InteropServices;
        using System.Drawing;
        using System.Drawing.Imaging;
        using Microsoft.Win32;
        namespace Wallpaper
        {
            public class Setter
            {
                public const int SetDesktopWallpaper = 20;
                public const int UpdateIniFile = 0x01;
                public const int SendWinIniChange = 0x02;
                [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
                private static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
                public static void SetWallpaper(string path)
                {
                    SystemParametersInfo(SetDesktopWallpaper, 0, path, UpdateIniFile | SendWinIniChange);
                }
            }
        }
"@ -ReferencedAssemblies System.Drawing
        
        # Ensure the image is saved in a compatible format
        $imageToUse = $ImagePath
        $extension = [System.IO.Path]::GetExtension($ImagePath).ToLower()
        
        # If not a BMP, create a temporary BMP copy which often works better
        if ($extension -ne ".bmp") {
            $tempFile = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), [System.IO.Path]::GetFileNameWithoutExtension($ImagePath) + ".bmp")
            Write-Verbose "Converting image to BMP format at: $tempFile"
            
            $img = [System.Drawing.Image]::FromFile($ImagePath)
            try {
                $img.Save($tempFile, [System.Drawing.Imaging.ImageFormat]::Bmp)
                $imageToUse = $tempFile
            } finally {
                $img.Dispose()
            }
        }
        
        [Wallpaper.Setter]::SetWallpaper($imageToUse)
        Write-Verbose "Applied wallpaper with .NET method"
        return $true
    } catch {
        Write-Verbose "Exception during .NET fallback: $_"
    }

    # Try method 3: Using PowerShell Com Object
    try {
        Write-Verbose "Using PowerShell Com Object method to set wallpaper"
        $shell = New-Object -ComObject WScript.Shell
        $userProfilePath = [System.Environment]::GetFolderPath('UserProfile')
        $desktopIniPath = Join-Path $userProfilePath "Desktop\desktop.ini"
        
        # Create or modify desktop.ini
        if (-not (Test-Path $desktopIniPath)) {
            New-Item -Path $desktopIniPath -ItemType File -Force | Out-Null
        }
        
        # Write the wallpaper configuration
        $iniContent = @"
[.ShellClassInfo]
LocalizedResourceName=@%SystemRoot%\system32\shell32.dll,-21787
[ExtShellFolderViews]
[{BE098140-A513-11D0-A3A4-00C04FD706EC}]
IconArea_Image=$ImagePath
"@
        Set-Content -Path $desktopIniPath -Value $iniContent -Force
        
        # Refresh the desktop
        $result = $shell.SendKeys("{F5}")
        Write-Verbose "Applied wallpaper with Com Object method"
        return $true
    } catch {
        Write-Verbose "Exception during Com Object method: $_"
    }

    # If all methods failed
    return $false
}

# Function to check if script is running as admin
function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Function to download file from URL with validation
function Download-File {
    param([string]$Url, [string]$OutputPath)
    
    Write-Host "Downloading image from $Url..."
    try {
        # Validate URL format
        if (-not ($Url -match "^https?://")) {
            Write-Error "Invalid URL format: $Url. URL must begin with http:// or https://"
            return $false
        }
        
        # Create webclient with TLS 1.2 support (for older Windows versions)
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        
        # Set default connection timeout (in milliseconds)
        [System.Net.ServicePointManager]::DefaultConnectionLimit = 100
        [System.Net.ServicePointManager]::MaxServicePointIdleTime = 30000
        
        # Create web client with proper timeout handling
        $webClient = New-Object System.Net.WebClient
        
        # Using WebClient events to handle timeouts
        $timeoutMS = 30000
        $hasTimedOut = $false
        
        # Register a timeout event
        $timer = New-Object System.Timers.Timer
        $timer.Interval = $timeoutMS
        $timer.AutoReset = $false
        $timer.Enabled = $true
        
        # Define timeout event handler
        Register-ObjectEvent -InputObject $timer -EventName Elapsed -Action {
            $global:hasTimedOut = $true
            $webClient.CancelAsync()
            Write-Host "Download timed out after $($timeoutMS / 1000) seconds."
        } | Out-Null
        
        # Download the file
        $webClient.DownloadFile($Url, $OutputPath)
        
        # Cleanup timer and event handlers
        $timer.Stop()
        Get-EventSubscriber | Where-Object {$_.SourceObject.GetType().Name -eq 'Timer'} | Unregister-Event -Force
        
        # Verify the downloaded file is an image
        if (Test-Path $OutputPath) {
            $fileInfo = Get-Item $OutputPath
            if ($fileInfo.Length -eq 0) {
                Write-Error "Downloaded file is empty"
                Remove-Item $OutputPath -Force
                return $false
            }
            
            # Basic check for image signature
            $imageSignatures = @{
                "JPG" = @(0xFF, 0xD8, 0xFF)
                "PNG" = @(0x89, 0x50, 0x4E, 0x47)
                "BMP" = @(0x42, 0x4D)
                "GIF" = @(0x47, 0x49, 0x46)
            }
            
            $fileBytes = [System.IO.File]::ReadAllBytes($OutputPath)
            $isImage = $false
            
            foreach ($sig in $imageSignatures.Values) {
                if ($fileBytes.Length -ge $sig.Length) {
                    $isMatch = $true
                    for ($i = 0; $i -lt $sig.Length; $i++) {
                        if ($fileBytes[$i] -ne $sig[$i]) {
                            $isMatch = $false
                            break
                        }
                    }
                    if ($isMatch) {
                        $isImage = $true
                        break
                    }
                }
            }
            
            if (-not $isImage) {
                Write-Error "Downloaded file does not appear to be a valid image"
                Remove-Item $OutputPath -Force
                return $false
            }
        } else {
            Write-Error "Failed to download file"
            return $false
        }
        
        Write-Host "[SUCCESS] Image downloaded successfully to $OutputPath"
        return $true
    } catch [System.Net.WebException] {
        Write-Error "Network error downloading image: $($_.Exception.Message)"
        return $false
    } catch {
        Write-Error "Failed to download image: $_"
        return $false
    } finally {
        # Clean up any remaining event subscribers
        Get-EventSubscriber | Where-Object {$_.SourceObject.GetType().Name -eq 'Timer'} | Unregister-Event -Force -ErrorAction SilentlyContinue
    }
}

# Function to disable wallpaper changes in registry
function Block-WallpaperChanges {
    Write-Host "Blocking users from changing wallpaper..."
    try {
        # Create/modify the registry key to prevent wallpaper changes - multiple methods for different Windows versions
        
        # Method 1: ActiveDesktop policy
        $registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop"
        if (-not (Test-Path $registryPath)) {
            New-Item -Path $registryPath -Force | Out-Null
        }
        New-ItemProperty -Path $registryPath -Name "NoChangingWallPaper" -Value 1 -PropertyType DWORD -Force | Out-Null
        
        # Method 2: Personalization policy
        $userPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization"
        if (-not (Test-Path $userPolicyPath)) {
            New-Item -Path $userPolicyPath -Force | Out-Null
        }
        New-ItemProperty -Path $userPolicyPath -Name "PreventChangingWallPaper" -Value 1 -PropertyType DWORD -Force | Out-Null
        
        # Method 3: Control Panel settings
        $controlPanelPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
        if (-not (Test-Path $controlPanelPath)) {
            New-Item -Path $controlPanelPath -Force | Out-Null
        }
        New-ItemProperty -Path $controlPanelPath -Name "NoDispBackgroundPage" -Value 1 -PropertyType DWORD -Force | Out-Null
        
        # Method 4: Explorer settings (for newer Windows versions)
        $explorerPolicyPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer"
        if (-not (Test-Path $explorerPolicyPath)) {
            New-Item -Path $explorerPolicyPath -Force | Out-Null
        }
        New-ItemProperty -Path $explorerPolicyPath -Name "NoActiveDesktopChanges" -Value 1 -PropertyType DWORD -Force | Out-Null
        
        # Apply the same settings for Default User profile (for new users)
        $defaultUserPath = "C:\Users\Default\NTUSER.DAT"
        if (Test-Path $defaultUserPath) {
            Write-Host "Setting policies for default user profile..."
            & reg load "HKU\DefaultUser" $defaultUserPath | Out-Null
            try {
                & reg add "HKU\DefaultUser\Software\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop" /v NoChangingWallPaper /t REG_DWORD /d 1 /f | Out-Null
                & reg add "HKU\DefaultUser\Software\Microsoft\Windows\CurrentVersion\Policies\System" /v NoDispBackgroundPage /t REG_DWORD /d 1 /f | Out-Null
            } finally {
                [gc]::Collect()
                Start-Sleep -Seconds 1
                & reg unload "HKU\DefaultUser" | Out-Null
            }
        }
        
        Write-Host "[SUCCESS] Successfully blocked wallpaper changes for all users"
        return $true
    } catch {
        Write-Error "Failed to block wallpaper changes: $_"
        return $false
    }
}

# Get all human user profiles
function Get-HumanUserProfiles {
    Write-Host "Identifying all human user profiles on the system..."
    $excludedUsers = @(
        "systemprofile", "LocalService", "NetworkService", 
        "defaultuser0", "Administrator", "Default", 
        "Public", "All Users", "DefaultAccount", 
        "WDAGUtilityAccount", "Guest"
    )
    
    # Get all user profiles from registry for more reliable results
    $profileList = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\*" | 
                   Where-Object { $_.ProfileImagePath -match "C:\\Users\\" } |
                   Select-Object @{Name="Path";Expression={$_.ProfileImagePath}}, @{Name="SID";Expression={$_.PSChildName}}
    
    # Filter out system accounts and excluded users
    $userProfiles = $profileList | Where-Object { 
        $username = Split-Path $_.Path -Leaf
        ($excludedUsers -notcontains $username) -and 
        (-not $_.SID.StartsWith("S-1-5-18")) -and  # Local System
        (-not $_.SID.StartsWith("S-1-5-19")) -and  # Local Service
        (-not $_.SID.StartsWith("S-1-5-20"))       # Network Service
    }
    
    Write-Host "Found $($userProfiles.Count) human user profiles"
    return $userProfiles
}

# Function to set wallpaper for a specific user profile with improved registry handling
function Set-WallpaperForUser {
    param(
        [Parameter(Mandatory=$true)]
        [string]$UserProfilePath,
        
        [Parameter(Mandatory=$true)]
        [string]$ImagePath,
        
        [string]$Style = "Center",
        
        [string]$SID = ""
    )
    
    $username = Split-Path $UserProfilePath -Leaf
    Write-Host "Setting wallpaper for user: $username"
    
    # Determine if user is currently logged in
    $activeSessionQuery = query session 2>$null
    $isUserLoggedIn = $activeSessionQuery -match $username
    
    if ($isUserLoggedIn) {
        Write-Host "User $username is currently logged in. Will apply wallpaper through registry method."
        # For logged-in users, we will use registry method only - avoid PsExec due to escaping issues
    }
    
    # Always attempt registry method as the main approach
    $userHive = "$UserProfilePath\NTUSER.DAT"
    $tempKey = "HKU\TempHive"
    
    try {
        # Check if registry hive exists
        if (-not (Test-Path $userHive)) {
            Write-Warning "User profile registry not found for $username"
            return $false
        }
        
        # Check if registry hive is already loaded
        $loadedHives = Get-ChildItem Registry::HKEY_USERS | Where-Object { 
            $_.PSChildName -ne ".DEFAULT" -and 
            $_.PSChildName -ne "S-1-5-18" -and 
            $_.PSChildName -ne "S-1-5-19" -and 
            $_.PSChildName -ne "S-1-5-20" -and 
            $_.PSChildName -match "S-\d-\d+-\d+-\d+" 
        }
        
        if ($SID -ne "" -and $loadedHives.PSChildName -contains $SID) {
            # If user hive is already loaded, use it directly
            Write-Host "User registry hive already loaded, using existing hive"
            $tempKey = "HKU\$SID"
        } else {
            # Attempt to load the hive with proper cleanup
            Write-Host "Loading user registry hive..."
            
            # Make sure any previous instances are unloaded
            try { & reg unload $tempKey | Out-Null } catch { }
            
            # Force garbage collection to release any handles
            [gc]::Collect()
            Start-Sleep -Seconds 1
            
            # Load the hive
            $loadResult = & reg load $tempKey $userHive 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Warning "Could not load registry hive for $username. It may be in use. Error: $loadResult"
                return $false
            }
        }
        
        # Set wallpaper style
        $wallpaperStyle = switch($Style) {
            "Fill"    {"10"}
            "Fit"     {"6"}
            "Stretch" {"2"}
            "Tile"    {"0"}
            "Center"  {"0"}
            "Span"    {"22"}
        }
        
        # Update registry settings for this user
        & reg add "$tempKey\Control Panel\Desktop" /v WallpaperStyle /t REG_SZ /d $wallpaperStyle /f | Out-Null
        & reg add "$tempKey\Control Panel\Desktop" /v TileWallpaper /t REG_SZ /d $(if ($Style -eq "Tile") {"1"} else {"0"}) /f | Out-Null
        & reg add "$tempKey\Control Panel\Desktop" /v Wallpaper /t REG_SZ /d $ImagePath /f | Out-Null
        
        # Set additional registry keys to prevent wallpaper changes
        & reg add "$tempKey\Software\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop" /v NoChangingWallPaper /t REG_DWORD /d 1 /f | Out-Null
        & reg add "$tempKey\Software\Microsoft\Windows\CurrentVersion\Policies\System" /v NoDispBackgroundPage /t REG_DWORD /d 1 /f | Out-Null
        
        Write-Host "[SUCCESS] Wallpaper settings applied for user: $username"
        return $true
    } catch {
        Write-Error "Error setting wallpaper for $username`: $_"
        return $false
    } finally {
        # Only unload the hive if we loaded it ourselves (not for already loaded hives)
        if ($SID -eq "" -or $loadedHives.PSChildName -notcontains $SID) {
            # Unload the hive with proper cleanup
            Write-Host "Unloading user registry hive..."
            [gc]::Collect()
            Start-Sleep -Seconds 1
            try {
                & reg unload $tempKey | Out-Null
            } catch {
                Write-Warning "Failed to unload registry hive for $username. Will retry..."
                # Try once more after a delay
                Start-Sleep -Seconds 2
                [gc]::Collect()
                try {
                    & reg unload $tempKey | Out-Null
                } catch {
                    Write-Error "Could not unload registry hive for $username. You may need to restart the computer."
                }
            }
        }
    }
}

# Function to check for Active Directory environment
function Test-DomainJoined {
    $computerSystem = Get-WmiObject -Class Win32_ComputerSystem
    return ($computerSystem.PartOfDomain)
}

# Function to handle Windows version specific settings
function Get-WindowsVersionSpecificSettings {
    $osInfo = Get-WmiObject -Class Win32_OperatingSystem
    $osVersion = [Version]($osInfo.Version)
    
    Write-Host "Detected Windows version: $($osInfo.Caption) ($($osInfo.Version))"
    
    # Different settings based on Windows version
    $settings = @{
        IsWindows7 = $osVersion.Major -eq 6 -and $osVersion.Minor -le 1
        IsWindows8 = $osVersion.Major -eq 6 -and ($osVersion.Minor -eq 2 -or $osVersion.Minor -eq 3)
        IsWindows10OrLater = $osVersion.Major -ge 10
    }
    
    return $settings
}

# Main execution starts here
try {
    # Set error action preference to stop on all errors to improve logging
    $ErrorActionPreference = "Stop"
    $VerbosePreference = "Continue"
    
    # Log script start with version
    Write-Host "====================================================" -ForegroundColor Cyan
    Write-Host "Scogo Nexus RMM Wallpaper Deployment Tool v1.1.2" -ForegroundColor Cyan  
    Write-Host "Started: $(Get-Date)" -ForegroundColor Cyan
    Write-Host "====================================================" -ForegroundColor Cyan
    
    # Ensure script is running as administrator
    if (-not (Test-Admin)) {
        Write-Error "This script must be run as Administrator. Please restart with administrator privileges."
        exit 1
    }
    
    # Get OS version specific settings
    try {
        $osSettings = Get-WindowsVersionSpecificSettings
    } catch {
        Write-Warning "Error detecting Windows version: $_. Will use default settings."
        $osSettings = @{
            IsWindows7 = $false
            IsWindows8 = $false
            IsWindows10OrLater = $true
        }
    }
    
    # Check if machine is domain joined
    try {
        $isDomainJoined = Test-DomainJoined
        if ($isDomainJoined) {
            Write-Host "Machine is domain-joined. Will handle domain user profiles appropriately."
        }
    } catch {
        Write-Warning "Error detecting domain status: $_. Will assume workgroup computer."
        $isDomainJoined = $false
    }
    
    # Create a permanent directory for the wallpaper if it doesn't exist
    $wallpaperDir = "C:\ProgramData\Scogo\Wallpaper"
    if (-not (Test-Path $wallpaperDir)) {
        Write-Host "Creating wallpaper directory at $wallpaperDir"
        try {
            New-Item -Path $wallpaperDir -ItemType Directory -Force | Out-Null
        } catch {
            Write-Warning "Error creating directory: $_. Will use temporary directory."
            $wallpaperDir = Join-Path $env:TEMP "Scogo\Wallpaper"
            New-Item -Path $wallpaperDir -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
        }
    }
    
    # Set appropriate permissions on the directory to ensure all users can access it
    try {
        $acl = Get-Acl $wallpaperDir
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule("Users", "ReadAndExecute", "ContainerInherit,ObjectInherit", "None", "Allow")
        $acl.SetAccessRule($rule)
        Set-Acl $wallpaperDir $acl
    } catch {
        Write-Warning "Could not set permissions on directory: $_. Wallpaper may not be accessible to all users."
    }
    
    # Download the wallpaper
    $wallpaperPath = Join-Path $wallpaperDir "corporate-wallpaper.jpg"
    $downloadSuccess = $false
    
    try {
        $downloadSuccess = Download-File -Url $ImageUrl -OutputPath $wallpaperPath
    } catch {
        Write-Error "Error during download: $_"
    }
    
    # If the main download failed, try a simple alternative method
    if (-not $downloadSuccess) {
        Write-Host "Primary download failed. Trying alternative download method..."
        try {
            # Configure TLS 1.2
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            
            # Use Invoke-WebRequest which is more reliable in some environments
            Invoke-WebRequest -Uri $ImageUrl -OutFile $wallpaperPath -UseBasicParsing -TimeoutSec 30
            
            # Check if file was downloaded successfully
            if (Test-Path $wallpaperPath) {
                $fileInfo = Get-Item $wallpaperPath
                if ($fileInfo.Length -gt 0) {
                    Write-Host "[SUCCESS] Image downloaded successfully using alternative method"
                    $downloadSuccess = $true
                }
            }
        } catch {
            Write-Warning "Alternative download method also failed: $_"
        }
    }
    
    # If both download methods failed, try to use a locally cached copy
    if (-not $downloadSuccess) {
        # Try to use a locally cached copy if available
        $localCopy = Join-Path $PSScriptRoot "corporate-wallpaper.jpg"
        if (Test-Path $localCopy) {
            Write-Host "Using locally cached wallpaper image."
            try {
                Copy-Item -Path $localCopy -Destination $wallpaperPath -Force
                $downloadSuccess = Test-Path $wallpaperPath
            } catch {
                Write-Error "Failed to copy local wallpaper: $_. Exiting."
                exit 1
            }
        } else {
            Write-Error "Failed to download wallpaper and no local copy found. Exiting."
            exit 1
        }
    }
    
    # Apply wallpaper for the current user first
    Write-Host "Setting wallpaper for current user..."
    $currentUserSuccess = $false
    try {
        $currentUserSuccess = SetWallPaperWithFallback -ImagePath $wallpaperPath -Style $Style
        
        if ($currentUserSuccess) {
            Write-Host "[SUCCESS] Wallpaper set for current user"
        } else {
            Write-Warning "Failed to set wallpaper for current user using direct method. Will try registry method."
        }
    } catch {
        Write-Warning "Error setting wallpaper for current user: $_"
    }
    
    # Block users from changing the wallpaper
    $blockSuccess = $false
    try {
        $blockSuccess = Block-WallpaperChanges
    } catch {
        Write-Warning "Error blocking wallpaper changes: $_"
    }
    
    # Then set it for all human users
    $userProfiles = @()
    try {
        $userProfiles = Get-HumanUserProfiles
    } catch {
        Write-Warning "Error getting user profiles: $_"
    }
    
    $userSuccessCount = 0
    foreach ($profile in $userProfiles) {
        try {
            $profilePath = $profile.Path
            $sid = $profile.SID
            
            $success = Set-WallpaperForUser -UserProfilePath $profilePath -ImagePath $wallpaperPath -Style $Style -SID $sid
            if ($success) {
                $userSuccessCount++
            }
        } catch {
            Write-Warning "Error processing user profile $($profile.Path): $_"
        }
    }
    
    Write-Host "Successfully set wallpaper for $userSuccessCount out of $($userProfiles.Count) users."
    
    # Setup a startup script to reapply the wallpaper when users log in
    try {
        Write-Host "Creating startup script to refresh wallpaper at login..."
        
        # Create a separate PS1 file with the refresh logic
        $refreshScriptPath = Join-Path $wallpaperDir "RefreshWallpaper.ps1"
        $refreshScriptContent = @"
# Wallpaper refresh script
# Created: $(Get-Date)

# Wait a moment for desktop to initialize
Start-Sleep -Seconds 5

# Define wallpaper path
$wallpaperPath = "$wallpaperPath"

# Make sure the wallpaper file exists
if (Test-Path $wallpaperPath) {
    # Force refresh desktop
    $null = Start-Process -FilePath 'C:\Windows\System32\RUNDLL32.EXE' -ArgumentList 'user32.dll,UpdatePerUserSystemParameters' -NoNewWindow

    # Use Windows API to set wallpaper
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class Wallpaper {
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
'@
    [Wallpaper]::SystemParametersInfo(20, 0, $wallpaperPath, 3)
    Write-Host "Wallpaper refreshed successfully."
} else {
    Write-Host "Wallpaper file not found at: $wallpaperPath"
}
"@
        
        # Write the PowerShell script
        Set-Content -Path $refreshScriptPath -Value $refreshScriptContent -Force
        
        # Create a simple batch file that calls the PowerShell script
        $batchContent = @"
@echo off
echo Refreshing wallpaper settings...
powershell.exe -ExecutionPolicy Bypass -File "$refreshScriptPath"
"@
        
        # Write the batch file to startup folder
        $startupDir = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp"
        if (-not (Test-Path $startupDir)) {
            New-Item -Path $startupDir -ItemType Directory -Force | Out-Null
        }
        
        $startupFile = Join-Path $startupDir "RefreshWallpaper.bat"
        Set-Content -Path $startupFile -Value $batchContent -Force
        
        Write-Host "[SUCCESS] Startup script created successfully"
        
        # For Windows 7, we need to create a scheduled task as well (startup scripts sometimes don't work reliably)
        if ($osSettings.IsWindows7) {
            try {
                Write-Host "Creating scheduled task for Windows 7 compatibility..."
                $taskName = "RefreshCorporateWallpaper"
                $taskAction = New-ScheduledTaskAction -Execute "C:\Windows\System32\cmd.exe" -Argument "/c `"$startupFile`""
                $taskTrigger = New-ScheduledTaskTrigger -AtLogOn
                $taskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
                $taskPrincipal = New-ScheduledTaskPrincipal -GroupId "Users" -RunLevel Highest
                
                # Remove task if it exists
                Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
                
                # Create the task
                Register-ScheduledTask -TaskName $taskName -Action $taskAction -Trigger $taskTrigger -Settings $taskSettings -Principal $taskPrincipal
            } catch {
                Write-Warning "Error creating scheduled task: $_"
            }
        }
    } catch {
        Write-Warning "Error creating startup script: $_"
    }
    
    # Refresh desktop to apply changes immediately
    try {
        Write-Host "Refreshing desktop settings..."
        & rundll32.exe user32.dll,UpdatePerUserSystemParameters
    } catch {
        Write-Warning "Error refreshing desktop: $_"
    }
    
    # Summary
    Write-Host "====================================================" -ForegroundColor Green
    Write-Host "Wallpaper deployment summary:" -ForegroundColor Green
    Write-Host "- Wallpaper downloaded: $downloadSuccess" -ForegroundColor Green
    Write-Host "- Current user applied: $currentUserSuccess" -ForegroundColor Green
    Write-Host "- User profiles updated: $userSuccessCount out of $($userProfiles.Count)" -ForegroundColor Green
    Write-Host "- Wallpaper changes blocked: $blockSuccess" -ForegroundColor Green
    Write-Host "- Script completed: $(Get-Date)" -ForegroundColor Green
    Write-Host "====================================================" -ForegroundColor Green
    
    exit 0 # success
} catch {
    Write-Host "⚠️ Error in line $($_.InvocationInfo.ScriptLineNumber): $($Error[0])" -ForegroundColor Red
    Write-Host "Full error details: $_" -ForegroundColor Red
    exit 1
}