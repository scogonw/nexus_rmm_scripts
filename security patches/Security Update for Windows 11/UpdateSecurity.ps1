# Windows 11 Security Updates Installer
# This script downloads and installs all available security updates for Windows 11
# Run this script as an administrator for best results

# Set up logging
$LogFile = "C:\Logs\Windows11_Security_Updates_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$LogDir = Split-Path $LogFile -Parent

# Create log directory if it doesn't exist
if (!(Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

# Function to write to log file and console
function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "[$TimeStamp] [$Level] $Message"
    
    Write-Host $LogMessage
    Add-Content -Path $LogFile -Value $LogMessage
}

# Start logging
Write-Log "Starting Windows 11 security updates installation"
Write-Log "Log file created at: $LogFile"

# Check if running as administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Log "Script is not running with administrator privileges. Some updates may fail to install." "WARNING"
    Write-Log "For best results, restart this script with administrator privileges." "WARNING"
}

try {
    # Create Windows Update session
    Write-Log "Creating Windows Update session"
    $UpdateSession = New-Object -ComObject Microsoft.Update.Session
    
    # Create update searcher
    $UpdateSearcher = $UpdateSession.CreateUpdateSearcher()
    
    # Search for security updates
    Write-Log "Searching for security updates"
    $SearchCriteria = "IsInstalled=0 and CategoryIDs contains '0fa1201d-4330-4fa8-8ae9-b877473b6441' and Type='Software'"
    $SearchResult = $UpdateSearcher.Search($SearchCriteria)
    
    $Updates = $SearchResult.Updates
    $UpdateCount = $Updates.Count
    
    Write-Log "Found $UpdateCount security updates available for installation"
    
    if ($UpdateCount -eq 0) {
        Write-Log "No security updates available. Your system is up to date."
    }
    else {
        # Create update collection for download
        $UpdatesToDownload = New-Object -ComObject Microsoft.Update.UpdateColl
        
        # Add all updates to collection
        foreach ($Update in $Updates) {
            if ($Update.EulaAccepted -eq $false) {
                $Update.AcceptEula()
            }
            $UpdatesToDownload.Add($Update) | Out-Null
            Write-Log "Added update to download queue: $($Update.Title)"
        }
        
        # Download updates
        Write-Log "Downloading $UpdateCount updates"
        $Downloader = $UpdateSession.CreateUpdateDownloader()
        $Downloader.Updates = $UpdatesToDownload
        $DownloadResult = $Downloader.Download()
        
        # Check download result
        if ($DownloadResult.ResultCode -eq 2) {
            Write-Log "Successfully downloaded all updates"
            
            # Create update collection for installation
            $UpdatesToInstall = New-Object -ComObject Microsoft.Update.UpdateColl
            
            # Add downloaded updates to installation collection
            foreach ($Update in $Updates) {
                if ($Update.IsDownloaded) {
                    $UpdatesToInstall.Add($Update) | Out-Null
                    Write-Log "Added update to installation queue: $($Update.Title)"
                }
                else {
                    Write-Log "Update was not downloaded successfully: $($Update.Title)" "ERROR"
                }
            }
            
            # Install updates
            if ($UpdatesToInstall.Count -gt 0) {
                Write-Log "Installing $($UpdatesToInstall.Count) updates"
                $Installer = $UpdateSession.CreateUpdateInstaller()
                $Installer.Updates = $UpdatesToInstall
                $InstallResult = $Installer.Install()
                
                # Log installation results
                Write-Log "Installation completed with result code: $($InstallResult.ResultCode)"
                Write-Log "Reboot required: $($InstallResult.RebootRequired)"
                
                if ($InstallResult.RebootRequired) {
                    Write-Log "System restart is required to complete update installation" "WARNING"
                    $RestartPrompt = Read-Host "Do you want to restart the computer now? (Y/N)"
                    if ($RestartPrompt -eq "Y" -or $RestartPrompt -eq "y") {
                        Write-Log "Initiating system restart"
                        Restart-Computer -Force
                    }
                    else {
                        Write-Log "System restart postponed. Please restart your computer as soon as possible."
                    }
                }
            }
            else {
                Write-Log "No updates were successfully downloaded" "ERROR"
            }
        }
        else {
            Write-Log "Failed to download updates. Result code: $($DownloadResult.ResultCode)" "ERROR"
        }
    }
}
catch {
    Write-Log "An error occurred: $($_.Exception.Message)" "ERROR"
    Write-Log "Stack trace: $($_.ScriptStackTrace)" "ERROR"
}
finally {
    Write-Log "Windows 11 security update process completed"
    Write-Log "See log file for details: $LogFile"
}