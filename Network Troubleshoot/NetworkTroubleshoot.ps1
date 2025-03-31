# Wi-Fi / Network Troubleshooter

Write-Host "Starting Network Troubleshooter..." -ForegroundColor Cyan

# Check network connection
Write-Host "Checking network connectivity..." -ForegroundColor Yellow
$pingTest = Test-Connection -ComputerName 8.8.8.8 -Count 2 -Quiet

if ($pingTest) {
    Write-Host "Network is connected." -ForegroundColor Green
} else {
    Write-Host "No internet connection detected!" -ForegroundColor Red
}

# Check network speed
Write-Host "Testing network speed..." -ForegroundColor Yellow
$networkSpeed = (Test-NetConnection -ComputerName speedtest.net).Ping
Write-Host "Network Latency: $networkSpeed ms" -ForegroundColor Green

# Ask user if they want to troubleshoot network issues
$troubleshootChoice = Read-Host "Do you want to run network troubleshooting? (Y/N)"
if ($troubleshootChoice -match "^[Yy]$") {
    Write-Host "Running Windows Network Troubleshooter..." -ForegroundColor Yellow
    Start-Process -FilePath "msdt.exe" -ArgumentList "/id NetworkDiagnosticsWeb" -NoNewWindow
} else {
    Write-Host "Skipping network troubleshooting." -ForegroundColor Cyan
}

# Wait for user input before closing
Write-Host "Press Enter to exit..." -ForegroundColor Cyan
Read-Host
