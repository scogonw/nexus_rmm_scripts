# Security Audit & Threat Detection Script

Write-Host "Starting Security Audit & Threat Detection..." -ForegroundColor Cyan

# Check Windows Defender Status
Write-Host "Checking Windows Defender status..." -ForegroundColor Yellow
$defenderStatus = Get-MpComputerStatus
if ($defenderStatus.AntivirusEnabled) {
    Write-Host "Windows Defender is enabled." -ForegroundColor Green
} else {
    Write-Host "Warning: Windows Defender is disabled!" -ForegroundColor Red
}

# Check for Recent Threats
Write-Host "Checking for recent threats detected by Windows Defender..." -ForegroundColor Yellow
$threats = Get-MpThreatDetection
if ($threats) {
    Write-Host "Recent threats found:" -ForegroundColor Red
    $threats | Format-Table -AutoSize
} else {
    Write-Host "No recent threats detected." -ForegroundColor Green
}

# Check Firewall Status
Write-Host "Checking Windows Firewall status..." -ForegroundColor Yellow
$firewallStatus = Get-NetFirewallProfile | Select-Object Name, Enabled
$firewallStatus | Format-Table -AutoSize

# Check Security Updates
Write-Host "Checking for pending security updates..." -ForegroundColor Yellow
$pendingUpdates = Get-WindowsUpdate -Category Security -ErrorAction SilentlyContinue
if ($pendingUpdates) {
    Write-Host "Security updates are available:" -ForegroundColor Red
    $pendingUpdates | Format-Table -AutoSize
} else {    
    Write-Host "System is up to date with security patches." -ForegroundColor Green
}

# Ask User for Full System Scan
$scanChoice = Read-Host "Do you want to run a full system scan? (Y/N)"
if ($scanChoice -match "^[Yy]$") {
    Write-Host "Starting full system scan..." -ForegroundColor Yellow
    Start-MpScan -ScanType FullScan
} else {
    Write-Host "Skipping full system scan." -ForegroundColor Cyan
}

# Wait for user input before closing
Write-Host "Press Enter to exit..." -ForegroundColor Cyan
Read-Host
