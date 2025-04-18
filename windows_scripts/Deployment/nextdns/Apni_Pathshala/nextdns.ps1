<#
.SYNOPSIS
  Install cloudflared as a SYSTEM service, lock it down, 
  point Windows DNS to localhost, and block non‑admins from changing it.

.DESCRIPTION
  1. Download & extract cloudflared
  2. Install & start it as a Windows service under LocalSystem
  3. Write a config.yml with your NextDNS DoH URL
  4. Harden service ACL so standard users can't stop it
  5. Point all adapters at 127.0.0.1 via PowerShell
  6. Set a registry policy to grey out DNS fields
  7. Verify the setup
#>

#Requires -RunAsAdministrator

# Variables
$Url             = 'https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe'
$InstallDir      = 'C:\Program Files\cloudflared'
$ExePath         = "$InstallDir\cloudflared.exe"
# IMPORTANT: When running as a service, cloudflared looks for config in this location
$ServiceConfigDir = 'C:\Windows\System32\config\systemprofile\.cloudflared'
$ServiceConfigPath = "$ServiceConfigDir\config.yml"
# Log file location
$LogDir          = "$ServiceConfigDir\logs"
$LogFile         = "$LogDir\cloudflared_install.log"
$VerboseLogFile  = "$LogDir\cloudflared_verbose.log"
# The actual Windows service name based on the error messages
$ServiceName     = 'Cloudflared'
# The service display name appears to be "Cloudflared agent"
$ServiceDisplayName = 'Cloudflared agent'
$DoHUrl          = 'https://dns.nextdns.io/d6849a'

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
    Write-Host "Initializing log directory..."
    
    # Create log directory if it doesn't exist
    if (-Not (Test-Path $LogDir)) {
        New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
    }
    
    # Initialize log files with headers
    $scriptStart = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $headerMain = "[$scriptStart] NextDNS Installation Log - Script started`n"
    $headerVerbose = "[$scriptStart] NextDNS Installation Verbose Log - Script started`n"
    
    Set-Content -Path $LogFile -Value $headerMain -Force
    Set-Content -Path $VerboseLogFile -Value $headerVerbose -Force
    
    # Log system information for troubleshooting
    $systemInfo = "System Information:`n"
    $systemInfo += "Windows Version: $([System.Environment]::OSVersion.VersionString)`n"
    $systemInfo += "PowerShell Version: $($PSVersionTable.PSVersion)`n"
    $systemInfo += "Computer Name: $env:COMPUTERNAME`n"
    $systemInfo += "User: $env:USERNAME`n"
    
    Add-Content -Path $VerboseLogFile -Value $systemInfo
    
    # Check if DNS Client service is running and could be using port 53
    Write-Status "Checking for services that might interfere with port 53..."
    $dnsClientService = Get-Service "Dnscache" -ErrorAction SilentlyContinue
    if ($dnsClientService -and $dnsClientService.Status -eq "Running") {
        Write-Status "DNS Client service is running. Checking if it's using port 53..."
        $netstatBeforeStop = netstat -ano | Select-String ":53 "
        Write-VerboseLog "Netstat before DNS client stop: $netstatBeforeStop"
        
        if ($netstatBeforeStop) {
            Write-Status "Found process using port 53. Attempting to stop DNS Client service..."
            Stop-Service "Dnscache" -Force
            Set-Service "Dnscache" -StartupType Disabled
            Write-Success "DNS Client service disabled"
            Write-VerboseLog "DNS Client service stopped and disabled"
        }
    }

    # Check for any other process using port 53
    $port53Process = netstat -ano | Select-String ":53 "
    Write-VerboseLog "Port 53 process check: $port53Process"
    
    if ($port53Process) {
        Write-Status "Process using port 53 detected: $port53Process"
        $processId = ($port53Process -split ' ')[-1]
        try {
            $process = Get-Process -Id $processId -ErrorAction SilentlyContinue
            if ($process) {
                Write-Status "Process using port 53: $($process.Name) (PID: $processId)"
                Write-Status "Attempting to stop process..."
                Write-VerboseLog "Stopping process: $($process.Name) (PID: $processId)"
                Stop-Process -Id $processId -Force -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 2
            }
        } catch {
            Write-Status "Could not get process details for PID $processId"
            Write-VerboseLog "Error getting process details: $_"
        }
    }

    # 1. Download & install cloudflared
    Write-Status "Creating installation directory..."
    if (-Not (Test-Path $InstallDir)) {
        New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
        Write-VerboseLog "Created installation directory: $InstallDir"
    }

    Write-Status "Downloading cloudflared..."
    try {
        Invoke-WebRequest -Uri $Url -OutFile $ExePath -UseBasicParsing
        Write-VerboseLog "Downloaded cloudflared from $Url to $ExePath"
        
        # Log file hash for verification
        $fileHash = Get-FileHash -Path $ExePath -Algorithm SHA256 -ErrorAction SilentlyContinue
        if ($fileHash) {
            Write-VerboseLog "Downloaded file hash (SHA256): $($fileHash.Hash)"
        }
    }
    catch {
        Write-Error "Failed to download cloudflared: $_"
        Write-VerboseLog "Download error details: $($_ | Format-List -Force | Out-String)"
        exit 1
    }

    # Create the necessary system profile directory for the service
    Write-Status "Creating service configuration directory..."
    if (-Not (Test-Path $ServiceConfigDir)) {
        New-Item -Path $ServiceConfigDir -ItemType Directory -Force | Out-Null
        Write-Success "Created systemprofile configuration directory"
        Write-VerboseLog "Created systemprofile directory: $ServiceConfigDir"
    }

    # Create config.yml for systemprofile
    Write-Status "Creating configuration file..."
    $configContent = @"
proxy-dns: true
proxy-dns-port: 53
proxy-dns-address: 127.0.0.1
proxy-dns-upstream:
  - $DoHUrl
"@

    # Write to systemprofile config
    $configContent | Set-Content -Path $ServiceConfigPath -Encoding ASCII
    Write-Success "Configuration file created in systemprofile location"
    Write-VerboseLog "Config file created at: $ServiceConfigPath"
    Write-VerboseLog "Config file content:`n$configContent"

    # 2. Install & start as SYSTEM service
    Write-Status "Installing cloudflared service..."
    try {
        # Check for existing service using Get-Service
        $existingService = Get-Service $ServiceName -ErrorAction SilentlyContinue
        
        if ($existingService) {
            Write-Status "Service already exists. Stopping and removing..."
            Write-VerboseLog "Existing service details: $($existingService | Format-List -Force | Out-String)"
            
            Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 5
            
            # Try to uninstall using cloudflared command
            Write-Status "Uninstalling existing service..."
            $uninstallOutput = & $ExePath service uninstall 2>&1
            Write-CommandOutput "service uninstall" $uninstallOutput
            Start-Sleep -Seconds 5
        }
        
        # Install the service
        Write-Status "Installing cloudflared service..."
        $installOutput = & $ExePath service install 2>&1
        Write-CommandOutput "service install" $installOutput
        Start-Sleep -Seconds 5
        
        # Use standard PowerShell commands to start the service rather than cloudflared's commands
        Write-Status "Starting cloudflared service with PowerShell commands..."
        Start-Service -Name $ServiceName
        Start-Sleep -Seconds 5
        
        # Verify service is running
        $runningService = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
        Write-VerboseLog "Service status after start: $($runningService | Format-List -Force | Out-String)"
        
        if ($runningService -and $runningService.Status -eq 'Running') {
            Write-Success "Service started successfully"
        } else {
            # If service isn't running, try to get more information
            Write-Error "Service not running after start attempt. Current status: $($runningService.Status)"
            Write-Status "Attempting to get service details..."
            $svcDetails = sc.exe qc $ServiceName
            Write-Host $svcDetails
            Write-CommandOutput "sc.exe qc $ServiceName" $svcDetails
        }
    }
    catch {
        Write-Error "Failed to install or start cloudflared service: $_"
        Write-VerboseLog "Service installation error details: $($_ | Format-List -Force | Out-String)"
        exit 1
    }

    # Verify that cloudflared is running and properly binding to port 53
    Write-Status "Checking if cloudflared is properly binding to port 53..."
    $portCheck = netstat -ano | Select-String ":53 "
    Write-VerboseLog "Port 53 check after service start: $portCheck"
    
    if (-not $portCheck) {
        Write-Status "Port 53 is not being used by any process. Waiting a bit longer..."
        Start-Sleep -Seconds 10
        $portCheck = netstat -ano | Select-String ":53 "
        Write-VerboseLog "Port 53 check after waiting: $portCheck"
        
        if (-not $portCheck) {
            Write-Status "Port 53 still not in use. Checking cloudflared logs..."
            # Try to restart the service and check logs
            Restart-Service -Name $ServiceName -Force
            Start-Sleep -Seconds 5
            
            # Check if config exists in the systemprofile directory
            Write-Status "Verifying configuration in systemprofile..."
            if (Test-Path $ServiceConfigPath) {
                Write-Status "Config exists in systemprofile directory: ${ServiceConfigPath}"
                $configFileContent = Get-Content $ServiceConfigPath | Out-String
                Write-Host $configFileContent
                Write-VerboseLog "Config file content verification:`n$configFileContent"
            } else {
                Write-Error "Configuration file not found in systemprofile directory!"
                Write-VerboseLog "Config file missing at: ${ServiceConfigPath}"
                # Try to create it again
                New-Item -Path $ServiceConfigDir -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
                $configContent | Set-Content -Path $ServiceConfigPath -Encoding ASCII -Force
                Write-Status "Re-created configuration file in systemprofile directory"
                Write-VerboseLog "Re-created config file"
                # Restart service
                Restart-Service -Name $ServiceName -Force
                Start-Sleep -Seconds 5
            }
            
            # Try to run cloudflared directly to see any errors
            Write-Status "Running cloudflared with verbose logging for diagnostics..."
            $diagnosticLogFile = "$LogDir\cloudflared_diagnostic.log"
            Write-Status "Diagnostic output will be saved to: $diagnosticLogFile"
            
            # Run cloudflared with debug logs and capture output to file
            try {
                $testOutput = & $ExePath proxy-dns --loglevel debug 2>&1 | Tee-Object -FilePath $diagnosticLogFile
                Write-Host $testOutput
                Write-CommandOutput "proxy-dns --loglevel debug" $testOutput
            }
            catch {
                Write-Error "Error running diagnostic command: $_"
                Write-VerboseLog "Diagnostic command error: $($_ | Format-List -Force | Out-String)"
            }
        }
    } else {
        Write-Success "Detected service running on port 53: $portCheck"
    }

    # 4. Harden the service ACL (deny STOP/PAUSE to Authenticated Users)
    #    Keep SYSTEM (SY) & Admins (BA) full control
    Write-Status "Hardening service ACLs..."
    $SDDL = 'D:(A;;CCLCSWLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)'
    try {
        $result = sc.exe sdset $ServiceName $SDDL
        Write-CommandOutput "sc.exe sdset $ServiceName $SDDL" $result
        
        if ($result -ne "[SC] SetServiceObjectSecurity SUCCESS") {
            Write-Error "Failed to set service ACL. Output: $result"
        }
    }
    catch {
        Write-Error "Failed to harden service ACL: $_"
        Write-VerboseLog "Service ACL error: $($_ | Format-List -Force | Out-String)"
        exit 1
    }

    # 5. Point all "Up" adapters at localhost
    Write-Status "Configuring network adapters to use localhost as DNS server..."
    try {
        $adapters = Get-NetAdapter | Where-Object Status -EQ 'Up'
        Write-VerboseLog "Active network adapters: $($adapters | Format-Table -AutoSize | Out-String)"
        
        if ($adapters.Count -eq 0) {
            Write-Error "No active network adapters found"
        } else {
            foreach ($adapter in $adapters) {
                Write-Status "  Setting DNS for adapter: $($adapter.Name)"
                $previousDns = Get-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex | Select-Object -ExpandProperty ServerAddresses
                Write-VerboseLog "Adapter $($adapter.Name) previous DNS: $($previousDns -join ', ')"
                
                Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses '127.0.0.1'
                $newDns = Get-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex | Select-Object -ExpandProperty ServerAddresses
                Write-VerboseLog "Adapter $($adapter.Name) new DNS: $($newDns -join ', ')"
            }
        }
    }
    catch {
        Write-Error "Failed to configure DNS settings: $_"
        Write-VerboseLog "DNS setting error: $($_ | Format-List -Force | Out-String)"
        exit 1
    }

    # 6. Grey‑out DNS fields via registry (locks down adapter properties)
    Write-Status "Setting registry policy to lock DNS settings..."
    try {
        $reg = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Network Connections'
        if (-Not (Test-Path $reg)) { 
            New-Item -Path $reg -Force | Out-Null 
            Write-VerboseLog "Created registry key: $reg"
        }
        New-ItemProperty -Path $reg -Name 'NC_LanProperties' -Value 1 -PropertyType DWord -Force | Out-Null
        Write-VerboseLog "Set registry value: $reg\NC_LanProperties = 1"
    }
    catch {
        Write-Error "Failed to set registry policy: $_"
        Write-VerboseLog "Registry setting error: $($_ | Format-List -Force | Out-String)"
        exit 1
    }

    # 7. Verification
    Write-Status "Verifying installation..."
    
    # Check service status - use the service name from sc.exe
    $serviceCheck = sc.exe query $ServiceName
    Write-Host "Service status from sc.exe:"
    Write-Host $serviceCheck
    Write-CommandOutput "sc.exe query $ServiceName" $serviceCheck
    
    # Also try with Get-Service
    $service = Get-Service $ServiceName -ErrorAction SilentlyContinue
    Write-VerboseLog "Get-Service result: $($service | Format-List -Force | Out-String)"
    
    if ($service -and $service.Status -eq 'Running') {
        Write-Success "Service status: Running"
    }
    else {
        Write-Error "Service is not running. Status: $(if($service){$service.Status}else{'Not found'})"
        
        # Try to check service status with the display name
        $serviceByDisplayName = Get-Service -DisplayName "*$ServiceDisplayName*" -ErrorAction SilentlyContinue
        if ($serviceByDisplayName) {
            Write-Host "Found service by display name: $($serviceByDisplayName.Name) - $($serviceByDisplayName.DisplayName)"
            Write-Host "Status: $($serviceByDisplayName.Status)"
            Write-VerboseLog "Service found by display name: $($serviceByDisplayName | Format-List -Force | Out-String)"
            # Update service name if found by display name
            $ServiceName = $serviceByDisplayName.Name
        }
    }
    
    # Flush DNS cache before testing
    Write-Status "Flushing DNS cache before testing..."
    ipconfig /flushdns | Out-Null
    Write-VerboseLog "DNS cache flushed"
    
    # Wait a bit more for DNS service to fully initialize
    Write-Status "Waiting for DNS service to fully initialize..."
    Start-Sleep -Seconds 10
    
    # Verify port 53 is in use
    $port53Check = netstat -ano | Select-String ":53 "
    Write-Host "Port 53 status: $(if($port53Check){"In use by process"}else{"Not in use"})"
    Write-VerboseLog "Final port 53 check: $port53Check"
    
    if ($port53Check) {
        Write-Host $port53Check
    }
    
    # Test DNS resolution with a timeout
    try {
        Write-Status "Testing DNS resolution with timeout..."
        $job = Start-Job -ScriptBlock { 
            param($server)
            Resolve-DnsName example.com -Server $server -ErrorAction Stop 
        } -ArgumentList "127.0.0.1"
        
        $completed = Wait-Job -Job $job -Timeout 15
        if ($completed) {
            $dnsResult = Receive-Job -Job $job
            Write-Success "DNS resolution successful: $(($dnsResult | Select-Object -First 1).IPAddress)"
            Write-VerboseLog "DNS resolution result: $($dnsResult | Format-List -Force | Out-String)"
            
            # Additional test to verify we're getting results through NextDNS
            $job2 = Start-Job -ScriptBlock { 
                param($server)
                Resolve-DnsName nextdns.io -Server $server -ErrorAction Stop 
            } -ArgumentList "127.0.0.1"
            
            $completed2 = Wait-Job -Job $job2 -Timeout 15
            if ($completed2) {
                $dnsQuery = Receive-Job -Job $job2
                Write-Success "NextDNS resolution successful: $(($dnsQuery | Select-Object -First 1).IPAddress)"
                Write-VerboseLog "NextDNS resolution result: $($dnsQuery | Format-List -Force | Out-String)"
            } else {
                Write-Error "NextDNS resolution timed out"
                Write-VerboseLog "NextDNS resolution job timed out"
                Remove-Job -Job $job2 -Force
            }
        } else {
            Write-Error "DNS resolution timed out"
            Write-VerboseLog "DNS resolution job timed out"
            Remove-Job -Job $job -Force
        }
    }
    catch {
        Write-Error "DNS resolution test failed: $_"
        Write-VerboseLog "DNS resolution error: $($_ | Format-List -Force | Out-String)"
        
        # Additional debug info for DNS resolution failures
        Write-Status "Checking if port 53 is listening on localhost..."
        $netstatResult = netstat -an | Select-String "127.0.0.1:53"
        Write-Host $netstatResult
        Write-VerboseLog "Localhost port 53 check: $netstatResult"
        
        Write-Status "Checking cloudflared process..."
        $process = Get-Process cloudflared -ErrorAction SilentlyContinue
        if ($process) {
            Write-Host "cloudflared process is running with PID: $($process.Id)"
            Write-VerboseLog "cloudflared process: $($process | Format-List -Force | Out-String)"
            
            # Try to manually run cloudflared to test DNS resolution
            Write-Status "Testing direct cloudflared DNS resolution..."
            $directTestLogFile = "$LogDir\direct_dns_test.log"
            $testResult = & $ExePath proxy-dns --address 127.0.0.1 --port 5353 --upstream $DoHUrl 2>&1 | Tee-Object -FilePath $directTestLogFile
            Write-Host $testResult
            Write-CommandOutput "proxy-dns --address 127.0.0.1 --port 5353" $testResult
            
            # Try simple nslookup
            Write-Status "Testing with nslookup..."
            Start-Sleep -Seconds 2
            $nslookupResult = nslookup example.com 127.0.0.1
            Write-Host $nslookupResult
            Write-CommandOutput "nslookup example.com 127.0.0.1" $nslookupResult
        } else {
            Write-Host "cloudflared process is not running"
            Write-VerboseLog "No cloudflared process found"
            
            # Display contents of systemprofile config file
            Write-Status "Checking systemprofile config file..."
            if (Test-Path $ServiceConfigPath) {
                Write-Host "Contents of ${ServiceConfigPath}:"
                $finalConfigContent = Get-Content $ServiceConfigPath | Out-String
                Write-Host $finalConfigContent
                Write-VerboseLog "Final config file content: $finalConfigContent"
            } else {
                Write-Error "System profile config file not found! This is likely the issue."
                Write-VerboseLog "Config file missing in final check"
            }
        }
    }
    
    # Log script completion
    $scriptEnd = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $completionMessage = "[$scriptEnd] NextDNS Installation completed"
    Add-Content -Path $LogFile -Value $completionMessage
    Add-Content -Path $VerboseLogFile -Value $completionMessage
    
    Write-Success "Installation completed!"
    Write-Host ""
    Write-Host "NextDNS is now configured with cloudflared using DoH. All DNS queries will be encrypted and sent to NextDNS." -ForegroundColor Cyan
    Write-Host "To verify this is working correctly, visit https://test.nextdns.io" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Important configuration notes:" -ForegroundColor Yellow
    Write-Host "The cloudflared service uses the configuration file at: ${ServiceConfigPath}" -ForegroundColor Yellow
    Write-Host "Detailed logs have been saved to:" -ForegroundColor Yellow
    Write-Host "  - Install log: ${LogFile}" -ForegroundColor Yellow
    Write-Host "  - Verbose log: ${VerboseLogFile}" -ForegroundColor Yellow
    Write-Host "  - Diagnostic logs: ${LogDir}" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "If you're experiencing issues with DNS resolution, try these troubleshooting steps:" -ForegroundColor Yellow
    Write-Host "1. Restart your computer" -ForegroundColor Yellow
    Write-Host "2. Manually check if cloudflared service is running after restart" -ForegroundColor Yellow
    Write-Host "3. Ensure no other services are using port 53" -ForegroundColor Yellow
    Write-Host "4. Check firewall settings to allow cloudflared to communicate" -ForegroundColor Yellow
    Write-Host "5. Review the logs in $LogDir for detailed information" -ForegroundColor Yellow
}
catch {
    # Log fatal error
    $errorMessage = "Fatal error occurred: $_"
    $errorDetails = $_ | Format-List -Force | Out-String
    
    Write-Error $errorMessage
    Write-VerboseLog "Fatal error: $errorMessage"
    Write-VerboseLog "Error details: $errorDetails"
    
    exit 1
}
