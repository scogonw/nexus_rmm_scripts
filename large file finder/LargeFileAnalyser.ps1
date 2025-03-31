# Storage Analyzer & Large Files Finder

Write-Host "Welcome to the Storage Analyzer! Let's check your disk space and find large files." -ForegroundColor Cyan

# Define the drive to analyze
$drive = "C:\"  # Change this if needed
$largeFileSizeMB = 100  # Define size threshold for large files

# Get drive space details
Write-Host "Checking disk space for $drive..." -ForegroundColor Yellow
$diskInfo = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root -eq $drive } | 
    Select-Object Name, @{Name='FreeSpace(GB)';Expression={[math]::round($_.Free/1GB,2)}}, 
                  @{Name='TotalSize(GB)';Expression={[math]::round(($_.Used + $_.Free)/1GB,2)}}
$diskInfo | Format-Table -AutoSize

# Find large files
Write-Host "Searching for files larger than $largeFileSizeMB MB..." -ForegroundColor Yellow
$largeFiles = Get-ChildItem -Path $drive -Recurse -ErrorAction SilentlyContinue | 
              Where-Object { $_.Length -gt ($largeFileSizeMB * 1MB) } | 
              Select-Object FullName, @{Name='SizeMB';Expression={[math]::round($_.Length/1MB,2)}} | 
              Sort-Object SizeMB -Descending

if ($largeFiles) {
    Write-Host "Large files found! Here's the list:" -ForegroundColor Green
    $largeFiles | Format-Table -AutoSize
    
    # Ask user if they want to delete a file
    Write-Host "Do you want to delete a file? Enter the full file path or type 'No' to skip." -ForegroundColor Yellow
    $fileToDelete = Read-Host "Enter file path or 'No'"
    
    if ($fileToDelete -ne "No") {
        if (Test-Path $fileToDelete) {
            Remove-Item $fileToDelete -Force
            Write-Host "File deleted successfully!" -ForegroundColor Green
        } else {
            Write-Host "File not found. Please check the path and try again." -ForegroundColor Red
        }
    } else {
        Write-Host "No files were deleted." -ForegroundColor Cyan
    }
} else {
    Write-Host "No large files found exceeding $largeFileSizeMB MB." -ForegroundColor Green
}

# Wait for user input before closing
Write-Host "Press Enter to exit..." -ForegroundColor Cyan
Read-Host
