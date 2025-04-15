#========================================================================
# Set-TransparencyEffects.ps1 - Toggle Windows Transparency Effects
#========================================================================

param (
    [Parameter(Mandatory=$true)]
    [ValidateSet('On', 'Off')]
    [string]$State
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

# 1 = Transparency On, 0 = Transparency Off
$StateValue = if ($State -eq 'On') { 1 } else { 0 }

# Set transparency
Set-ItemProperty -Path $RegistryPath -Name 'EnableTransparency' -Value $StateValue -Type Dword

Write-Host "Windows transparency effects have been turned $State." -ForegroundColor Green

# Restart the explorer process to apply changes
Write-Host "Restarting Windows Explorer to apply changes..." -ForegroundColor Yellow
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Process explorer 