# DefenderUpdate.ps1
# This script updates Windows Defender definitions

# Ensure the script runs with administrative privileges
$adminCheck = [System.Security.Principal.WindowsPrincipal] [System.Security.Principal.WindowsIdentity]::GetCurrent()
$adminRole = [System.Security.Principal.WindowsBuiltInRole]::Administrator
if (-Not $adminCheck.IsInRole($adminRole)) {
    Write-Host "Please run this script as Administrator!" -ForegroundColor Red
    Pause
    Exit
}

Write-Host "Checking Windows Defender status..." -ForegroundColor Cyan

# Check if Windows Defender service is running
$defenderStatus = Get-Service -Name WinDefend -ErrorAction SilentlyContinue

if ($null -eq $defenderStatus -or $defenderStatus.Status -ne "Running") {
    Write-Host "Windows Defender is not running or not available on this system." -ForegroundColor Red
    Pause
    Exit
}

Write-Host "Updating Windows Defender definitions..." -ForegroundColor Yellow

# Update Windows Defender definitions
$updateResult = Update-MpSignature

if ($updateResult -eq $null) {
    Write-Host "Windows Defender definitions updated successfully!" -ForegroundColor Green
} else {
    Write-Host "Failed to update Windows Defender definitions!" -ForegroundColor Red
}

# Keep the window open
Write-Host "Press any key to exit..."
[System.Console]::ReadKey() | Out-Null
