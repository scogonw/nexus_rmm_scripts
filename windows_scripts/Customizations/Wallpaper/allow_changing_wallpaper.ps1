<#
.SYNOPSIS
	Allows users to change desktop wallpaper by removing restrictions
.DESCRIPTION
	This PowerShell script removes registry restrictions that prevent users from changing their desktop wallpaper
.EXAMPLE
	PS> ./allow_changing_wallpaper.ps1
.LINK
	https://github.com/scogonw/nexus_rmm_scripts
.NOTES
	Author: Karan Singh | License: MIT
	Modified for Scogo Nexus RMM
	Version: 1.0.1
#>

# Function to check if script is running as admin
function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Function to allow wallpaper changes in registry (system-wide)
function Allow-WallpaperChanges {
    Write-Host "Allowing users to change wallpaper (system-wide settings)..."
    try {
        # Remove restrictions from registry - multiple methods for different Windows versions
        
        # Method 1: ActiveDesktop policy
        $registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop"
        if (Test-Path $registryPath) {
            Remove-ItemProperty -Path $registryPath -Name "NoChangingWallPaper" -Force -ErrorAction SilentlyContinue
            if ((Get-Item -Path $registryPath -ErrorAction SilentlyContinue).Property.Count -eq 0) {
                Remove-Item -Path $registryPath -Force -ErrorAction SilentlyContinue
            }
        }
        
        # Method 2: Personalization policy
        $userPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization"
        if (Test-Path $userPolicyPath) {
            Remove-ItemProperty -Path $userPolicyPath -Name "PreventChangingWallPaper" -Force -ErrorAction SilentlyContinue
            if ((Get-Item -Path $userPolicyPath -ErrorAction SilentlyContinue).Property.Count -eq 0) {
                Remove-Item -Path $userPolicyPath -Force -ErrorAction SilentlyContinue
            }
        }
        
        # Method 3: Control Panel settings
        $controlPanelPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
        if (Test-Path $controlPanelPath) {
            Remove-ItemProperty -Path $controlPanelPath -Name "NoDispBackgroundPage" -Force -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path $controlPanelPath -Name "NoDispAppearancePage" -Force -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path $controlPanelPath -Name "NoDispScrSavPage" -Force -ErrorAction SilentlyContinue
        }
        
        # Method 4: Explorer settings (for newer Windows versions)
        $explorerPolicyPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer"
        if (Test-Path $explorerPolicyPath) {
            Remove-ItemProperty -Path $explorerPolicyPath -Name "NoActiveDesktopChanges" -Force -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path $explorerPolicyPath -Name "NoDesktop" -Force -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path $explorerPolicyPath -Name "NoSetActiveDesktop" -Force -ErrorAction SilentlyContinue
        }
        
        # Additional policies that might affect wallpaper
        $deskPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Control Panel\Desktop"
        if (Test-Path $deskPolicyPath) {
            Remove-Item -Path $deskPolicyPath -Force -Recurse -ErrorAction SilentlyContinue
        }
        
        # Apply the same settings for Default User profile (for new users)
        $defaultUserPath = "C:\Users\Default\NTUSER.DAT"
        if (Test-Path $defaultUserPath) {
            Write-Host "Removing restrictions from default user profile..."
            & reg load "HKU\DefaultUser" $defaultUserPath | Out-Null
            try {
                & reg delete "HKU\DefaultUser\Software\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop" /v NoChangingWallPaper /f | Out-Null
                & reg delete "HKU\DefaultUser\Software\Microsoft\Windows\CurrentVersion\Policies\System" /v NoDispBackgroundPage /f | Out-Null
                & reg delete "HKU\DefaultUser\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoActiveDesktopChanges /f | Out-Null
            } catch {
                # Ignore errors if keys don't exist
            } finally {
                [gc]::Collect()
                Start-Sleep -Seconds 1
                & reg unload "HKU\DefaultUser" | Out-Null
            }
        }
        
        Write-Host "[SUCCESS] Successfully removed system-wide wallpaper restrictions"
        return $true
    } catch {
        Write-Error "Failed to remove system-wide wallpaper restrictions: $_"
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

# Function to allow wallpaper changes for a specific user profile
function Allow-WallpaperChangesForUser {
    param(
        [Parameter(Mandatory=$true)]
        [string]$UserProfilePath,
        
        [string]$SID = ""
    )
    
    $username = Split-Path $UserProfilePath -Leaf
    Write-Host "Allowing wallpaper changes for user: $username"
    
    # User registry hive
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
        
        # Remove restrictions from user registry (all potential locations)
        try {
            # ActiveDesktop policy
            & reg delete "$tempKey\Software\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop" /v NoChangingWallPaper /f | Out-Null
            & reg delete "$tempKey\Software\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop" /f | Out-Null
            
            # System policy
            & reg delete "$tempKey\Software\Microsoft\Windows\CurrentVersion\Policies\System" /v NoDispBackgroundPage /f | Out-Null
            
            # Explorer policy
            & reg delete "$tempKey\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoActiveDesktopChanges /f | Out-Null
            & reg delete "$tempKey\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoDesktop /f | Out-Null
            
            # Control Panel/Desktop policy
            & reg delete "$tempKey\Software\Policies\Microsoft\Windows\Control Panel\Desktop" /f | Out-Null
        } catch {
            # Ignore errors for keys that don't exist
        }
        
        # Enable personalization for this user
        try {
            & reg add "$tempKey\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v EnableTransparency /t REG_DWORD /d 1 /f | Out-Null
            & reg add "$tempKey\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v AppsUseLightTheme /t REG_DWORD /d 1 /f | Out-Null
            & reg add "$tempKey\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v ColorPrevalence /t REG_DWORD /d 1 /f | Out-Null
        } catch {
            # Ignore errors
        }
        
        Write-Host "[SUCCESS] Wallpaper restrictions removed for user: $username"
        return $true
    } catch {
        Write-Error "Error allowing wallpaper changes for $username`: $_"
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

# Function to allow wallpaper changes for current user directly
function Allow-CurrentUserWallpaperChanges {
    Write-Host "Allowing wallpaper changes for current user..."
    try {
        # Current user registry paths
        $paths = @(
            # ActiveDesktop policy
            "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop",
            # System policy
            "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System",
            # Explorer policy
            "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer",
            # Control Panel/Desktop policy
            "HKCU:\Software\Policies\Microsoft\Windows\Control Panel\Desktop"
        )
        
        # Remove registry keys
        foreach ($path in $paths) {
            if (Test-Path $path) {
                try {
                    Remove-Item -Path $path -Force -Recurse -ErrorAction SilentlyContinue
                    Write-Host "Removed restrictions at: $path"
                } catch {
                    Write-Warning "Could not remove $path`: $_"
                }
            }
        }
        
        # Remove specific values
        $keyValues = @{
            "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop" = @("NoChangingWallPaper")
            "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System" = @("NoDispBackgroundPage", "NoDispAppearancePage")
            "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" = @("NoActiveDesktopChanges", "NoDesktop", "NoSetActiveDesktop")
        }
        
        foreach ($key in $keyValues.Keys) {
            foreach ($value in $keyValues[$key]) {
                try {
                    if (Test-Path $key) {
                        Remove-ItemProperty -Path $key -Name $value -Force -ErrorAction SilentlyContinue
                    }
                } catch {
                    # Ignore errors
                }
            }
        }
        
        # Enable personalization 
        $personalizePath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
        if (-not (Test-Path $personalizePath)) {
            New-Item -Path $personalizePath -Force | Out-Null
        }
        
        New-ItemProperty -Path $personalizePath -Name "EnableTransparency" -Value 1 -PropertyType DWORD -Force | Out-Null
        New-ItemProperty -Path $personalizePath -Name "AppsUseLightTheme" -Value 1 -PropertyType DWORD -Force | Out-Null
        New-ItemProperty -Path $personalizePath -Name "ColorPrevalence" -Value 1 -PropertyType DWORD -Force | Out-Null
        
        Write-Host "[SUCCESS] Current user restrictions removed"
        return $true
    } catch {
        Write-Error "Failed to remove current user restrictions: $_"
        return $false
    }
}

# Function to remove startup script for wallpaper refresh
function Remove-WallpaperStartupScript {
    Write-Host "Removing wallpaper refresh startup scripts..."
    
    try {
        # Remove batch file from startup
        $startupDir = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp"
        $startupFile = Join-Path $startupDir "RefreshWallpaper.bat"
        
        if (Test-Path $startupFile) {
            Remove-Item -Path $startupFile -Force
            Write-Host "Removed startup batch file."
        }
        
        # Remove PowerShell script
        $wallpaperDir = "C:\ProgramData\Scogo\Wallpaper"
        $refreshScriptPath = Join-Path $wallpaperDir "RefreshWallpaper.ps1"
        
        if (Test-Path $refreshScriptPath) {
            Remove-Item -Path $refreshScriptPath -Force
            Write-Host "Removed refresh PowerShell script."
        }
        
        # Remove scheduled task (for Windows 7 compatibility)
        try {
            $taskName = "RefreshCorporateWallpaper"
            $taskExists = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
            
            if ($taskExists) {
                Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
                Write-Host "Removed scheduled task for wallpaper refresh."
            }
        } catch {
            Write-Warning "Error checking scheduled task: $_"
            # Try using schtasks.exe as fallback
            try {
                & schtasks /Query /TN "RefreshCorporateWallpaper" 2>&1 | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    & schtasks /Delete /TN "RefreshCorporateWallpaper" /F | Out-Null
                    Write-Host "Removed scheduled task using schtasks.exe."
                }
            } catch {
                # Ignore errors
            }
        }
        
        return $true
    } catch {
        Write-Warning "Error removing startup scripts: $_"
        return $false
    }
}

# Function to disable and enable Active Desktop (can help reset certain locks)
function Reset-ActiveDesktop {
    Write-Host "Resetting Active Desktop settings..."
    
    try {
        # Try to reset Active Desktop if available (depends on Windows version)
        $shell = New-Object -ComObject Shell.Application
        
        try {
            # This works on older Windows versions
            $desktop = $shell.NameSpace(0x0) # CSIDL_DESKTOP
            $desktop.Items() | Out-Null
        } catch {
            # Ignore errors
        }
        
        # Try with rundll32 commands too (different Windows versions)
        try {
            # Disable and re-enable Active Desktop
            & rundll32.exe user32.dll,UpdatePerUserSystemParameters
            & rundll32.exe user32.dll,UpdatePerUserSystemParameters 1, True
        } catch {
            # Ignore errors
        }
        
        return $true
    } catch {
        Write-Warning "Error resetting Active Desktop: $_"
        return $false
    }
}

# Function to restart Explorer (applies changes without requiring reboot)
function Restart-Explorer {
    Write-Host "Restarting Windows Explorer to apply changes..."
    
    try {
        # Get Explorer processes
        $explorerProcesses = Get-Process -Name "explorer" -ErrorAction SilentlyContinue
        
        if ($explorerProcesses) {
            # Kill all Explorer processes
            $explorerProcesses | ForEach-Object { 
                try {
                    Stop-Process -Id $_.Id -Force
                } catch {
                    Write-Warning "Could not stop Explorer: $_"
                }
            }
            
            # Wait a moment
            Start-Sleep -Seconds 2
            
            # Start Explorer again
            Start-Process "explorer.exe"
            
            Write-Host "Explorer restarted successfully."
            return $true
        } else {
            Write-Host "No Explorer processes found to restart."
            return $true
        }
    } catch {
        Write-Warning "Error restarting Explorer: $_"
        return $false
    }
}

# Function to fix Group Policy if it's enforcing settings
function Reset-GroupPolicyRestrictions {
    Write-Host "Checking for Group Policy restrictions..."
    
    try {
        # Check if gpupdate is available and run it
        $gpupdateExists = Get-Command "gpupdate.exe" -ErrorAction SilentlyContinue
        
        if ($gpupdateExists) {
            # Force Group Policy update to remove any cached policy settings
            Write-Host "Updating Group Policy..."
            & gpupdate /Target:User /Force | Out-Null
            
            # Give it a moment to process
            Start-Sleep -Seconds 2
        }
        
        # Check for any local ADMX files that might be enforcing the policy
        $admxFolder = "$env:SystemRoot\PolicyDefinitions"
        $personalizeAdmx = Join-Path $admxFolder "personalization.admx"
        
        if (Test-Path $personalizeAdmx) {
            Write-Host "Found personalization policy definitions. Group Policy might be enforcing some settings."
        }
        
        return $true
    } catch {
        Write-Warning "Error resetting Group Policy: $_"
        return $false
    }
}

# Main execution starts here
try {
    # Set error action preference to stop on all errors to improve logging
    $ErrorActionPreference = "Stop"
    $VerbosePreference = "Continue"
    
    # Log script start with version
    Write-Host "====================================================" -ForegroundColor Cyan
    Write-Host "Scogo Nexus RMM Wallpaper Restriction Removal Tool v1.0.1" -ForegroundColor Cyan  
    Write-Host "Started: $(Get-Date)" -ForegroundColor Cyan
    Write-Host "====================================================" -ForegroundColor Cyan
    
    # Ensure script is running as administrator
    if (-not (Test-Admin)) {
        Write-Error "This script must be run as Administrator. Please restart with administrator privileges."
        exit 1
    }
    
    # Allow wallpaper changes globally
    $globalSuccess = $false
    try {
        $globalSuccess = Allow-WallpaperChanges
    } catch {
        Write-Warning "Error allowing global wallpaper changes: $_"
    }
    
    # Allow changes for current user (ensure they can change wallpaper)
    $currentUserSuccess = $false
    try {
        $currentUserSuccess = Allow-CurrentUserWallpaperChanges
    } catch {
        Write-Warning "Error allowing wallpaper changes for current user: $_"
    }
    
    # Allow changes for all user profiles
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
            
            $success = Allow-WallpaperChangesForUser -UserProfilePath $profilePath -SID $sid
            if ($success) {
                $userSuccessCount++
            }
        } catch {
            Write-Warning "Error processing user profile $($profile.Path): $_"
        }
    }
    
    # Remove startup script
    $startupRemoved = $false
    try {
        $startupRemoved = Remove-WallpaperStartupScript
    } catch {
        Write-Warning "Error removing startup script: $_"
    }
    
    # Check for any Group Policy restrictions
    $gpReset = $false
    try {
        $gpReset = Reset-GroupPolicyRestrictions
    } catch {
        Write-Warning "Error resetting Group Policy: $_"
    }
    
    # Reset Active Desktop settings
    $desktopReset = $false
    try {
        $desktopReset = Reset-ActiveDesktop
    } catch {
        Write-Warning "Error resetting Active Desktop: $_"
    }
    
    # Refresh desktop to apply changes immediately
    try {
        Write-Host "Refreshing desktop settings..."
        & rundll32.exe user32.dll,UpdatePerUserSystemParameters
        & rundll32.exe user32.dll,UpdatePerUserSystemParameters 1, True
    } catch {
        Write-Warning "Error refreshing desktop: $_"
    }
    
    # Restart Explorer to apply changes without requiring reboot
    $explorerRestarted = $false
    try {
        $explorerRestarted = Restart-Explorer
    } catch {
        Write-Warning "Error restarting Explorer: $_"
    }
    
    # Summary
    Write-Host "====================================================" -ForegroundColor Green
    Write-Host "Wallpaper restrictions removal summary:" -ForegroundColor Green
    Write-Host "- Global restrictions removed: $globalSuccess" -ForegroundColor Green  
    Write-Host "- Current user settings updated: $currentUserSuccess" -ForegroundColor Green
    Write-Host "- User profiles updated: $userSuccessCount out of $($userProfiles.Count)" -ForegroundColor Green
    Write-Host "- Startup scripts removed: $startupRemoved" -ForegroundColor Green
    Write-Host "- Group Policy reset attempted: $gpReset" -ForegroundColor Green
    Write-Host "- Windows Explorer restarted: $explorerRestarted" -ForegroundColor Green
    Write-Host "- Script completed: $(Get-Date)" -ForegroundColor Green
    Write-Host "====================================================" -ForegroundColor Green
    
    # Let the user know they can now change their wallpaper
    Write-Host "You can now change your wallpaper using Windows Settings or Control Panel." -ForegroundColor Yellow
    Write-Host "If you still cannot change your wallpaper, try restarting your computer." -ForegroundColor Yellow
    
    exit 0 # success
} catch {
    Write-Host "[ERROR] Script failed at line $($_.InvocationInfo.ScriptLineNumber): $($Error[0])" -ForegroundColor Red
    Write-Host "[ERROR DETAILS] $($_)" -ForegroundColor Red
    exit 1
} 