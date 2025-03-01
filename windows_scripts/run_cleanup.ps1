#############################################################
# Windows Temporary Files Cleanup Launcher
# This PowerShell script downloads the main cleanup script from GitHub,
# handles execution policy restrictions, and runs the script.
#############################################################

# Clear the screen
Clear-Host

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Windows Temporary Files Cleanup Utility" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Check if running as administrator
function Test-Administrator {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Administrator)) {
    Write-Host "This script requires administrator privileges." -ForegroundColor Red
    Write-Host "Please run PowerShell as Administrator and try again." -ForegroundColor Red
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

# Set up script locations
$randomSuffix = Get-Random -Minimum 10000 -Maximum 99999
$tempDir = Join-Path -Path $env:TEMP -ChildPath "TempCleanup_$randomSuffix"
$psScriptPath = Join-Path -Path $tempDir -ChildPath "temporary_files_cleanup.ps1"

# Set GitHub URL for the PowerShell script
$psScriptUrl = "https://raw.githubusercontent.com/scogonw/nexus_rmm_scripts/refs/heads/main/windows_scripts/temporary_files_cleanup.ps1"

# Create temporary directory
if (-not (Test-Path -Path $tempDir)) {
    New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
}

# Download the script
Write-Host "Downloading cleanup script from GitHub..." -ForegroundColor Yellow
Write-Host "Source: $psScriptUrl"
Write-Host ""

try {
    # Create a WebClient object to download the script
    $webClient = New-Object System.Net.WebClient
    $webClient.DownloadFile($psScriptUrl, $psScriptPath)
    
    # Verify download succeeded
    if (-not (Test-Path -Path $psScriptPath)) {
        throw "Failed to download the script"
    }
    
    Write-Host "PowerShell script successfully downloaded." -ForegroundColor Green
    Write-Host ""
    
    # Process command line arguments
    $scriptArgs = $args
    
    # If no parameters specified, run with defaults
    if ($scriptArgs.Count -eq 0) {
        Write-Host "No parameters specified - running with default settings (production mode)." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Default settings:"
        Write-Host "- Windows Drive: C:"
        Write-Host "- Days to Keep: 0 (delete all temporary files regardless of age)"
        Write-Host "- Prefetch cleaning: Enabled"
        Write-Host "- Mode: Production (files will be deleted)"
        Write-Host ""
        Write-Host "To run in test mode, use: .\$(Split-Path $MyInvocation.MyCommand.Path -Leaf) -TestMode" -ForegroundColor Cyan
        Write-Host ""
    }
    
    # Build the command to execute
    $command = "& '$psScriptPath'"
    if ($scriptArgs.Count -gt 0) {
        $command += " $($scriptArgs -join ' ')"
    }
    
    Write-Host "Executing cleanup script..." -ForegroundColor Yellow
    Write-Host "Command: $command"
    Write-Host ""
    
    # Execute the script
    $global:LASTEXITCODE = 0
    Invoke-Expression $command
    
    # Check script execution status
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "The cleanup script encountered an error (Exit code: $LASTEXITCODE)." -ForegroundColor Red
        Write-Host ""
    } else {
        Write-Host ""
        Write-Host "Cleanup completed successfully." -ForegroundColor Green
        Write-Host ""
    }
} 
catch {
    Write-Host "ERROR: $_" -ForegroundColor Red
    Write-Host "Script execution failed." -ForegroundColor Red
}
finally {
    # Clean up the downloaded script
    Write-Host "Cleaning up temporary files..." -ForegroundColor Yellow
    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    
    # In RMM context, this might be unnecessary, but included for interactive use
    if (-not $env:RMM_CONTEXT) {
        Read-Host "Press Enter to exit"
    }
}

# End of script 