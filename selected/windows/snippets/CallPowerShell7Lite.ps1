<#
.SYNOPSIS
    Ensures the script is executed using PowerShell 7 or higher.

.DESCRIPTION
    This script verifies whether it is running in a PowerShell 7+ environment. 
    If not, and if PowerShell 7 (pwsh) is available on the system, it re-invokes itself using pwsh, passing along any parameters.
    If pwsh is not found, the script outputs a message and exits with an error code.
    Once running in PowerShell 7 or higher, it sets the output rendering mode to plaintext for consistent formatting.

.NOTES
    Author: SAN
    Date: 29/04/2025
    #public

.CHANGELOG
  22.05.25 SAN Added UTF8 to fix encoding issue with russian & french chars
#>


if (!($PSVersionTable.PSVersion.Major -ge 7)) {
  if (Get-Command pwsh -ErrorAction SilentlyContinue) {
    pwsh -File "`"$PSCommandPath`"" @PSBoundParameters
    exit $LASTEXITCODE
  } else {
    Write-Output "ERROR: PowerShell 7 is not available. Exiting."
    exit 1
  }
}
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$PSStyle.OutputRendering = "plaintext"
