<#
.SYNOPSIS
    Software Installation & Updates Checker (sia)
.DESCRIPTION
    A PowerShell script that simplifies software installation and updates using winget or chocolatey
.EXAMPLE
    sia install firefox
    sia update chrome
    sia search vscode
    sia list
.NOTES
    Author: Claude
    Date: March 30, 2025
#>

param (
    [Parameter(Position=0)]
    [string]$Command,
    
    [Parameter(Position=1, ValueFromRemainingArguments=$true)]
    [string[]]$Arguments
)

# Configuration
$DefaultPackageManager = "winget" # Options: "winget" or "choco"
$ConfigFile = "$env:USERPROFILE\.sia_config.json"

# Function to load configuration
function Load-Config {
    if (Test-Path $ConfigFile) {
        try {
            $config = Get-Content $ConfigFile | ConvertFrom-Json
            return $config
        } catch {
            Write-Host "Error loading configuration. Using defaults." -ForegroundColor Yellow
        }
    }
    
    # Default config
    return @{
        PackageManager = $DefaultPackageManager
    } | ConvertTo-Json | ConvertFrom-Json
}

# Function to save configuration
function Save-Config {
    param (
        [PSCustomObject]$Config
    )
    
    try {
        $Config | ConvertTo-Json | Set-Content $ConfigFile
        Write-Host "Configuration saved." -ForegroundColor Green
    } catch {
        Write-Host "Error saving configuration." -ForegroundColor Red
    }
}

# Function to check if a package manager is installed
function Test-PackageManager {
    param (
        [string]$PackageManager
    )
    
    switch ($PackageManager) {
        "winget" {
            try {
                $null = winget -v
                return $true
            } catch {
                return $false
            }
        }
        "choco" {
            try {
                $null = choco -v
                return $true
            } catch {
                return $false
            }
        }
        default {
            return $false
        }
    }
}

# Function to execute commands using the selected package manager
function Invoke-PackageManagerCommand {
    param (
        [string]$PackageManager,
        [string]$Command,
        [string[]]$Arguments
    )
    
    switch ($PackageManager) {
        "winget" {
            switch ($Command) {
                "install" { 
                    Write-Host "Installing $($Arguments -join ' ') using winget..." -ForegroundColor Cyan
                    winget install $Arguments 
                }
                "update" { 
                    if ($Arguments.Count -eq 0) {
                        Write-Host "Updating all packages using winget..." -ForegroundColor Cyan
                        winget upgrade --all
                    } else {
                        Write-Host "Updating $($Arguments -join ' ') using winget..." -ForegroundColor Cyan
                        winget upgrade $Arguments
                    }
                }
                "search" { 
                    Write-Host "Searching for $($Arguments -join ' ') using winget..." -ForegroundColor Cyan
                    winget search $Arguments 
                }
                "list" { 
                    Write-Host "Listing installed packages using winget..." -ForegroundColor Cyan
                    winget list 
                }
                "uninstall" { 
                    Write-Host "Uninstalling $($Arguments -join ' ') using winget..." -ForegroundColor Cyan
                    winget uninstall $Arguments 
                }
                default { 
                    Write-Host "Unknown command: $Command" -ForegroundColor Red
                    Show-Help
                }
            }
        }
        "choco" {
            switch ($Command) {
                "install" { 
                    Write-Host "Installing $($Arguments -join ' ') using chocolatey..." -ForegroundColor Cyan
                    choco install $Arguments -y
                }
                "update" { 
                    if ($Arguments.Count -eq 0) {
                        Write-Host "Updating all packages using chocolatey..." -ForegroundColor Cyan
                        choco upgrade all -y
                    } else {
                        Write-Host "Updating $($Arguments -join ' ') using chocolatey..." -ForegroundColor Cyan
                        choco upgrade $Arguments -y
                    }
                }
                "search" { 
                    Write-Host "Searching for $($Arguments -join ' ') using chocolatey..." -ForegroundColor Cyan
                    choco search $Arguments 
                }
                "list" { 
                    Write-Host "Listing installed packages using chocolatey..." -ForegroundColor Cyan
                    choco list --local-only
                }
                "uninstall" { 
                    Write-Host "Uninstalling $($Arguments -join ' ') using chocolatey..." -ForegroundColor Cyan
                    choco uninstall $Arguments -y
                }
                default { 
                    Write-Host "Unknown command: $Command" -ForegroundColor Red
                    Show-Help
                }
            }
        }
    }
}

# Function to display help information
function Show-Help {
    Write-Host "Software Installation & Updates Checker (sia)" -ForegroundColor Cyan
    Write-Host "Usage: sia [command] [arguments]" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Commands:" -ForegroundColor Yellow
    Write-Host "  install [package]   - Install a package"
    Write-Host "  update [package]    - Update a package (or all packages if none specified)"
    Write-Host "  search [query]      - Search for packages"
    Write-Host "  list                - List installed packages"
    Write-Host "  uninstall [package] - Uninstall a package"
    Write-Host "  config [option]     - Configure sia"
    Write-Host "    pm=[winget|choco] - Set package manager"
    Write-Host "  help                - Show this help"
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Yellow
    Write-Host "  sia install firefox"
    Write-Host "  sia update chrome"
    Write-Host "  sia search vscode"
    Write-Host "  sia list"
    Write-Host "  sia config pm=choco"
}

# Main script logic
$Config = Load-Config

# Handle config command
if ($Command -eq "config") {
    foreach ($arg in $Arguments) {
        if ($arg -match "pm=(winget|choco)") {
            $Config.PackageManager = $Matches[1]
            Write-Host "Package manager set to $($Config.PackageManager)" -ForegroundColor Green
        } else {
            Write-Host "Unknown config option: $arg" -ForegroundColor Red
        }
    }
    
    Save-Config -Config $Config
    exit
}

# Handle help command
if ($Command -eq "help" -or $Command -eq "" -or $null -eq $Command) {
    Show-Help
    exit
}

# Check if the configured package manager is installed
if (-not (Test-PackageManager -PackageManager $Config.PackageManager)) {
    Write-Host "Package manager '$($Config.PackageManager)' is not installed or not available." -ForegroundColor Red
    
    # Check if the alternative package manager is available
    $AlternativePackageManager = if ($Config.PackageManager -eq "winget") { "choco" } else { "winget" }
    
    if (Test-PackageManager -PackageManager $AlternativePackageManager) {
        Write-Host "However, '$AlternativePackageManager' is available. Would you like to use it instead? (Y/N)" -ForegroundColor Yellow
        $response = Read-Host
        
        if ($response -eq "Y" -or $response -eq "y") {
            $Config.PackageManager = $AlternativePackageManager
            Save-Config -Config $Config
            Write-Host "Package manager switched to $AlternativePackageManager." -ForegroundColor Green
        } else {
            Write-Host "Operation cancelled." -ForegroundColor Red
            exit
        }
    } else {
        Write-Host "Please install a supported package manager (winget or chocolatey)." -ForegroundColor Red
        exit
    }
}

# Execute the command
Invoke-PackageManagerCommand -PackageManager $Config.PackageManager -Command $Command -Arguments $Arguments