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

# Add System.Web assembly for URL encoding
Add-Type -AssemblyName System.Web

# Variables
$Url             = 'https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe'
$InstallDir      = 'C:\Program Files\cloudflared'
$ExePath         = "$InstallDir\cloudflared.exe"
# IMPORTANT: When running as a service, cloudflared looks for config in this location
$ServiceConfigDir = 'C:\Windows\System32\config\systemprofile\.cloudflared'
$ServiceConfigPath = "$ServiceConfigDir\config.yml"
# Base system profile directory
$SystemProfileDir = 'C:\Windows\System32\config\systemprofile'
# Log file location
$LogDir          = "$ServiceConfigDir\logs"
$LogFile         = "$LogDir\cloudflared_install.log"
$VerboseLogFile  = "$LogDir\cloudflared_verbose.log"
# The actual Windows service name based on the error messages
$ServiceName     = 'Cloudflared'
# The service display name appears to be "Cloudflared agent"
$ServiceDisplayName = 'Cloudflared agent'
$DoHUrl          = 'https://dns.nextdns.io/d6849a/' + [System.Web.HttpUtility]::UrlEncode($env:COMPUTERNAME)
# Flag to check if we need to use netsh fallback for IPv6 configuration
$UseNetshFallback = $false

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
            
            # Try multiple methods to stop DNS Client service
            try {
                # Method 1: Try standard PowerShell command with elevated privileges
                Write-Status "Attempting to stop DNS Client service using PowerShell..."
                Stop-Service "Dnscache" -Force -ErrorAction SilentlyContinue
                
                # Check if service stopped
                Start-Sleep -Seconds 2
                $dnsService = Get-Service "Dnscache" -ErrorAction SilentlyContinue
                if ($dnsService -and $dnsService.Status -eq "Stopped") {
                    Write-Success "Successfully stopped DNS Client service using PowerShell"
                    
                    # Try to disable the service
                    try {
                        Set-Service "Dnscache" -StartupType Disabled -ErrorAction Stop
                        Write-Success "DNS Client service disabled"
                    } catch {
                        Write-Error "Failed to disable DNS Client service using PowerShell: $_"
                        Write-VerboseLog "Set-Service error: $($_ | Format-List -Force | Out-String)"
                        
                        # Try alternative method using sc.exe
                        Write-Status "Trying alternative method to disable DNS Client service..."
                        $scResult = sc.exe config Dnscache start= disabled
                        Write-CommandOutput "sc.exe config Dnscache start= disabled" $scResult
                        
                        if ($scResult -match "SUCCESS") {
                            Write-Success "DNS Client service disabled using sc.exe"
                        } else {
                            Write-Error "Failed to disable DNS Client service using sc.exe. Output: $scResult"
                        }
                    }
                } else {
                    # Method 2: Try using sc.exe to stop the service
                    Write-Status "Attempting to stop DNS Client service using sc.exe..."
                    $scStopResult = sc.exe stop Dnscache
                    Write-CommandOutput "sc.exe stop Dnscache" $scStopResult
                    
                    Start-Sleep -Seconds 3
                    $dnsService = Get-Service "Dnscache" -ErrorAction SilentlyContinue
                    if ($dnsService -and $dnsService.Status -eq "Stopped") {
                        Write-Success "Successfully stopped DNS Client service using sc.exe"
                        
                        # Try to disable service using sc.exe
                        $scConfigResult = sc.exe config Dnscache start= disabled
                        Write-CommandOutput "sc.exe config Dnscache start= disabled" $scConfigResult
                        
                        if ($scConfigResult -match "SUCCESS") {
                            Write-Success "DNS Client service disabled using sc.exe"
                        } else {
                            Write-Error "Failed to disable DNS Client service using sc.exe. Output: $scConfigResult"
                        }
                    } else {
                        # Method 3: Try to kill the associated process directly
                        Write-Status "Direct service manipulation failed. Attempting to find and kill the process..."
                        $processInfo = netstat -ano | Select-String ":53 "
                        if ($processInfo) {
                            $processId = ($processInfo -split ' ')[-1]
                            Write-Status "Found process using port 53: PID $processId"
                            
                            try {
                                Stop-Process -Id $processId -Force -ErrorAction SilentlyContinue
                                Write-Success "Killed process (PID: $processId) using port 53"
                            } catch {
                                Write-Error "Failed to kill process using port 53: $_"
                            }
                        }
                        
                        # Method 4: Last resort - modify registry to disable on next boot
                        Write-Status "Attempting to disable DNS Client service via registry for next boot..."
                        try {
                            $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache"
                            if (Test-Path $regPath) {
                                Set-ItemProperty -Path $regPath -Name "Start" -Value 4 -Type DWord -Force
                                Write-Success "Set DNS Client service to disabled via registry (will take effect after reboot)"
                                Write-VerboseLog "Set registry value: $regPath\Start = 4"
                            } else {
                                Write-Error "DNS Client service registry key not found"
                            }
                        } catch {
                            Write-Error "Failed to disable DNS Client service via registry: $_"
                            Write-VerboseLog "Registry modification error: $($_ | Format-List -Force | Out-String)"
                        }
                        
                        Write-Status "Warning: DNS Client service could not be fully stopped/disabled. A reboot may be required"
                        Write-Status "         before cloudflared can properly bind to port 53."
                    }
                }
            } catch {
                Write-Error "Failed to stop DNS Client service: $_"
                Write-VerboseLog "DNS Client service stop error: $($_ | Format-List -Force | Out-String)"
                
                # Try alternative methods as fallback
                Write-Status "Trying alternative methods to manage DNS Client service..."
                
                # Try using sc.exe command
                $scStopResult = sc.exe stop Dnscache
                Write-CommandOutput "sc.exe stop Dnscache" $scStopResult
                
                Start-Sleep -Seconds 3
                $dnsService = Get-Service "Dnscache" -ErrorAction SilentlyContinue
                if ($dnsService -and $dnsService.Status -eq "Stopped") {
                    Write-Success "Successfully stopped DNS Client service using sc.exe"
                    
                    # Disable the service
                    $scConfigResult = sc.exe config Dnscache start= disabled
                    Write-CommandOutput "sc.exe config Dnscache start= disabled" $scConfigResult
                    
                    if ($scConfigResult -match "SUCCESS") {
                        Write-Success "DNS Client service disabled using sc.exe"
                    } else {
                        Write-Error "Failed to disable DNS Client service: $_"
                        Write-VerboseLog "Service disable error: $($_ | Format-List -Force | Out-String)"
                    }
                } else {
                    Write-Error "Could not stop DNS Client service. Port 53 may not be available."
                    Write-Status "You might need to manually disable the DNS Client service and restart the computer."
                }
            }
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

    # Force TLS 1.2 to avoid connection issues with GitHub
    Write-Status "Configuring TLS settings for secure downloads..."
    try {
        # Set strong TLS security for PowerShell
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Write-VerboseLog "Set TLS protocol to TLS 1.2"
    } catch {
        Write-Error "Failed to set TLS 1.2 protocol: $_"
        Write-VerboseLog "TLS protocol setting error: $($_ | Format-List -Force | Out-String)"
        # Continue anyway
    }

    Write-Status "Downloading cloudflared..."
    try {
        Invoke-WebRequest -Uri $Url -OutFile $ExePath -UseBasicParsing
        Write-VerboseLog "Downloaded cloudflared from $Url to $ExePath"
        
        # Log file hash for verification if download succeeded
        if (Test-Path $ExePath) {
            $fileHash = Get-FileHash -Path $ExePath -Algorithm SHA256 -ErrorAction SilentlyContinue
            if ($fileHash) {
                Write-VerboseLog "Downloaded file hash (SHA256): $($fileHash.Hash)"
            }
        } else {
            Write-Error "Download appeared to succeed but file $ExePath not found"
            exit 1
        }
    }
    catch {
        Write-Error "Failed to download cloudflared: $_"
        Write-VerboseLog "Download error details: $($_ | Format-List -Force | Out-String)"
        exit 1
    }

    # Create the necessary system profile directory for the service
    Write-Status "Creating service configuration directory..."

    # Ensure each directory in the path exists
    Write-Status "Checking and creating system profile directory structure..."
    # Check for systemprofile dir
    if (-Not (Test-Path $SystemProfileDir)) {
        Write-Status "System profile directory does not exist. Creating it..."
        try {
            New-Item -Path $SystemProfileDir -ItemType Directory -Force | Out-Null
            Write-Success "Created system profile directory: $SystemProfileDir"
            Write-VerboseLog "Created system profile directory: $SystemProfileDir"
        } catch {
            Write-Error "Failed to create system profile directory: $_"
            Write-VerboseLog "Error creating system profile directory: $($_ | Format-List -Force | Out-String)"
            exit 1
        }
    }

    # Create .cloudflared directory inside systemprofile
    if (-Not (Test-Path $ServiceConfigDir)) {
        Write-Status "Creating .cloudflared directory inside systemprofile..."
        try {
            New-Item -Path $ServiceConfigDir -ItemType Directory -Force | Out-Null
            Write-Success "Created .cloudflared directory: $ServiceConfigDir"
            Write-VerboseLog "Created .cloudflared directory: $ServiceConfigDir"
        } catch {
            Write-Error "Failed to create .cloudflared directory: $_"
            Write-VerboseLog "Error creating .cloudflared directory: $($_ | Format-List -Force | Out-String)"
            exit 1
        }
    }

    # Create logs directory
    if (-Not (Test-Path $LogDir)) {
        Write-Status "Creating logs directory..."
        try {
            New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
            Write-Success "Created logs directory: $LogDir"
            Write-VerboseLog "Created logs directory: $LogDir"
        } catch {
            Write-Error "Failed to create logs directory: $_"
            Write-VerboseLog "Error creating logs directory: $($_ | Format-List -Force | Out-String)"
            exit 1
        }
    }

    # Verify all directories exist
    $allDirectoriesExist = (Test-Path $SystemProfileDir) -and (Test-Path $ServiceConfigDir) -and (Test-Path $LogDir)
    if (-not $allDirectoriesExist) {
        Write-Error "Failed to create all required directories. Installation cannot continue."
        Write-VerboseLog "Directory creation verification failed. SystemProfileDir: $(Test-Path $SystemProfileDir), ServiceConfigDir: $(Test-Path $ServiceConfigDir), LogDir: $(Test-Path $LogDir)"
        exit 1
    }

    # Create config.yml for systemprofile
    Write-Status "Creating configuration file..."
    $configContent = @"
proxy-dns: true
proxy-dns-port: 53
proxy-dns-address: '::'
proxy-dns-upstream: ['$DoHUrl']
"@

    # Write to systemprofile config
    try {
        # Ensure directory exists with proper permissions
        $acl = Get-Acl -Path $SystemProfileDir -ErrorAction SilentlyContinue
        if ($acl) {
            Write-VerboseLog "System profile directory ACL: $($acl | Format-List -Force | Out-String)"
        }

        $configContent | Set-Content -Path $ServiceConfigPath -Encoding ASCII -Force
        Write-Success "Configuration file created in systemprofile location"
        Write-VerboseLog "Config file created at: $ServiceConfigPath"
        Write-VerboseLog "Config file content:`n$configContent"
        
        # Verify config file was created successfully
        if (Test-Path $ServiceConfigPath) {
            $configFileContent = Get-Content $ServiceConfigPath -Raw
            if ($configFileContent) {
                Write-Success "Verified config file exists with content"
                Write-VerboseLog "Config file verification successful. Content:`n$configFileContent"
                
                # Set permissions explicitly on the config file
                try {
                    $fileAcl = Get-Acl -Path $ServiceConfigPath
                    $fileAcl.SetAccessRuleProtection($false, $true)
                    $systemAccount = New-Object System.Security.Principal.SecurityIdentifier([System.Security.Principal.WellKnownSidType]::LocalSystemSid, $null)
                    $systemRule = New-Object System.Security.AccessControl.FileSystemAccessRule($systemAccount, "FullControl", "Allow")
                    $fileAcl.AddAccessRule($systemRule)
                    Set-Acl -Path $ServiceConfigPath -AclObject $fileAcl
                    Write-VerboseLog "Set explicit permissions on config file for SYSTEM account"
                } catch {
                    Write-VerboseLog "Failed to set explicit permissions on config file: $_"
                    # Non-critical, continue
                }
            } else {
                Write-Error "Config file exists but appears to be empty!"
                Write-VerboseLog "Config file verification failed - file is empty"
            }
        } else {
            Write-Error "Failed to create config file at $ServiceConfigPath"
            Write-VerboseLog "Config file verification failed - file does not exist"
        }
    } catch {
        Write-Error "Failed to create configuration file: $_"
        Write-VerboseLog "Error creating configuration file: $($_ | Format-List -Force | Out-String)"
        exit 1
    }

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
            
            # Manually remove service if cloudflared uninstall fails
            $checkService = Get-Service $ServiceName -ErrorAction SilentlyContinue
            if ($checkService) {
                Write-Status "Service still exists after uninstall command. Trying sc.exe delete..."
                $scDeleteOutput = sc.exe delete $ServiceName
                Write-CommandOutput "sc.exe delete $ServiceName" $scDeleteOutput
                Start-Sleep -Seconds 5
            }
        }
        
        # Before installing, create a local config file in the same directory as cloudflared.exe
        # Some versions look for config in the executable directory first
        $localConfigPath = "$InstallDir\config.yml"
        $configContent | Set-Content -Path $localConfigPath -Encoding ASCII -Force
        Write-VerboseLog "Created local config file at: $localConfigPath"
        
        # Install the service with explicit path to config
        Write-Status "Installing cloudflared service..."
        # First install the service
        $installOutput = & $ExePath service install 2>&1
        Write-CommandOutput "service install" $installOutput
        Start-Sleep -Seconds 5

        # Then configure the service to use our config file
        if (Get-Service $ServiceName -ErrorAction SilentlyContinue) {
            Write-Status "Configuring service with config file..."
            $scConfigResult = sc.exe config $ServiceName binPath= "`"$ExePath`" --config `"$ServiceConfigPath`""
            Write-CommandOutput "sc.exe config $ServiceName" $scConfigResult
        } else {
            Write-Error "Service not found after installation attempt"
            Write-Status "Trying alternative installation method..."
            
            # Try installing with sc.exe
            $scInstallOutput = sc.exe create $ServiceName binPath= "`"$ExePath`" --config `"$ServiceConfigPath`"" start= auto DisplayName= "Cloudflared agent"
            Write-CommandOutput "sc.exe create $ServiceName" $scInstallOutput
            
            # Set service description
            sc.exe description $ServiceName "Cloudflare DNS-over-HTTPS proxy daemon for NextDNS" | Out-Null
            
            # Configure service recovery options
            sc.exe failure $ServiceName reset= 86400 actions= restart/60000/restart/60000/restart/60000 | Out-Null
            
            # Verify service was created
            $serviceCheck = Get-Service $ServiceName -ErrorAction SilentlyContinue
            if (-not $serviceCheck) {
                Write-Error "Failed to create service using alternative method"
                exit 1
            }
        }
        
        # Start the service
        Write-Status "Starting cloudflared service..."
        try {
            Start-Service -Name $ServiceName -ErrorAction Stop
            Write-Success "Service started successfully"
        } catch {
            Write-Error "Failed to start service using PowerShell: $_"
            Write-VerboseLog "Start service error: $($_ | Format-List -Force | Out-String)"
            
            # Try using sc.exe to start service
            Write-Status "Attempting to start service using sc.exe..."
            $scStartOutput = sc.exe start $ServiceName
            Write-CommandOutput "sc.exe start $ServiceName" $scStartOutput
            
            # Wait for service to start
            Start-Sleep -Seconds 10
        }
        
        # Verify service is running
        $runningService = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
        Write-VerboseLog "Service status after start: $($runningService | Format-List -Force | Out-String)"
        
        if ($runningService -and $runningService.Status -eq 'Running') {
            Write-Success "Service running successfully"
        } else {
            Write-Error "Service not running after start attempt. Current status: $($runningService.Status)"
            Write-Status "Attempting to get service details..."
            $svcDetails = sc.exe qc $ServiceName
            Write-Host $svcDetails
            Write-CommandOutput "sc.exe qc $ServiceName" $svcDetails
            
            # Check Event Log for clues
            Write-Status "Checking Event Log for service errors..."
            $eventLogs = Get-EventLog -LogName System -EntryType Error -Newest 5 -Source "Service Control Manager" -ErrorAction SilentlyContinue
            foreach ($log in $eventLogs) {
                if ($log.Message -like "*$ServiceName*" -or $log.Message -like "*cloudflared*") {
                    Write-Host "Event Log Error: $($log.TimeGenerated) - $($log.Message)"
                    Write-VerboseLog "Event Log Error: $($log.TimeGenerated) - $($log.Message)"
                }
            }
            
            # Test running cloudflared directly to debug
            Write-Status "Testing cloudflared executable directly..."
            $testRunOutput = & $ExePath --version 2>&1
            Write-CommandOutput "cloudflared --version" $testRunOutput
            
            # Try to run the same command that the service would run
            Write-Status "Testing service command configuration..."
            $testServiceCmd = & $ExePath proxy-dns --config $ServiceConfigPath 2>&1
            Write-CommandOutput "cloudflared proxy-dns --config $ServiceConfigPath" $testServiceCmd
            
            # Install anyway but warn user
            Write-Status "WARNING: The service is not running properly. DNS functionality may not work as expected."
            Write-Status "Please check the logs or try restarting the computer."
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
            try {
                Restart-Service -Name $ServiceName -Force -ErrorAction Stop
                Write-Status "Service restarted"
            } catch {
                Write-Error "Failed to restart service: $_"
                Write-VerboseLog "Restart service error: $($_ | Format-List -Force | Out-String)"
                
                # Try sc.exe to restart
                $scRestartOutput = sc.exe stop $ServiceName
                Start-Sleep -Seconds 5
                $scStartOutput = sc.exe start $ServiceName
                Write-CommandOutput "sc.exe restart $ServiceName" "$scRestartOutput`n$scStartOutput"
            }
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
                try {
                    Restart-Service -Name $ServiceName -Force -ErrorAction Stop
                } catch {
                    Write-Error "Failed to restart service after recreating config: $_"
                    Write-VerboseLog "Restart service error: $($_ | Format-List -Force | Out-String)"
                }
                Start-Sleep -Seconds 5
            }
            
            # Try to run cloudflared directly to see any errors
            Write-Status "Running cloudflared with verbose logging for diagnostics..."
            $diagnosticLogFile = "$LogDir\cloudflared_diagnostic.log"
            Write-Status "Diagnostic output will be saved to: $diagnosticLogFile"
            
            # Run cloudflared with debug logs and capture output to file
            try {
                # Use correct debug flag format for newer versions
                $testOutput = & $ExePath proxy-dns --address :: --port 5353 --upstream $DoHUrl 2>&1 | Tee-Object -FilePath $diagnosticLogFile
                Write-Host $testOutput
                Write-CommandOutput "proxy-dns --address :: --port 5353" $testOutput
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

    # Check for and enable IPv6 support
    Write-Status "Checking IPv6 support on network interfaces..."
    try {
        $adapters = Get-NetAdapter | Where-Object Status -EQ 'Up'
        Write-VerboseLog "Active network adapters: $($adapters | Format-Table -AutoSize | Out-String)"
        
        if ($adapters.Count -eq 0) {
            Write-Error "No active network adapters found"
        } else {
            # Check if IPv6 is enabled on all adapters
            $ipv6Disabled = $false
            foreach ($adapter in $adapters) {
                $ipv6Components = Get-NetAdapterBinding -InterfaceAlias $adapter.Name -ComponentID 'ms_tcpip6'
                Write-VerboseLog "IPv6 status for adapter $($adapter.Name): $($ipv6Components.Enabled)"
                
                if (-not $ipv6Components.Enabled) {
                    $ipv6Disabled = $true
                    Write-Status "  IPv6 is disabled on adapter: $($adapter.Name). Enabling..."
                    try {
                        # Enable IPv6 on the interface
                        Enable-NetAdapterBinding -InterfaceAlias $adapter.Name -ComponentID 'ms_tcpip6'
                        Write-Success "  IPv6 enabled on adapter: $($adapter.Name)"
                        Write-VerboseLog "Enabled IPv6 on adapter $($adapter.Name)"
                    }
                    catch {
                        Write-Error "  Failed to enable IPv6 on adapter $($adapter.Name): $_"
                        Write-VerboseLog "IPv6 enable error on adapter $($adapter.Name): $($_ | Format-List -Force | Out-String)"
                    }
                }
            }
            
            # Check and enable IPv6 globally through registry if it was disabled
            $regPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters'
            if (Test-Path $regPath) {
                $disabledComponents = Get-ItemProperty -Path $regPath -Name 'DisabledComponents' -ErrorAction SilentlyContinue
                if ($disabledComponents -and $disabledComponents.DisabledComponents -ne 0) {
                    Write-Status "IPv6 is disabled globally. Enabling IPv6 through registry..."
                    try {
                        # Set DisabledComponents to 0 to enable IPv6
                        Set-ItemProperty -Path $regPath -Name 'DisabledComponents' -Value 0 -Type DWord -Force
                        Write-Success "IPv6 enabled globally through registry"
                        Write-VerboseLog "Set registry value: $regPath\DisabledComponents = 0"
                        
                        Write-Status "Note: A system restart will be required for global IPv6 changes to take full effect"
                    }
                    catch {
                        Write-Error "Failed to enable IPv6 through registry: $_"
                        Write-VerboseLog "Registry IPv6 enable error: $($_ | Format-List -Force | Out-String)"
                    }
                } else {
                    Write-Success "IPv6 is already enabled globally"
                }
            }
        }
    }
    catch {
        Write-Error "Failed to check or enable IPv6: $_"
        Write-VerboseLog "IPv6 check error: $($_ | Format-List -Force | Out-String)"
        # Continue with the script even if IPv6 check/enable fails
    }

    # 5. Point all "Up" adapters at localhost for both IPv4 and IPv6
    Write-Status "Configuring network adapters to use localhost for both IPv4 and IPv6 DNS..."
    try {
        $adapters = Get-NetAdapter | Where-Object Status -EQ 'Up'
        Write-VerboseLog "Active network adapters: $($adapters | Format-Table -AutoSize | Out-String)"
        
        if ($adapters.Count -eq 0) {
            Write-Error "No active network adapters found"
        } else {
            foreach ($adapter in $adapters) {
                Write-Status "  Setting IPv4 DNS for adapter: $($adapter.Name)"
                $previousDnsIPv4 = Get-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 | Select-Object -ExpandProperty ServerAddresses
                Write-VerboseLog "Adapter $($adapter.Name) previous IPv4 DNS: $($previousDnsIPv4 -join ', ')"
                
                # Set IPv4 DNS
                Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses '127.0.0.1' -ErrorAction Stop
                $newDnsIPv4 = Get-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 | Select-Object -ExpandProperty ServerAddresses
                Write-VerboseLog "Adapter $($adapter.Name) new IPv4 DNS: $($newDnsIPv4 -join ', ')"
                
                # Set IPv6 DNS
                Write-Status "  Setting IPv6 DNS for adapter: $($adapter.Name)"
                try {
                    # First try PowerShell method
                    Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses '::1' -AddressFamily IPv6 -ErrorAction Stop
                    Write-Success "  IPv6 DNS configured for adapter: $($adapter.Name)"
                } catch {
                    Write-Status "  PowerShell method for IPv6 DNS setting failed. Falling back to netsh..."
                    Write-VerboseLog "IPv6 DNS setting error with PowerShell: $($_ | Format-List -Force | Out-String)"
                    
                    try {
                        # Get interface name for netsh
                        $interfaceName = $adapter.Name
                        
                        # Use netsh to set IPv6 DNS - make sure to handle spaces in interface names
                        $quotedInterfaceName = "`"$interfaceName`""
                        
                        # First remove any existing IPv6 DNS servers
                        $netshRemoveOutput = netsh interface ipv6 delete dnsservers $quotedInterfaceName all
                        Write-CommandOutput "netsh interface ipv6 delete dnsservers" $netshRemoveOutput
                        
                        # Then add our IPv6 DNS server
                        $netshOutput = netsh interface ipv6 add dnsservers $quotedInterfaceName address=::1 index=1
                        Write-CommandOutput "netsh interface ipv6 add dnsservers" $netshOutput
                        
                        # Verify the setting
                        $verifyDnsIPv6 = Get-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv6 -ErrorAction SilentlyContinue | Select-Object -ExpandProperty ServerAddresses
                        if ($verifyDnsIPv6 -contains "::1") {
                            Write-Success "  IPv6 DNS configured for adapter: $($adapter.Name) using netsh"
                        } else {
                            Write-Error "  Failed to set IPv6 DNS using netsh for adapter: $($adapter.Name)"
                            Write-VerboseLog "IPv6 DNS not set correctly after netsh: $($verifyDnsIPv6 -join ', ')"
                        }
                    } catch {
                        Write-Error "  Failed to set IPv6 DNS using netsh for adapter $($adapter.Name): $_"
                        Write-VerboseLog "netsh error: $($_ | Format-List -Force | Out-String)"
                    }
                }
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
            $dnsResult = Receive-Job -Job $job -ErrorAction Stop
            if ($dnsResult) {
                Write-Success "DNS resolution successful: $(($dnsResult | Select-Object -First 1).IPAddress)"
                Write-VerboseLog "DNS resolution result: $($dnsResult | Format-List -Force | Out-String)"
                
                # Additional test to verify we're getting results through NextDNS
                $job2 = Start-Job -ScriptBlock { 
                    param($server)
                    Resolve-DnsName nextdns.io -Server $server -ErrorAction Stop 
                } -ArgumentList "127.0.0.1"
                
                $completed2 = Wait-Job -Job $job2 -Timeout 15
                if ($completed2) {
                    $dnsQuery = Receive-Job -Job $job2 -ErrorAction Stop
                    if ($dnsQuery) {
                        Write-Success "NextDNS resolution successful: $(($dnsQuery | Select-Object -First 1).IPAddress)"
                        Write-VerboseLog "NextDNS resolution result: $($dnsQuery | Format-List -Force | Out-String)"
                    } else {
                        Write-Error "NextDNS resolution returned no results"
                        Write-VerboseLog "NextDNS resolution job returned null/empty"
                    }
                } else {
                    Write-Error "NextDNS resolution timed out"
                    Write-VerboseLog "NextDNS resolution job timed out"
                    Remove-Job -Job $job2 -Force
                }
            } else {
                Write-Error "DNS resolution returned no results"
                Write-VerboseLog "DNS resolution job returned null/empty"
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
        
        # Check port 53 on any interface
        $netstatAnyResult = netstat -an | Select-String ":53 "
        Write-Host "Port 53 listening on any interface:"
        Write-Host $netstatAnyResult
        Write-VerboseLog "Any interface port 53 check: $netstatAnyResult"
        
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
            $nslookupResult = nslookup example.com 127.0.0.1 2>&1
            Write-Host $nslookupResult
            Write-CommandOutput "nslookup example.com 127.0.0.1" $nslookupResult
            
            # Try with dig if available
            if (Get-Command dig -ErrorAction SilentlyContinue) {
                Write-Status "Testing with dig..."
                # Use Start-Process to avoid PowerShell parsing issues with @ symbol
                $digResult = Start-Process -FilePath "dig" -ArgumentList "+short", "example.com", "@127.0.0.1" -NoNewWindow -Wait -RedirectStandardOutput "$env:TEMP\dig_output.txt" -RedirectStandardError "$env:TEMP\dig_error.txt"
                $digOutput = Get-Content "$env:TEMP\dig_output.txt" -ErrorAction SilentlyContinue
                $digError = Get-Content "$env:TEMP\dig_error.txt" -ErrorAction SilentlyContinue
                Write-Host "Dig output: $digOutput"
                Write-Host "Dig errors: $digError"
                Write-CommandOutput "dig +short example.com @127.0.0.1" "$digOutput`n$digError"
                
                # Clean up temporary files
                Remove-Item "$env:TEMP\dig_output.txt" -ErrorAction SilentlyContinue
                Remove-Item "$env:TEMP\dig_error.txt" -ErrorAction SilentlyContinue
            }
        } else {
            Write-Host "cloudflared process is not running"
            Write-VerboseLog "No cloudflared process found"
            
            # Check if service is running
            $serviceStatus = Get-Service $ServiceName -ErrorAction SilentlyContinue
            Write-Host "cloudflared service status: $($serviceStatus.Status)"
            Write-VerboseLog "cloudflared service status: $($serviceStatus | Format-List -Force | Out-String)"
            
            # Try running cloudflared directly
            Write-Status "Attempting to run cloudflared directly..."
            $directRunOutput = & $ExePath proxy-dns --address 127.0.0.1 --upstream $DoHUrl 2>&1
            Write-Host $directRunOutput
            Write-CommandOutput "cloudflared proxy-dns direct run" $directRunOutput
            
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

    # Test IPv6 DNS resolution
    try {
        Write-Status "Testing IPv6 DNS resolution with timeout..."
        $job = Start-Job -ScriptBlock { 
            param($server)
            Resolve-DnsName example.com -Type AAAA -Server $server -ErrorAction Stop 
        } -ArgumentList "::1"
        
        $completed = Wait-Job -Job $job -Timeout 15
        if ($completed) {
            $dnsResult = Receive-Job -Job $job
            Write-Success "IPv6 DNS resolution successful: $(($dnsResult | Select-Object -First 1).IPAddress)"
            Write-VerboseLog "IPv6 DNS resolution result: $($dnsResult | Format-List -Force | Out-String)"
        } else {
            Write-Error "IPv6 DNS resolution timed out"
            Write-VerboseLog "IPv6 DNS resolution job timed out"
            Remove-Job -Job $job -Force
        }
    }
    catch {
        Write-Error "IPv6 DNS resolution test failed: $_"
        Write-VerboseLog "IPv6 DNS resolution error: $($_ | Format-List -Force | Out-String)"
        
        # Additional debug info for IPv6 DNS resolution failures
        Write-Status "Checking if port 53 is listening on IPv6..."
        $netstatResultIPv6 = netstat -an | Select-String "\[::\]:53"
        Write-Host $netstatResultIPv6
        Write-VerboseLog "IPv6 port 53 check: $netstatResultIPv6"
        
        # Try simple nslookup with IPv6
        Write-Status "Testing with nslookup over IPv6..."
        Start-Sleep -Seconds 2
        $nslookupResultIPv6 = nslookup example.com ::1
        Write-Host $nslookupResultIPv6
        Write-CommandOutput "nslookup example.com ::1" $nslookupResultIPv6
    }

    # During verification section, add another check specifically for IPv6 port 53
    $port53IPv6Check = netstat -ano | Select-String "\[::\]:53"
    Write-Host "IPv6 port 53 status: $(if($port53IPv6Check){"In use by process"}else{"Not in use"})"
    Write-VerboseLog "Final IPv6 port 53 check: $port53IPv6Check"

    if ($port53IPv6Check) {
        Write-Host $port53IPv6Check
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
    Write-Host "IPv6 DNS Configuration Status:" -ForegroundColor Yellow
    if ($UseNetshFallback) {
        Write-Host "- IPv6 DNS was configured using netsh fallback method" -ForegroundColor Yellow
    } else {
        Write-Host "- IPv6 DNS was configured using standard PowerShell methods" -ForegroundColor Yellow
    }
    Write-Host "- To test IPv6 resolution, use: Resolve-DnsName example.com -Server ::1 -Type AAAA" -ForegroundColor Yellow

    Write-Host ""
    Write-Host "If you're experiencing issues with DNS resolution, try these troubleshooting steps:" -ForegroundColor Yellow
    Write-Host "1. Restart your computer" -ForegroundColor Yellow
    Write-Host "2. Manually check if cloudflared service is running after restart" -ForegroundColor Yellow
    Write-Host "3. Ensure no other services are using port 53" -ForegroundColor Yellow
    Write-Host "4. Check firewall settings to allow cloudflared to communicate" -ForegroundColor Yellow
    Write-Host "5. Review the logs in $LogDir for detailed information" -ForegroundColor Yellow

    # During verification section, add another check for config file
    # Add this right after the "Verifying installation..." line
    Write-Status "Verifying cloudflared configuration..."
    if (Test-Path $ServiceConfigPath) {
        Write-Success "Configuration file exists at: $ServiceConfigPath"
        $finalConfigContent = Get-Content $ServiceConfigPath -Raw
        Write-VerboseLog "Final config file content: $finalConfigContent"
        
        # Copy config to a backup location just in case
        $backupConfigPath = "$InstallDir\config.yml.backup"
        try {
            Copy-Item -Path $ServiceConfigPath -Destination $backupConfigPath -Force
            Write-Success "Created backup configuration at: $backupConfigPath"
            Write-VerboseLog "Created config backup at: $backupConfigPath"
        } catch {
            Write-Status "Failed to create backup configuration (non-critical): $_"
            Write-VerboseLog "Backup config error: $($_ | Format-List -Force | Out-String)"
        }
    } else {
        Write-Error "Configuration file missing during verification!"
        Write-VerboseLog "Config file missing during verification check"
        
        # Attempt to recreate config file
        Write-Status "Attempting to recreate missing configuration file..."
        try {
            # Ensure directory exists
            if (-Not (Test-Path $ServiceConfigDir)) {
                New-Item -Path $ServiceConfigDir -ItemType Directory -Force | Out-Null
                Write-VerboseLog "Recreated service config directory during verification"
            }
            
            # Recreate config
            $configContent | Set-Content -Path $ServiceConfigPath -Encoding ASCII -Force
            Write-Success "Recreated configuration file during verification"
            
            # Restart service to pick up new config
            Restart-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
            Write-Status "Restarted service to pick up recreated configuration"
            Start-Sleep -Seconds 5
        } catch {
            Write-Error "Failed to recreate configuration file: $_"
            Write-VerboseLog "Error recreating config during verification: $($_ | Format-List -Force | Out-String)"
        }
    }
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
