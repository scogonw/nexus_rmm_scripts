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
	Version: 1.0.0
#>

# Function to check if script is running as admin
function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Function to allow wallpaper changes in registry
function Allow-WallpaperChanges {
    Write-Host "Allowing users to change wallpaper..."
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
        }
        
        # Method 4: Explorer settings (for newer Windows versions)
        $explorerPolicyPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer"
        if (Test-Path $explorerPolicyPath) {
            Remove-ItemProperty -Path $explorerPolicyPath -Name "NoActiveDesktopChanges" -Force -ErrorAction SilentlyContinue
        }
        
        # Apply the same settings for Default User profile (for new users)
        $defaultUserPath = "C:\Users\Default\NTUSER.DAT"
        if (Test-Path $defaultUserPath) {
            Write-Host "Removing restrictions from default user profile..."
            & reg load "HKU\DefaultUser" $defaultUserPath | Out-Null
            try {
                & reg delete "HKU\DefaultUser\Software\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop" /v NoChangingWallPaper /f | Out-Null
                & reg delete "HKU\DefaultUser\Software\Microsoft\Windows\CurrentVersion\Policies\System" /v NoDispBackgroundPage /f | Out-Null
            } catch {
                # Ignore errors if keys don't exist
            } finally {
                [gc]::Collect()
                Start-Sleep -Seconds 1
                & reg unload "HKU\DefaultUser" | Out-Null
            }
        }
        
        Write-Host "[SUCCESS] Successfully allowed wallpaper changes for all users"
        return $true
    } catch {
        Write-Error "Failed to allow wallpaper changes: $_"
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
        
        # Remove restrictions from user registry
        & reg delete "$tempKey\Software\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop" /v NoChangingWallPaper /f | Out-Null
        & reg delete "$tempKey\Software\Microsoft\Windows\CurrentVersion\Policies\System" /v NoDispBackgroundPage /f | Out-Null
        
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
        $taskName = "RefreshCorporateWallpaper"
        $taskExists = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        
        if ($taskExists) {
            Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
            Write-Host "Removed scheduled task for wallpaper refresh."
        }
        
        return $true
    } catch {
        Write-Warning "Error removing startup scripts: $_"
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
    Write-Host "Scogo Nexus RMM Wallpaper Restriction Removal Tool v1.0.0" -ForegroundColor Cyan  
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
    
    # Refresh desktop to apply changes immediately
    try {
        Write-Host "Refreshing desktop settings..."
        & rundll32.exe user32.dll,UpdatePerUserSystemParameters
    } catch {
        Write-Warning "Error refreshing desktop: $_"
    }
    
    # Summary
    Write-Host "====================================================" -ForegroundColor Green
    Write-Host "Wallpaper restrictions removal summary:" -ForegroundColor Green
    Write-Host "- Global restrictions removed: $globalSuccess" -ForegroundColor Green  
    Write-Host "- User profiles updated: $userSuccessCount out of $($userProfiles.Count)" -ForegroundColor Green
    Write-Host "- Startup scripts removed: $startupRemoved" -ForegroundColor Green
    Write-Host "- Script completed: $(Get-Date)" -ForegroundColor Green
    Write-Host "====================================================" -ForegroundColor Green
    
    # Let the user know they can now change their wallpaper
    Write-Host "You can now change your wallpaper using Windows Settings or Control Panel." -ForegroundColor Yellow
    
    exit 0 # success
} catch {
    Write-Host "[ERROR] Script failed at line $($_.InvocationInfo.ScriptLineNumber): $($Error[0])" -ForegroundColor Red
    Write-Host "[ERROR DETAILS] $($_)" -ForegroundColor Red
    exit 1
} 