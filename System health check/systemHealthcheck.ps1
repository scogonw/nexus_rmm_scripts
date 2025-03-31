# System Health Check Script

Write-Host "Starting System Health Check..." -ForegroundColor Cyan

# Get System Information
Write-Host "System Information:" -ForegroundColor Yellow
Get-ComputerInfo | Select-Object CsName, OsName, OsArchitecture, WindowsVersion, WindowsBuildLabEx

# Check CPU Usage
Write-Host "CPU Usage:" -ForegroundColor Yellow
Get-WmiObject Win32_Processor | Select-Object LoadPercentage

# Check Memory Usage
Write-Host "Memory Usage:" -ForegroundColor Yellow
Get-CimInstance Win32_OperatingSystem | Select-Object @{Name='TotalMemory(GB)';Expression={[math]::round($_.TotalVisibleMemorySize/1MB,2)}},
                                                         @{Name='FreeMemory(GB)';Expression={[math]::round($_.FreePhysicalMemory/1MB,2)}}

# Check Disk Space
Write-Host "Disk Space Usage:" -ForegroundColor Yellow
Get-PSDrive -PSProvider FileSystem | Select-Object Name, @{Name='FreeSpace(GB)';Expression={[math]::round($_.Free/1GB,2)}}, @{Name='TotalSize(GB)';Expression={[math]::round($_.Used/1GB,2)}}

# Check Network Status
Write-Host "Network Status:" -ForegroundColor Yellow
Test-NetConnection | Select-Object ComputerName, PingSucceeded, TcpTestSucceeded

# Check Running Services
Write-Host "Running Critical Services:" -ForegroundColor Yellow
Get-Service | Where-Object { $_.Status -eq 'Running' } | Select-Object DisplayName, Status

# Wait for user input before closing
Write-Host "System Health Check Completed." -ForegroundColor Green
Write-Host "Press Enter to exit..." -ForegroundColor Cyan
Read-Host
