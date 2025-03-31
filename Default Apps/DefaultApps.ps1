# Default App Reset Script

Write-Host "Starting Default App Reset..." -ForegroundColor Cyan

# Confirm with the user before proceeding
$confirmation = Read-Host "Are you sure you want to reset all default apps? This will restore system defaults. (Y/N)"
if ($confirmation -match "^[Nn]$") {
    Write-Host "Operation canceled by user." -ForegroundColor Yellow
    exit
}

# Execute the command to reset default apps
Write-Host "Resetting default apps to system defaults..." -ForegroundColor Yellow
try {
    Get-AppxPackage *WindowsDefaultApps* | Reset-AppxPackage
    Write-Host "Default apps have been reset successfully." -ForegroundColor Green
} catch {
    Write-Host "An error occurred while resetting default apps." -ForegroundColor Red
}

# Wait for user input before closing
Write-Host "Press Enter to exit..." -ForegroundColor Cyan
Read-Host
