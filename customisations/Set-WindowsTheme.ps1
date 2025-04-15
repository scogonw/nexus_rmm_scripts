#========================================================================
# Set-WindowsTheme.ps1 - Toggle between Windows Dark and Light modes
#========================================================================

param (
    [Parameter(Mandatory=$true)]
    [ValidateSet('Dark', 'Light')]
    [string]$Theme
)

# Requires administrator privileges for some registry operations
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "This script requires elevation for some features. Please run as Administrator for full functionality."
}

$RegistryPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'

# Make sure the registry path exists
if (-not (Test-Path $RegistryPath)) {
    New-Item -Path $RegistryPath -Force | Out-Null
}

# 0 = Dark mode, 1 = Light mode
$ThemeValue = if ($Theme -eq 'Dark') { 0 } else { 1 }

# Set app theme
Set-ItemProperty -Path $RegistryPath -Name 'AppsUseLightTheme' -Value $ThemeValue -Type Dword

# Set system theme
Set-ItemProperty -Path $RegistryPath -Name 'SystemUsesLightTheme' -Value $ThemeValue -Type Dword

Write-Host "Windows theme has been set to $Theme mode." -ForegroundColor Green 