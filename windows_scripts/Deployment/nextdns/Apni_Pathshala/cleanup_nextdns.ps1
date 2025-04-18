<#
.SYNOPSIS
  Uninstall cloudflared service and restore original DNS settings.

.DESCRIPTION
  1. Stop and remove the cloudflared service
  2. Restore original DNS settings for network adapters
  3. Remove registry policy that locks DNS fields
  4. Re-enable the DNS Client service if it was disabled
  5. Clean up installed files
#>

#Requires -RunAsAdministrator

# Script variables
$ServiceName     = 'Cloudflared'
$InstallDir      = 'C:\Program Files\cloudflared'
$ExePath         = "$InstallDir\cloudflared.exe"
$ServiceConfigDir = 'C:\Windows\System32\config\systemprofile\.cloudflared'
$ServiceConfigPath = "$ServiceConfigDir\config.yml"
$LogDir          = "$env:TEMP\nextdns_uninstall_logs"
$LogFile         = "$LogDir\uninstall.log"
$VerboseLogFile  = "$LogDir\uninstall_verbose.log"
$BackupDnsFile   = "$env:TEMP\nextdns_backup_dns.json"

# Helper function to reset all adapters to DHCP DNS
function Reset-AllAdaptersToDhcp {
    $adapters = Get-NetAdapter | Where-Object Status -EQ 'Up'
    
    foreach ($adapter in $adapters) {
        Write-Status "  Resetting DNS to DHCP for adapter: $($adapter.Name)"
        try {
            # Reset IPv4 DNS
            Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ResetServerAddresses -ErrorAction Stop
            Write-Success "  Reset IPv4 DNS to DHCP for adapter: $($adapter.Name)"
            Write-VerboseLog "Reset IPv4 DNS to DHCP for adapter $($adapter.Name)"
            
            # Reset IPv6 DNS
            Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ResetServerAddresses -AddressFamily IPv6 -ErrorAction Stop
            Write-Success "  Reset IPv6 DNS to DHCP for adapter: $($adapter.Name)"
            Write-VerboseLog "Reset IPv6 DNS to DHCP for adapter $($adapter.Name)"
        } catch {
            Write-Error ("  Failed to reset DNS for adapter $($adapter.Name): " + $_)
            Write-VerboseLog ("DNS reset error: " + $_)
            
            # Try netsh as fallback
            try {
                Write-Status "  Trying netsh to reset DNS for adapter: $($adapter.Name)"
                $netshOutput = netsh interface ip set dns name="$($adapter.Name)" source=dhcp
                $netshOutput6 = netsh interface ipv6 set dnsservers name="$($adapter.Name)" source=dhcp
                Write-CommandOutput "netsh DNS reset" "$netshOutput`n$netshOutput6"
                Write-Success "  Reset DNS using netsh for adapter: $($adapter.Name)"
            } catch {
                Write-Error ("  Failed to reset DNS using netsh for adapter $($adapter.Name): " + $_)
                Write-VerboseLog ("netsh reset error: " + $_)
            }
        }
    }
}

function Write-Status($message) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [INFO] $message"
    Write-Host "[INFO] $message" -ForegroundColor Cyan
    Add-Content -Path $LogFile -Value $logMessage -ErrorAction SilentlyContinue
}

function Write-Success($message) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [SUCCESS] $message"
    Write-Host "[SUCCESS] $message" -ForegroundColor Green
    Add-Content -Path $LogFile -Value $logMessage -ErrorAction SilentlyContinue
}

function Write-Error($message) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [ERROR] $message"
    Write-Host "[ERROR] $message" -ForegroundColor Red
    Add-Content -Path $LogFile -Value $logMessage -ErrorAction SilentlyContinue
}

function Write-VerboseLog($message) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [VERBOSE] $message"
    Add-Content -Path $VerboseLogFile -Value $logMessage -ErrorAction SilentlyContinue
}

function Write-CommandOutput($command, $output) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $header = "[$timestamp] [COMMAND] $command"
    Add-Content -Path $VerboseLogFile -Value $header -ErrorAction SilentlyContinue
    Add-Content -Path $VerboseLogFile -Value $output -ErrorAction SilentlyContinue
    Add-Content -Path $VerboseLogFile -Value "`n" -ErrorAction SilentlyContinue
}

# Check if script is running as admin
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-Not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script must be run as Administrator"
    exit 1
}

try {
    # Initialize log directories
    if (-Not (Test-Path $LogDir)) {
        New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
    }
    
    # Initialize log files with headers
    $scriptStart = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $headerMain = "[$scriptStart] NextDNS Uninstallation Log - Script started`n"
    $headerVerbose = "[$scriptStart] NextDNS Uninstallation Verbose Log - Script started`n"
    
    Set-Content -Path $LogFile -Value $headerMain -Force
    Set-Content -Path $VerboseLogFile -Value $headerVerbose -Force
    
    # Log system information for troubleshooting
    $systemInfo = "System Information:`n"
    $systemInfo += "Windows Version: $([System.Environment]::OSVersion.VersionString)`n"
    $systemInfo += "PowerShell Version: $($PSVersionTable.PSVersion)`n"
    $systemInfo += "Computer Name: $env:COMPUTERNAME`n"
    $systemInfo += "User: $env:USERNAME`n"
    
    Add-Content -Path $VerboseLogFile -Value $systemInfo
    
    # 1. Stop and uninstall cloudflared service
    Write-Status "Checking for cloudflared service..."
    $service = Get-Service $ServiceName -ErrorAction SilentlyContinue
    
    if ($service) {
        Write-Status "Stopping cloudflared service..."
        try {
            Stop-Service -Name $ServiceName -Force -ErrorAction Stop
            Write-Success "Service stopped successfully"
        } catch {
            Write-Error ("Failed to stop service: " + $_)
            Write-VerboseLog ("Error stopping service: " + $_)
            
            # Try using SC
            Write-Status "Trying sc.exe to stop service..."
            $scStopOutput = sc.exe stop $ServiceName
            Write-CommandOutput "sc.exe stop $ServiceName" $scStopOutput
        }
        
        # Wait to ensure it's fully stopped
        Start-Sleep -Seconds 3
        
        # Check if cloudflared.exe exists and try to uninstall using its command
        if (Test-Path $ExePath) {
            Write-Status "Uninstalling service using cloudflared command..."
            $uninstallOutput = & $ExePath service uninstall 2>&1
            Write-CommandOutput "service uninstall" $uninstallOutput
            Start-Sleep -Seconds 2
        }
        
        # Double-check service is gone; if not, remove manually
        $serviceCheck = Get-Service $ServiceName -ErrorAction SilentlyContinue
        if ($serviceCheck) {
            Write-Status "Service still exists. Removing using sc.exe delete..."
            $scDeleteOutput = sc.exe delete $ServiceName
            Write-CommandOutput "sc.exe delete $ServiceName" $scDeleteOutput
        }
        
        # Final check
        $finalCheck = Get-Service $ServiceName -ErrorAction SilentlyContinue
        if (-not $finalCheck) {
            Write-Success "Cloudflared service removed successfully"
        } else {
            Write-Error ("Failed to completely remove cloudflared service. Current status: " + $finalCheck.Status)
        }
    } else {
        Write-Status "Cloudflared service not found"
    }
    
    # 2. Restore DNS settings for all network adapters
    Write-Status "Restoring DNS settings for network adapters..."
    
    # Check if a backup file exists
    $backupExists = Test-Path $BackupDnsFile
    if ($backupExists) {
        try {
            Write-Status "Found DNS backup file. Restoring settings from backup..."
            $backupDnsSettings = Get-Content $BackupDnsFile -Raw | ConvertFrom-Json
            
            foreach ($adapter in $backupDnsSettings) {
                $ifIndex = $adapter.InterfaceIndex
                $adapterName = $adapter.InterfaceName
                $ipv4Dns = $adapter.IPv4Dns
                $ipv6Dns = $adapter.IPv6Dns
                
                Write-Status "  Restoring DNS for adapter: $adapterName (Index: $ifIndex)"
                
                # Check if adapter still exists
                $currentAdapter = Get-NetAdapter | Where-Object { $_.ifIndex -eq $ifIndex } -ErrorAction SilentlyContinue
                if ($currentAdapter) {
                    # Restore IPv4 DNS
                    try {
                        if ($ipv4Dns -and $ipv4Dns.Count -gt 0 -and -not ($ipv4Dns -contains "127.0.0.1")) {
                            Set-DnsClientServerAddress -InterfaceIndex $ifIndex -ServerAddresses $ipv4Dns -ErrorAction Stop
                            Write-Success "  Restored IPv4 DNS for adapter: $adapterName"
                            Write-VerboseLog "Restored IPv4 DNS for adapter $adapterName to: $($ipv4Dns -join ', ')"
                        } else {
                            # If original DNS was localhost or empty, set to DHCP
                            Set-DnsClientServerAddress -InterfaceIndex $ifIndex -ResetServerAddresses -ErrorAction Stop
                            Write-Success "  Reset IPv4 DNS to DHCP for adapter: $adapterName"
                            Write-VerboseLog "Reset IPv4 DNS to DHCP for adapter $adapterName"
                        }
                    } catch {
                        Write-Error ("  Failed to restore IPv4 DNS for adapter ${adapterName}: " + $_)
                        Write-VerboseLog ("IPv4 DNS restore error: " + $_)
                    }
                    
                    # Restore IPv6 DNS
                    try {
                        if ($ipv6Dns -and $ipv6Dns.Count -gt 0 -and -not ($ipv6Dns -contains "::1")) {
                            Set-DnsClientServerAddress -InterfaceIndex $ifIndex -ServerAddresses $ipv6Dns -AddressFamily IPv6 -ErrorAction Stop
                            Write-Success "  Restored IPv6 DNS for adapter: $adapterName"
                            Write-VerboseLog "Restored IPv6 DNS for adapter $adapterName to: $($ipv6Dns -join ', ')"
                        } else {
                            # If original DNS was localhost or empty, set to DHCP
                            Set-DnsClientServerAddress -InterfaceIndex $ifIndex -ResetServerAddresses -AddressFamily IPv6 -ErrorAction Stop
                            Write-Success "  Reset IPv6 DNS to DHCP for adapter: $adapterName"
                            Write-VerboseLog "Reset IPv6 DNS to DHCP for adapter $adapterName"
                        }
                    } catch {
                        Write-Error ("  Failed to restore IPv6 DNS for adapter ${adapterName}: " + $_)
                        Write-VerboseLog ("IPv6 DNS restore error: " + $_)
                        
                        # Try netsh as fallback for IPv6
                        try {
                            $netshOutput = netsh interface ipv6 set dnsservers name="$adapterName" source=dhcp
                            Write-CommandOutput "netsh ipv6 DNS reset" $netshOutput
                            Write-Status "  Reset IPv6 DNS using netsh for adapter: $adapterName"
                        } catch {
                            Write-Error ("  Failed to reset IPv6 DNS using netsh for adapter ${adapterName}: " + $_)
                        }
                    }
                } else {
                    Write-Status "  Adapter $adapterName (Index: $ifIndex) no longer exists, skipping"
                }
            }
        } catch {
            Write-Error ("Failed to restore DNS from backup: " + $_)
            Write-VerboseLog ("Backup restore error: " + ($($_ | Format-List -Force | Out-String)))
            # Fall back to DHCP for all adapters
            Write-Status "Falling back to resetting all adapters to DHCP DNS settings..."
            Reset-AllAdaptersToDhcp
        }
    } else {
        Write-Status "No DNS backup file found. Resetting all adapters to DHCP..."
        Reset-AllAdaptersToDhcp
    }
    
    # 3. Remove registry policy that locks DNS fields
    Write-Status "Removing registry policies..."
    try {
        $regPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Network Connections'
        if (Test-Path $regPath) {
            if (Get-ItemProperty -Path $regPath -Name 'NC_LanProperties' -ErrorAction SilentlyContinue) {
                Remove-ItemProperty -Path $regPath -Name 'NC_LanProperties' -Force
                Write-Success "Removed registry policy that locked DNS settings"
                Write-VerboseLog "Removed registry value: $regPath\NC_LanProperties"
            } else {
                Write-Status "Registry policy for DNS locking not found"
            }
        } else {
            Write-Status "Registry path for Network Connections policies not found"
        }
        
        # Check and restore IPv6 registry settings
        $ipv6RegPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters'
        if (Test-Path $ipv6RegPath) {
            if (Get-ItemProperty -Path $ipv6RegPath -Name 'DisabledComponents' -ErrorAction SilentlyContinue) {
                # Don't automatically reenable IPv6 if it was explicitly disabled, just notify
                Write-Status "IPv6 settings found in registry. You may need to reenable IPv6 manually if desired."
                Write-VerboseLog "IPv6 registry setting found: $ipv6RegPath\DisabledComponents"
            }
        }
    } catch {
        Write-Error ("Failed to remove registry policies: " + $_)
        Write-VerboseLog ("Registry policy removal error: " + ($($_ | Format-List -Force | Out-String)))
    }
    
    # 4. Re-enable the DNS Client service if it was disabled
    Write-Status "Checking DNS Client service status..."
    try {
        $dnsClientService = Get-Service "Dnscache" -ErrorAction SilentlyContinue
        if ($dnsClientService) {
            $startupType = Get-WmiObject -Class Win32_Service -Filter "Name='Dnscache'" | Select-Object -ExpandProperty StartMode
            Write-VerboseLog "DNS Client service current startup type: $startupType"
            
            if ($startupType -eq "Disabled") {
                Write-Status "DNS Client service is disabled. Re-enabling..."
                Set-Service "Dnscache" -StartupType Automatic
                Start-Service "Dnscache"
                Write-Success "DNS Client service re-enabled and started"
                Write-VerboseLog "DNS Client service startup type set to Automatic and service started"
            } else {
                if ($dnsClientService.Status -ne "Running") {
                    Write-Status "DNS Client service is not running. Starting..."
                    Start-Service "Dnscache"
                    Write-Success "DNS Client service started"
                } else {
                    Write-Status "DNS Client service is already running"
                }
            }
            
            # Check registry setting that might have been used to disable the service
            $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache"
            if (Test-Path $regPath) {
                $startValue = Get-ItemProperty -Path $regPath -Name "Start" -ErrorAction SilentlyContinue
                if ($startValue -and $startValue.Start -eq 4) {
                    Write-Status "DNS Client service disabled in registry. Re-enabling..."
                    Set-ItemProperty -Path $regPath -Name "Start" -Value 2 -Type DWord -Force
                    Write-Success "Registry setting for DNS Client service updated"
                    Write-VerboseLog "Registry value updated: $regPath\Start = 2"
                }
            }
        } else {
            Write-Error "DNS Client service not found on the system"
        }
    } catch {
        Write-Error ("Failed to check or update DNS Client service: " + $_)
        Write-VerboseLog ("DNS Client service error: " + ($($_ | Format-List -Force | Out-String)))
    }
    
    # 5. Clean up installed files
    Write-Status "Cleaning up installed files..."
    
    # Remove service config directory
    if (Test-Path $ServiceConfigDir) {
        try {
            Remove-Item -Path $ServiceConfigDir -Recurse -Force
            Write-Success "Removed service configuration directory"
            Write-VerboseLog "Removed directory: $ServiceConfigDir"
        } catch {
            Write-Error ("Failed to remove service configuration directory: " + $_)
            Write-VerboseLog ("Service config dir removal error: " + ($($_ | Format-List -Force | Out-String)))
        }
    }
    
    # Remove installation directory if it exists
    if (Test-Path $InstallDir) {
        try {
            Remove-Item -Path $InstallDir -Recurse -Force
            Write-Success "Removed installation directory"
            Write-VerboseLog "Removed directory: $InstallDir"
        } catch {
            Write-Error ("Failed to remove installation directory: " + $_)
            Write-VerboseLog ("Installation dir removal error: " + ($($_ | Format-List -Force | Out-String)))
        }
    }
    
    # Remove backup file
    if (Test-Path $BackupDnsFile) {
        try {
            Remove-Item -Path $BackupDnsFile -Force
            Write-Success "Removed DNS backup file"
            Write-VerboseLog "Removed file: $BackupDnsFile"
        } catch {
            Write-Error ("Failed to remove DNS backup file: " + $_)
            Write-VerboseLog ("Backup file removal error: " + $_)
        }
    }
    
    # Clean up potentially leftover files
    $potentialLeftovers = @(
        "$env:ProgramData\cloudflared",
        "$env:LOCALAPPDATA\cloudflared"
    )
    
    foreach ($path in $potentialLeftovers) {
        if (Test-Path $path) {
            try {
                Remove-Item -Path $path -Recurse -Force
                Write-Success "Removed leftover files: $path"
                Write-VerboseLog "Removed leftover path: $path"
            } catch {
                Write-Error ("Failed to remove leftover files at ${path}: " + $_)
                Write-VerboseLog ("Leftover removal error: " + $_)
            }
        }
    }
    
    # Final DNS verification
    Write-Status "Verifying DNS settings after cleanup..."
    $adapters = Get-NetAdapter | Where-Object Status -EQ 'Up'
    foreach ($adapter in $adapters) {
        $ipv4Dns = Get-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 | Select-Object -ExpandProperty ServerAddresses
        $ipv6Dns = Get-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv6 | Select-Object -ExpandProperty ServerAddresses
        
        Write-Status "  Adapter: $($adapter.Name)"
        Write-Status "    IPv4 DNS: $($ipv4Dns -join ', ')"
        Write-Status "    IPv6 DNS: $($ipv6Dns -join ', ')"
        
        Write-VerboseLog "Final DNS for adapter $($adapter.Name) - IPv4: $($ipv4Dns -join ', ') - IPv6: $($ipv6Dns -join ', ')"
    }
    
    # Flush DNS cache
    Write-Status "Flushing DNS cache..."
    ipconfig /flushdns | Out-Null
    Write-VerboseLog "DNS cache flushed"
    
    # Check for any processes that might still be running
    $cloudflaredProcess = Get-Process cloudflared -ErrorAction SilentlyContinue
    if ($cloudflaredProcess) {
        Write-Status "Found running cloudflared processes. Terminating..."
        try {
            $cloudflaredProcess | Stop-Process -Force
            Write-Success "Terminated cloudflared processes"
            Write-VerboseLog "Terminated cloudflared processes: $($cloudflaredProcess.Id -join ', ')"
        } catch {
            Write-Error ("Failed to terminate cloudflared processes: " + $_)
            Write-VerboseLog ("Process termination error: " + $_)
        }
    }
    
    # Final verification of port 53
    $port53Check = netstat -ano | Select-String ":53 "
    if ($port53Check) {
        Write-Status "Port 53 is still in use by some process. You may need to restart your computer."
        Write-Host $port53Check
        Write-VerboseLog "Port 53 still in use: $port53Check"
    } else {
        Write-Success "Port 53 is free"
    }
    
    # Log script completion
    $scriptEnd = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $completionMessage = "[$scriptEnd] NextDNS Uninstallation completed"
    Add-Content -Path $LogFile -Value $completionMessage
    Add-Content -Path $VerboseLogFile -Value $completionMessage
    
    Write-Success "Uninstallation completed!"
    Write-Host ""
    Write-Host "NextDNS has been completely uninstalled from your system." -ForegroundColor Cyan
    Write-Host "DNS settings have been restored to defaults (DHCP)." -ForegroundColor Cyan
    Write-Host ""
    Write-Host "If you encounter any networking issues, please try these steps:" -ForegroundColor Yellow
    Write-Host "1. Restart your computer" -ForegroundColor Yellow
    Write-Host "2. Verify your DNS settings manually in Network Connections" -ForegroundColor Yellow
    Write-Host "3. Make sure the DNS Client service is running" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Logs from this uninstallation have been saved to:" -ForegroundColor Yellow
    Write-Host "  - Main log: $LogFile" -ForegroundColor Yellow
    Write-Host "  - Verbose log: $VerboseLogFile" -ForegroundColor Yellow
} catch {
    Write-Error ("An unexpected error occurred during uninstallation: " + $_)
    Write-VerboseLog "Uninstallation critical error: $($_ | Format-List -Force | Out-String)"
    exit 1
}
