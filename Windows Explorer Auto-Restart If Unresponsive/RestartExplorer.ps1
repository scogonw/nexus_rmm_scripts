# Windows Explorer Auto-Restart If Unresponsive

Write-Host "Checking if Windows Explorer is responsive..." -ForegroundColor Cyan

# Check if explorer.exe is running
$explorerProcess = Get-Process -Name explorer -ErrorAction SilentlyContinue

if ($explorerProcess) {
    Write-Host "Windows Explorer is running." -ForegroundColor Green
    
    # Ask the user if they want to restart it anyway
    $restartChoice = Read-Host "Do you want to restart Explorer? (Y/N)"
    if ($restartChoice -match "^[Yy]$") {
        Write-Host "Restarting Windows Explorer..." -ForegroundColor Yellow
        Stop-Process -Name explorer -Force
        Start-Process explorer
        Write-Host "Windows Explorer restarted successfully!" -ForegroundColor Green
    } else {
        Write-Host "No changes made. Explorer will continue running." -ForegroundColor Cyan
    }
} else {
    Write-Host "Windows Explorer is not running! Attempting to restart..." -ForegroundColor Red
    Start-Process explorer
    Write-Host "Windows Explorer started successfully!" -ForegroundColor Green
}

# Wait for user input before closing
Write-Host "Press Enter to exit..." -ForegroundColor Cyan
Read-Host
