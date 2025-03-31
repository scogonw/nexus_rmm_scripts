# Airplane Mode Toggle Script (Emulating Airplane Mode)

Write-Host "Airplane Mode Toggle Script" -ForegroundColor Cyan

# Function to check the status of Wi-Fi and Bluetooth adapters
function Get-AirplaneModeStatus {
    $wifi = Get-NetAdapter | Where-Object { $_.Name -match "Wi-Fi" -or $_.InterfaceDescription -match "Wireless" }
    $bluetooth = Get-NetAdapter | Where-Object { $_.Name -match "Bluetooth" }
    
    if ($wifi.Status -eq "Up" -or $bluetooth.Status -eq "Up") {
        Write-Host "Airplane Mode: OFF (Wireless adapters are enabled)" -ForegroundColor Yellow
    } else {
        Write-Host "Airplane Mode: ON (Wireless adapters are disabled)" -ForegroundColor Green
    }
}

# Function to toggle Airplane Mode
function Set-AirplaneMode {
    param (
        [string]$action
    )
    $wifi = Get-NetAdapter | Where-Object { $_.Name -match "Wi-Fi" -or $_.InterfaceDescription -match "Wireless" }
    $bluetooth = Get-NetAdapter | Where-Object { $_.Name -match "Bluetooth" }
    
    if ($action -eq "on") {
        Write-Host "Turning Airplane Mode ON (Disabling wireless adapters)..." -ForegroundColor Yellow
        $wifi | Disable-NetAdapter -Confirm:$false
        $bluetooth | Disable-NetAdapter -Confirm:$false
    } elseif ($action -eq "off") {
        Write-Host "Turning Airplane Mode OFF (Enabling wireless adapters)..." -ForegroundColor Yellow
        $wifi | Enable-NetAdapter -Confirm:$false
        $bluetooth | Enable-NetAdapter -Confirm:$false
    } else {
        Write-Host "Invalid option. Use 'on' or 'off'." -ForegroundColor Red
    }
}

# Display current status
Get-AirplaneModeStatus

# Ask user for input
$choice = Read-Host "Enter 'on' to enable Airplane Mode or 'off' to disable it"
Set-AirplaneMode -action $choice

# Confirm the change
Get-AirplaneModeStatus

# Wait for user input before closing
Write-Host "Press Enter to exit..." -ForegroundColor Cyan
Read-Host
