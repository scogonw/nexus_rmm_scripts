<#
.SYNOPSIS
	Sets the given image file as desktop wallpaper
.DESCRIPTION
	This PowerShell script sets the given image file as desktop wallpaper (.JPG or .PNG supported)
.PARAMETER ImageFile
	Specifies the path to the image file
.PARAMETER Style
        Specifies either Fill, Fit, Stretch, Tile, Center, or Span (default)
.EXAMPLE
	PS> ./set-wallpaper C:\ocean.jpg
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$ImageFile = "", [string]$Style = "Span")

function SetWallPaperWithFallback {
    param (
        [Parameter(Mandatory=$true)]
        [string]$ImagePath,
        
        [ValidateSet('Fill', 'Fit', 'Stretch', 'Tile', 'Center', 'Span')]
        [string]$Style = "Span"
    )

    # Map style names to values
    $WallpaperStyle = switch($Style) {
        "Fill"    {"10"}
        "Fit"     {"6"}
        "Stretch" {"2"}
        "Tile"    {"0"}
        "Center"  {"0"}
        "Span"    {"22"}
    }

    # Set registry values for the style - suppressing output
    if ($Style -eq "Tile") {
        New-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name WallpaperStyle -PropertyType String -Value $WallpaperStyle -Force | Out-Null
        New-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name TileWallpaper -PropertyType String -Value 1 -Force | Out-Null
    } else {
        New-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name WallpaperStyle -PropertyType String -Value $WallpaperStyle -Force | Out-Null
        New-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name TileWallpaper -PropertyType String -Value 0 -Force | Out-Null
    }

    # Try method 1: Using Windows API
    try {
        Add-Type -TypeDefinition @"
        using System;
        using System.Runtime.InteropServices;
        using System.IO;

        public class Wallpaper {
            [DllImport("user32.dll", CharSet = CharSet.Auto)]
            public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
        }
"@
        # Ensure we use a properly formatted absolute path
        $ImagePath = [System.IO.Path]::GetFullPath($ImagePath)
        Write-Verbose "Setting wallpaper using SystemParametersInfo with path: $ImagePath"
        
        $SPI_SETDESKWALLPAPER = 0x0014
        $UpdateIniFile = 0x01
        $SendChangeEvent = 0x02
        $fWinIni = $UpdateIniFile -bor $SendChangeEvent
        
        $result = [Wallpaper]::SystemParametersInfo($SPI_SETDESKWALLPAPER, 0, $ImagePath, $fWinIni)
        
        if ($result -ne 0) {
            Write-Verbose "Successfully set wallpaper using SystemParametersInfo"
            return $true
        } else {
            Write-Verbose "SystemParametersInfo failed with code 0, trying fallback method"
        }
    } catch {
        Write-Verbose "Exception during API call: $_"
    }

    # Try method 2: Using .NET as fallback
    try {
        Write-Verbose "Using .NET fallback method to set wallpaper"
        Add-Type -TypeDefinition @"
        using System;
        using System.Runtime.InteropServices;
        using System.Drawing;
        using System.Drawing.Imaging;
        using Microsoft.Win32;
        namespace Wallpaper
        {
            public class Setter
            {
                public const int SetDesktopWallpaper = 20;
                public const int UpdateIniFile = 0x01;
                public const int SendWinIniChange = 0x02;
                [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
                private static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
                public static void SetWallpaper(string path)
                {
                    SystemParametersInfo(SetDesktopWallpaper, 0, path, UpdateIniFile | SendWinIniChange);
                }
            }
        }
"@ -ReferencedAssemblies System.Drawing
        
        # Ensure the image is saved in a compatible format
        $imageToUse = $ImagePath
        $extension = [System.IO.Path]::GetExtension($ImagePath).ToLower()
        
        # If not a BMP, create a temporary BMP copy which often works better
        if ($extension -ne ".bmp") {
            $tempFile = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), [System.IO.Path]::GetFileNameWithoutExtension($ImagePath) + ".bmp")
            Write-Verbose "Converting image to BMP format at: $tempFile"
            
            $img = [System.Drawing.Image]::FromFile($ImagePath)
            try {
                $img.Save($tempFile, [System.Drawing.Imaging.ImageFormat]::Bmp)
                $imageToUse = $tempFile
            } finally {
                $img.Dispose()
            }
        }
        
        [Wallpaper.Setter]::SetWallpaper($imageToUse)
        Write-Verbose "Applied wallpaper with .NET method"
        return $true
    } catch {
        Write-Verbose "Exception during .NET fallback: $_"
    }

    # Try method 3: Using PowerShell Com Object
    try {
        Write-Verbose "Using PowerShell Com Object method to set wallpaper"
        $shell = New-Object -ComObject WScript.Shell
        $userProfilePath = [System.Environment]::GetFolderPath('UserProfile')
        $desktopIniPath = Join-Path $userProfilePath "Desktop\desktop.ini"
        
        # Create or modify desktop.ini
        if (-not (Test-Path $desktopIniPath)) {
            New-Item -Path $desktopIniPath -ItemType File -Force | Out-Null
        }
        
        # Write the wallpaper configuration
        $iniContent = @"
[.ShellClassInfo]
LocalizedResourceName=@%SystemRoot%\system32\shell32.dll,-21787
[ExtShellFolderViews]
[{BE098140-A513-11D0-A3A4-00C04FD706EC}]
IconArea_Image=$ImagePath
"@
        Set-Content -Path $desktopIniPath -Value $iniContent -Force
        
        # Refresh the desktop
        $result = $shell.SendKeys("{F5}")
        Write-Verbose "Applied wallpaper with Com Object method"
        return $true
    } catch {
        Write-Verbose "Exception during Com Object method: $_"
    }

    # If all methods failed
    return $false
}

try {
    # Turn on verbose output for diagnostics
    $VerbosePreference = "Continue"
    
    # Prompt for image file if not provided
    if ($ImageFile -eq "") { 
        $ImageFile = Read-Host "Enter path to image file" 
    }
    
    # Convert to absolute path if needed
    if (-not [System.IO.Path]::IsPathRooted($ImageFile)) {
        $ImageFile = Join-Path -Path (Get-Location) -ChildPath $ImageFile
    }
    
    # Validate file exists
    if (-not (Test-Path -Path $ImageFile -PathType Leaf)) {
        Write-Error "The specified file does not exist: $ImageFile"
        exit 1
    }
    
    # Validate file is an image (basic check)
    $extension = [System.IO.Path]::GetExtension($ImageFile).ToLower()
    if ($extension -notin @('.jpg', '.jpeg', '.png', '.bmp', '.gif')) {
        Write-Warning "File may not be a supported image type. Only JPG, PNG, BMP and GIF are fully supported."
    }
    
    # Check if file is accessible and not locked
    try {
        $fileStream = [System.IO.File]::Open($ImageFile, 'Open', 'Read')
        $fileStream.Close()
        $fileStream.Dispose()
    } catch {
        Write-Error "Cannot access the image file. It may be locked or you don't have permissions: $($_.Exception.Message)"
        exit 1
    }
    
    # Log diagnostic information
    Write-Verbose "Setting wallpaper with the following details:"
    Write-Verbose "Image path: $ImageFile"
    Write-Verbose "Style: $Style"
    Write-Verbose "User: $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)"
    Write-Verbose "PowerShell version: $($PSVersionTable.PSVersion)"
    
    # Set the wallpaper using our multi-method function
    $success = SetWallPaperWithFallback -ImagePath $ImageFile -Style $Style
    
    if ($success) {
        $filename = [System.IO.Path]::GetFileName($ImageFile)
        Write-Host "✅ Wallpaper successfully set to '$filename' with style '$Style'"
        exit 0 # success
    } else {
        Write-Error "Failed to set wallpaper after trying multiple methods. Please check file permissions and format."
        exit 1
    }
} catch {
    Write-Host "⚠️ Error in line $($_.InvocationInfo.ScriptLineNumber): $($Error[0])" -ForegroundColor Red
    Write-Verbose "Full error details: $_"
    exit 1
}