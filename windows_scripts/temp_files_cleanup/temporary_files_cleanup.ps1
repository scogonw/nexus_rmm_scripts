#############################################################
# Windows Temporary Files Cleanup Utility
# Purpose: Automate cleanup of temporary files to improve system performance
# Usage: Run as administrator via Group Policy or scheduled task
# Parameters:
#   -TestMode           : Only report files to be deleted without removing them
#   -LogPath            : Custom path for log files
#   -WindowsDrive       : Drive letter where Windows is installed (default: C:)
#   -SkipPrefetch       : Skip cleaning the prefetch folder
#   -DaysToKeep         : Number of days of temp files to keep (default: 0)
#############################################################

param (
    [switch]$TestMode,
    [string]$LogPath,
    [string]$WindowsDrive = "C:",
    [switch]$SkipPrefetch,
    [int]$DaysToKeep = 0
)

# Check OS compatibility
$osInfo = Get-WmiObject -Class Win32_OperatingSystem
$osVersion = [System.Version]$osInfo.Version
$minVersion = [System.Version]"6.1.0.0" # Windows 7/Server 2008 R2
$maxTestedVersion = [System.Version]"10.0.22000.0" # Windows 11/Server 2022

if ($osVersion -lt $minVersion) {
    Write-Warning "This script was designed for Windows 7/Server 2008 R2 and later. Your OS version ($($osInfo.Caption)) may not be fully compatible."
    $confirmContinue = Read-Host "Do you want to continue anyway? (Y/N)"
    if ($confirmContinue -ne "Y") {
        exit 1
    }
}

if ($osVersion -gt $maxTestedVersion) {
    Write-Warning "This script has been tested up to Windows 11/Server 2022. Your OS version ($($osInfo.Caption)) is newer and some functions may behave differently."
}

# Ensure script is running with administrator privileges
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "This script requires administrator privileges. Please restart with elevated permissions."
    exit 1
}

# Determine Windows and log paths - Fix for the colon issue
# Clean up drive letter format - extract just the drive letter
$DriveLetter = $WindowsDrive.Trim() -replace '[\\:]+$', '' -replace '^([a-zA-Z]).*$', '$1'
# Construct proper Windows path with drive letter
$WindowsPath = $DriveLetter + ":\Windows"

# Check if Windows path exists
if (-not (Test-Path -Path $WindowsPath)) {
    Write-Warning "Windows folder not found at $WindowsPath. Please specify the correct drive with -WindowsDrive parameter."
    exit 1
}

# Set up logging
if (-not $LogPath) {
    $LogPath = $DriveLetter + ":\Windows\Logs"
}

if (-not (Test-Path -Path $LogPath)) {
    try {
        New-Item -Path $LogPath -ItemType Directory -Force | Out-Null
    }
    catch {
        Write-Warning "Cannot create log directory at $LogPath. Using system temp folder instead."
        $LogPath = [System.IO.Path]::GetTempPath()
    }
}
$LogFile = "$LogPath\TempFileCleanup_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$ScriptStartTime = Get-Date

# Initialize counters for metrics
$TotalFilesDeleted = 0
$TotalSpaceFreed = 0
$LocationStats = @{}

# Get initial disk space on Windows drive
$InitialFreeSpace = (Get-PSDrive $DriveLetter | Select-Object -ExpandProperty Free)

function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "$TimeStamp [$Level] $Message"
    Add-Content -Path $LogFile -Value $LogEntry
    
    # Also write to console with appropriate color
    switch ($Level) {
        "INFO" { Write-Host $Message -ForegroundColor Green }
        "WARNING" { Write-Host $Message -ForegroundColor Yellow }
        "ERROR" { Write-Host $Message -ForegroundColor Red }
        default { Write-Host $Message }
    }
}

# Initialize log
Write-Log "Starting temporary file cleanup process on $env:COMPUTERNAME"
Write-Log "Running as user: $env:USERNAME"
Write-Log "Mode: $(if ($TestMode) { 'TEST (No files will be deleted)' } else { 'CLEAN' })"
Write-Log "Operating System: $($osInfo.Caption) (Version $($osInfo.Version))"

# Function to safely remove files
function Remove-TempFiles {
    param (
        [string]$Path,
        [string]$Description,
        [int]$DaysToKeep = 0,
        [switch]$TestMode
    )
    
    Write-Log "Processing $Description at path: $Path"
    
    if (-not (Test-Path -Path $Path)) {
        Write-Log "Path not found: $Path" -Level "WARNING"
        return
    }
    
    try {
        # Calculate total size before cleanup
        $sizeBeforeCleanup = 0
        $filesBeforeCleanup = Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue
        if ($filesBeforeCleanup) {
            $sizeBeforeCleanup = ($filesBeforeCleanup | Measure-Object -Property Length -Sum).Sum
        }
        
        $filesToRemove = Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue |
                         Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$DaysToKeep) }
        
        $totalFiles = ($filesToRemove | Measure-Object).Count
        $totalSize = 0
        if ($filesToRemove) {
            $totalSize = ($filesToRemove | Measure-Object -Property Length -Sum).Sum
        }
        
        Write-Log "Found $totalFiles temp files to remove in $Description (Size: $([math]::Round($totalSize/1MB, 2)) MB)"
        
        if ($totalFiles -gt 0) {
            if ($TestMode) {
                Write-Log "TEST MODE: Would delete $totalFiles files (Size: $([math]::Round($totalSize/1MB, 2)) MB)" -Level "WARNING"
                
                # Update stats for reporting in test mode
                $script:TotalFilesDeleted += $totalFiles
                $script:TotalSpaceFreed += $totalSize
                $script:LocationStats[$Description] = @{
                    "FilesDeleted" = $totalFiles
                    "SpaceFreed" = $totalSize
                }
            }
            else {
                # Add a safety check for unexpectedly large deletion operations
                if ($totalFiles -gt 10000) {
                    Write-Log "WARNING: Attempting to delete more than 10,000 files ($totalFiles). This is unusual." -Level "WARNING"
                    $confirmLargeDeletion = Read-Host "Continue with deletion of $totalFiles files? (Y/N)"
                    if ($confirmLargeDeletion -ne "Y") {
                        Write-Log "Large file deletion skipped by user choice" -Level "WARNING"
                        return
                    }
                }
                
                # Try to handle in-use files more gracefully
                $successfullyDeleted = 0
                $failedToDelete = 0
                
                foreach ($file in $filesToRemove) {
                    try {
                        Remove-Item -Path $file.FullName -Force -ErrorAction Stop
                        $successfullyDeleted++
                    }
                    catch [System.IO.IOException] {
                        # File is likely in use
                        $failedToDelete++
                    }
                    catch {
                        # Other error
                        $failedToDelete++
                        Write-Log "Error deleting file $($file.FullName): $_" -Level "ERROR"
                    }
                }
                
                # Calculate space after cleanup
                $sizeAfterCleanup = 0
                $filesAfterCleanup = Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue
                if ($filesAfterCleanup) {
                    $sizeAfterCleanup = ($filesAfterCleanup | Measure-Object -Property Length -Sum).Sum
                }
                
                $actualSpaceFreed = $sizeBeforeCleanup - $sizeAfterCleanup
                
                Write-Log "Successfully deleted $successfullyDeleted files from $Description (Freed: $([math]::Round($actualSpaceFreed/1MB, 2)) MB)"
                if ($failedToDelete -gt 0) {
                    Write-Log "Failed to delete $failedToDelete files (likely in use)" -Level "WARNING"
                }
                
                # Update global counters
                $script:TotalFilesDeleted += $successfullyDeleted
                $script:TotalSpaceFreed += $actualSpaceFreed
                $script:LocationStats[$Description] = @{
                    "FilesDeleted" = $successfullyDeleted
                    "SpaceFreed" = $actualSpaceFreed
                    "FailedDeletes" = $failedToDelete
                }
            }
        }
        
        # Try to remove empty directories
        if (-not $TestMode) {
            Get-ChildItem -Path $Path -Recurse -Directory -ErrorAction SilentlyContinue | 
            Where-Object { (Get-ChildItem -Path $_.FullName -Recurse -File -ErrorAction SilentlyContinue | Measure-Object).Count -eq 0 } | 
            ForEach-Object {
                try {
                    Remove-Item -Path $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
                }
                catch {
                    # Silently continue if directory can't be removed
                }
            }
        }
    }
    catch {
        Write-Log "Error cleaning $Description`: $_" -Level "ERROR"
    }
}

# 1. Clean Windows Temp folder
Remove-TempFiles -Path "$WindowsPath\Temp" -Description "Windows Temp Folder" -DaysToKeep $DaysToKeep -TestMode:$TestMode

# 2. Clean Windows Prefetch folder if not skipped
if (-not $SkipPrefetch) {
    Write-Log "Note: Cleaning Prefetch may temporarily slow application launches until Windows rebuilds these files" -Level "WARNING"
    Remove-TempFiles -Path "$WindowsPath\Prefetch" -Description "Windows Prefetch Folder" -DaysToKeep $DaysToKeep -TestMode:$TestMode
}
else {
    Write-Log "Skipping Prefetch folder cleanup as requested"
}

# 3. Clean User Temp folders
$userProfiles = Get-ChildItem -Path "$DriveLetter`:\Users" -Directory -ErrorAction SilentlyContinue | 
                Where-Object { $_.Name -ne "Public" -and $_.Name -ne "Default" -and $_.Name -ne "Default User" }

foreach ($profile in $userProfiles) {
    $tempPath = Join-Path -Path $profile.FullName -ChildPath "AppData\Local\Temp"
    Remove-TempFiles -Path $tempPath -Description "User Temp Folder for $($profile.Name)" -DaysToKeep $DaysToKeep -TestMode:$TestMode
    
    # Clean browser caches if needed (commented out by default)
    # $chromeCachePath = Join-Path -Path $profile.FullName -ChildPath "AppData\Local\Google\Chrome\User Data\Default\Cache"
    # Remove-TempFiles -Path $chromeCachePath -Description "Chrome Cache for $($profile.Name)" -DaysToKeep $DaysToKeep -TestMode:$TestMode
}

# 4. Run Windows Disk Cleanup tool safely (only in real mode, not test mode)
if (-not $TestMode) {
    # Check if cleanmgr.exe exists before attempting to use it
    $cleanmgrPath = "$WindowsPath\System32\cleanmgr.exe"
    if (Test-Path -Path $cleanmgrPath) {
        Write-Log "Running Windows Disk Cleanup utility"
        try {
            # Set up Disk Cleanup for common temp files only (safest options)
            $regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches"
            
            # Ensure only temp file types are selected for cleanup
            $safeCleanupTypes = @(
                "Temporary Files",
                "Temporary Setup Files", 
                "System error memory dump files",
                "System error minidump files",
                "Windows Error Reporting Files"
            )
            
            # Backup registry state
            $backupRegPath = "$env:TEMP\CleanupRegBackup_$(Get-Date -Format 'yyyyMMdd_HHmmss').reg"
            Start-Process -FilePath "reg.exe" -ArgumentList "export `"$regPath`" `"$backupRegPath`"" -Wait -WindowStyle Hidden
            Write-Log "Registry state backed up to $backupRegPath for rollback if needed"
            
            Get-ChildItem $regPath -ErrorAction SilentlyContinue | ForEach-Object {
                $cleanupName = Split-Path $_.Name -Leaf
                if ($safeCleanupTypes -contains $cleanupName) {
                    Set-ItemProperty -Path "$regPath\$cleanupName" -Name "StateFlags0001" -Value 2 -ErrorAction SilentlyContinue
                } else {
                    Set-ItemProperty -Path "$regPath\$cleanupName" -Name "StateFlags0001" -Value 0 -ErrorAction SilentlyContinue
                }
            }
            
            # Run Disk Cleanup silently
            Start-Process -FilePath $cleanmgrPath -ArgumentList "/sagerun:1" -Wait -WindowStyle Hidden
            Write-Log "Windows Disk Cleanup completed successfully"
        }
        catch {
            Write-Log "Error running Disk Cleanup: $_" -Level "ERROR"
            Write-Log "Attempting to restore registry from backup" -Level "WARNING"
            
            # Attempt to restore from backup if it exists
            if (Test-Path -Path $backupRegPath) {
                Start-Process -FilePath "reg.exe" -ArgumentList "import `"$backupRegPath`"" -Wait -WindowStyle Hidden
                Write-Log "Registry restoration attempted"
            }
        }
    }
    else {
        Write-Log "Disk Cleanup utility (cleanmgr.exe) not found - skipping this step" -Level "WARNING"
    }
}
else {
    Write-Log "TEST MODE: Skipping Windows Disk Cleanup utility"
}

# Calculate space savings and execution time
$ScriptEndTime = Get-Date
$ExecutionTime = $ScriptEndTime - $ScriptStartTime

# Get final disk space on Windows drive and calculate actual change
$FinalFreeSpace = 0
$TotalDiskSpaceFreed = 0

if (-not $TestMode) {
    $FinalFreeSpace = (Get-PSDrive $DriveLetter | Select-Object -ExpandProperty Free)
    $TotalDiskSpaceFreed = $FinalFreeSpace - $InitialFreeSpace
}

# Report cleanup metrics
Write-Log "=========== CLEANUP METRICS ==========="
if ($TestMode) {
    Write-Log "TEST MODE SUMMARY - No files were actually deleted"
    Write-Log "Total files that would be deleted: $TotalFilesDeleted"
    Write-Log "Total space that would be freed: $([math]::Round($TotalSpaceFreed/1MB, 2)) MB ($([math]::Round($TotalSpaceFreed/1GB, 2)) GB)"
}
else {
    Write-Log "Total files deleted: $TotalFilesDeleted"
    Write-Log "Total space freed: $([math]::Round($TotalSpaceFreed/1MB, 2)) MB ($([math]::Round($TotalSpaceFreed/1GB, 2)) GB)"
    Write-Log "Actual disk space change: $([math]::Round($TotalDiskSpaceFreed/1MB, 2)) MB ($([math]::Round($TotalDiskSpaceFreed/1GB, 2)) GB)"
}
Write-Log "Execution time: $($ExecutionTime.TotalMinutes.ToString('0.00')) minutes"

# Report statistics per location
Write-Log "========== LOCATION BREAKDOWN =========="
foreach ($location in $LocationStats.Keys) {
    $stats = $LocationStats[$location]
    $failedMsg = ""
    if ($stats.ContainsKey("FailedDeletes") -and $stats.FailedDeletes -gt 0) {
        $failedMsg = " (Failed to delete: $($stats.FailedDeletes))"
    }
    Write-Log "$location - Files: $($stats.FilesDeleted)$failedMsg, Space Freed: $([math]::Round($stats.SpaceFreed/1MB, 2)) MB"
}

Write-Log "Temporary file cleanup $(if ($TestMode) { 'analysis' } else { 'operation' }) completed on $env:COMPUTERNAME"

# Output log file location for reference
Write-Host "`nLog file created at: $LogFile" -ForegroundColor Cyan

# End of script 