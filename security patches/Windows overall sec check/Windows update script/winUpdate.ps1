# Check for Windows Updates and install them
Write-Host "Checking for Windows Updates..." -ForegroundColor Cyan

# Import the required module
Install-Module -Name PSWindowsUpdate -Force -Scope CurrentUser -ErrorAction SilentlyContinue

# Load the module
Import-Module PSWindowsUpdate

# Check for available updates
$Updates = Get-WindowsUpdate

if ($Updates) {
    Write-Host "Updates found. Installing updates..." -ForegroundColor Yellow
    # Install the updates
    Install-WindowsUpdate -AcceptAll -AutoReboot
} else {
    Write-Host "No updates available." -ForegroundColor Green
}

# Wait for user input before closing
Write-Host "Press Enter to exit..." -ForegroundColor Cyan
Read-Host
