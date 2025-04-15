# Airplane Mode Toggle Script (Emulating Airplane Mode)

# Ensure script runs with administrative privileges
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "This script requires Administrator privileges." -ForegroundColor Red
    Write-Host "Please run this script as Administrator." -ForegroundColor Red
    exit 1
}

Write-Host "Airplane Mode Toggle Script" -ForegroundColor Cyan

# Function to check the status of Wi-Fi and Bluetooth adapters
function Get-AirplaneModeStatus {
    try {
        $wifi = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "Wi-Fi" -or $_.InterfaceDescription -match "Wireless" }
        $bluetooth = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "Bluetooth" }
        
        $wirelessUp = $false
        
        if ($wifi -and ($wifi.Status -eq "Up")) {
            $wirelessUp = $true
        }
        
        if ($bluetooth -and ($bluetooth.Status -eq "Up")) {
            $wirelessUp = $true
        }
        
        if ($wirelessUp) {
            Write-Host "Airplane Mode: OFF (Wireless adapters are enabled)" -ForegroundColor Yellow
            return "off"
        } else {
            Write-Host "Airplane Mode: ON (Wireless adapters are disabled)" -ForegroundColor Green
            return "on"
        }
    } catch {
        Write-Host "Error checking adapter status: $_" -ForegroundColor Red
        return $null
    }
}

# Function to toggle Airplane Mode
function Set-AirplaneMode {
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet("on", "off", "toggle")]
        [string]$Action
    )
    
    try {
        # Get current status if action is toggle
        if ($Action -eq "toggle") {
            $currentStatus = Get-AirplaneModeStatus
            if ($currentStatus -eq "on") {
                $Action = "off"
            } else {
                $Action = "on"
            }
        }
        
        $wifi = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "Wi-Fi" -or $_.InterfaceDescription -match "Wireless" }
        $bluetooth = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "Bluetooth" }
        
        if ($Action -eq "on") {
            Write-Host "Turning Airplane Mode ON (Disabling wireless adapters)..." -ForegroundColor Yellow
            if ($wifi) {
                $wifi | Disable-NetAdapter -Confirm:$false -ErrorAction SilentlyContinue
            }
            if ($bluetooth) {
                $bluetooth | Disable-NetAdapter -Confirm:$false -ErrorAction SilentlyContinue
            }
            return $true
        } elseif ($Action -eq "off") {
            Write-Host "Turning Airplane Mode OFF (Enabling wireless adapters)..." -ForegroundColor Yellow
            if ($wifi) {
                $wifi | Enable-NetAdapter -Confirm:$false -ErrorAction SilentlyContinue
            }
            if ($bluetooth) {
                $bluetooth | Enable-NetAdapter -Confirm:$false -ErrorAction SilentlyContinue
            }
            return $true
        }
    } catch {
        Write-Host "Error toggling airplane mode: $_" -ForegroundColor Red
        return $false
    }
}

# Check for command line arguments (useful for RMM deployments)
param (
    [Parameter(Position=0)]
    [ValidateSet("on", "off", "toggle", "status")]
    [string]$Mode = ""
)

# Display current status
$currentStatus = Get-AirplaneModeStatus

# Process based on arguments or interactive input
if ($Mode -eq "") {
    # Interactive mode
    $choice = Read-Host "Enter 'on' to enable Airplane Mode, 'off' to disable it, or 'toggle' to switch"
    if ($choice -in @("on", "off", "toggle")) {
        Set-AirplaneMode -Action $choice
    } else {
        Write-Host "Invalid option. Use 'on', 'off', or 'toggle'." -ForegroundColor Red
    }
    
    # Confirm the change
    Get-AirplaneModeStatus
    
    # Wait for user input before closing
    Write-Host "Press Enter to exit..." -ForegroundColor Cyan
    Read-Host
} else {
    # Non-interactive mode (for RMM)
    if ($Mode -eq "status") {
        # Just display status
        exit 0
    } else {
        $result = Set-AirplaneMode -Action $Mode
        Get-AirplaneModeStatus
        if ($result) {
            exit 0
        } else {
            exit 1
        }
    }
}
