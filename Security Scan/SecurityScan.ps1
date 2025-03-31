# Windows Defender Quick Scan

Write-Host "Starting Windows Defender Quick Scan..." -ForegroundColor Cyan

# Check if Windows Defender is enabled
$defenderStatus = Get-MpPreference
if ($defenderStatus -eq $null) {
    Write-Host "Windows Defender is not available or disabled on this system." -ForegroundColor Red
    exit
}

# Ask user for confirmation
$confirmation = Read-Host "Do you want to proceed with a quick scan? (Y/N)"
if ($confirmation -match "^[Nn]$") {
    Write-Host "Scan aborted by user." -ForegroundColor Yellow
    exit
}

# Run quick scan
Write-Host "Running quick scan..." -ForegroundColor Yellow
Start-MpScan -ScanType QuickScan

Write-Host "Quick scan initiated. You can check the scan results in Windows Security." -ForegroundColor Green

# Wait for user input before closing
Write-Host "Press Enter to exit..." -ForegroundColor Cyan
Read-Host
