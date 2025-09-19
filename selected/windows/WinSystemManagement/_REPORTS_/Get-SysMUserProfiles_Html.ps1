﻿#Requires -Version 5.0
#Requires -Modules ActiveDirectory

<#
    .SYNOPSIS
        Generates a report with the Active Directory user profiles on the computer
    
    .DESCRIPTION  

    .NOTES
        This PowerShell script was developed and optimized for ScriptRunner. The use of the scripts requires ScriptRunner. 
        The customer or user is authorized to copy the script from the repository and use them in ScriptRunner. 
        The terms of use for ScriptRunner do not apply to this script. In particular, ScriptRunner Software GmbH assumes no liability for the function, 
        the use and the consequences of the use of this freely available script.
        PowerShell is a product of Microsoft Corporation. ScriptRunner is a product of ScriptRunner Software GmbH.
        © ScriptRunner Software GmbH

    .COMPONENT
        Requires Module ActiveDirectory
        Requires Library Script ReportLibrary from the Action Pack Reporting\_LIB_

    .LINK
        https://github.com/scriptrunner/ActionPacks/tree/master/WinSystemManagement/_REPORTS_ 
                
    .Parameter ComputerName
        [sr-en] Computer from which the profiles are listed
                
    .Parameter AccessAccount
        [sr-en] User account that has permission to perform this action. If Credential is not specified, the current user account is used
#>

param(
    [string]$ComputerName,
    [pscredential]$AccessAccount
)

Import-Module ActiveDirectory

$Script:Cim= $null
try{
    if([System.string]::IsNullOrWhiteSpace($ComputerName)){
        $ComputerName = [System.Net.DNS]::GetHostByName('').HostName
    }          
    if($null -eq $AccessAccount){
        $Script:Cim = New-CimSession -ComputerName $ComputerName -ErrorAction Stop
    }
    else {
        $Script:Cim = New-CimSession -ComputerName $ComputerName -Credential $AccessAccount -ErrorAction Stop
    }
    $profiles = Get-CimInstance -CimSession $Script:Cim -ClassName Win32_UserProfile -ErrorAction Stop `
                                | Where-Object{$_.Special -eq $false} | Select-Object LastUseTime,SID

    $Script:output = @()                            
    foreach($itm in $profiles){
        $sid = $itm.SID
        $usr = Get-ADUser -Filter{SID -eq $sid} -Properties Name
        if([System.String]::IsNullOrWhiteSpace($usr.Name) -eq $false){            
            $Script:output +=  [PSCustomObject] @{
                                'User' = $usr.Name;                                
                                'Last use' = $itm.LastUseTime
            }
        }
    }

    ConvertTo-ResultHtml -Result $Script:output
}
catch{
    throw
}
finally{
    if($null -ne $Script:Cim){
        Remove-CimSession $Script:Cim 
    }
}