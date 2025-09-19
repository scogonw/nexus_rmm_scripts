﻿#Requires -Version 5.0

<#
.SYNOPSIS
    Restores Bitlocker encryption for the specified volume

.DESCRIPTION

.NOTES
    This PowerShell script was developed and optimized for ScriptRunner. The use of the scripts requires ScriptRunner. 
    The customer or user is authorized to copy the script from the repository and use them in ScriptRunner. 
    The terms of use for ScriptRunner do not apply to this script. In particular, ScriptRunner Software GmbH assumes no liability for the function, 
    the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. ScriptRunner is a product of ScriptRunner Software GmbH.
    © ScriptRunner Software GmbH

.COMPONENT

.LINK
    https://github.com/scriptrunner/ActionPacks/tree/master/WinSystemManagement/BitLocker

.Parameter DriveLetter
    [sr-en] Drive letter
 
.Parameter ComputerName
    [sr-en] Remote computer, if the name empty the local computer is used

.Parameter AccessAccount
    [sr-en] User account that has permission to perform this action. If Credential is not specified, the current user account is used.
#>

[CmdLetBinding()]
Param(
    [Parameter(Mandatory = $true)]    
    [string]$DriveLetter,
    [string]$ComputerName,    
    [PSCredential]$AccessAccount
)

try{
    $Script:output
    [string[]]$Properties = @('MountPoint','EncryptionMethod','VolumeStatus','ProtectionStatus','EncryptionPercentage','VolumeType','CapacityGB')
    
    if([System.String]::IsNullOrWhiteSpace($ComputerName) -eq $true){
        $null = Resume-BitLocker -MountPoint $DriveLetter -Confirm:$false -ErrorAction Stop
        $Script:output = Get-BitLockerVolume -MountPoint $DriveLetter | Select-Object $Properties
    }
    else {
        if($null -eq $AccessAccount){
            Invoke-Command -ComputerName $ComputerName -ScriptBlock{
                Resume-BitLocker -MountPoint $Using:DriveLetter -Confirm:$false -ErrorAction Stop
            } -ErrorAction Stop
            $Script:output = Invoke-Command -ComputerName $ComputerName -ScriptBlock{
                Get-BitLockerVolume -MountPoint $Using:DriveLetter | Select-Object $Using:Properties
            }
        }
        else {
            Invoke-Command -ComputerName $ComputerName -Credential $AccessAccount -ScriptBlock{
                Resume-BitLocker -MountPoint $Using:DriveLetter -Confirm:$false -ErrorAction Stop
            } -ErrorAction Stop
            $Script:output = Invoke-Command -ComputerName $ComputerName -Credential $AccessAccount -ScriptBlock{
                Get-BitLockerVolume -MountPoint $Using:DriveLetter | Select-Object $Using:Properties
            }
        }
    }      
    
    if($SRXEnv) {
        $SRXEnv.ResultMessage = $Script:output
    }
    else{
        Write-Output $Script:output
    }
}
catch{
    throw
}
finally{
}