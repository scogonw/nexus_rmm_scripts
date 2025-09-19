﻿#Requires -Version 5.0

<#
.SYNOPSIS
    Generates a report with an app package installation log

.DESCRIPTION

.NOTES
    This PowerShell script was developed and optimized for ScriptRunner. The use of the scripts requires ScriptRunner. 
    The customer or user is authorized to copy the script from the repository and use them in ScriptRunner. 
    The terms of use for ScriptRunner do not apply to this script. In particular, ScriptRunner Software GmbH assumes no liability for the function, 
    the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. ScriptRunner is a product of ScriptRunner Software GmbH.
    © ScriptRunner Software GmbH

.COMPONENT
    Requires Library Script ReportLibrary from the Action Pack Reporting\_LIB_

.LINK
    https://github.com/scriptrunner/ActionPacks/tree/master/WinSystemManagement/_REPORTS_

.Parameter ResultItems
    [sr-en] Limit the number of the last logs

.Parameter ComputerName
    [sr-en] Remote computer, if the name empty the local computer is used

.Parameter AccessAccount
    [sr-en] User account that has permission to perform this action. If Credential is not specified, the current user account is used.
#>

[CmdLetBinding()]
Param(
    [ValidateRange(1,100)]
    [int]$ResultItems = 20,
    [string]$ComputerName,    
    [PSCredential]$AccessAccount
)

try{    
    [string[]]$Properties = @('Id','UserID','TimeCreated','ActivityId','LevelDisplayName')
    $Script:output    
    
    if([System.String]::IsNullOrWhiteSpace($ComputerName) -eq $true){        
        $Script:output = Get-AppxLog -All -ErrorAction Stop | Select-Object $Properties -Last $ResultItems        
    }
    else {
        if($null -eq $AccessAccount){
             $Script:output = Invoke-Command -ComputerName $ComputerName -ScriptBlock{
                Get-AppxLog -All -ErrorAction Stop | Select-Object $Using:Properties -Last $Using:ResultItems
            } -ErrorAction Stop
        }
        else {            
            $Script:output = Invoke-Command -ComputerName $ComputerName -Credential $AccessAccount -ScriptBlock{
                Get-AppxLog -All -ErrorAction Stop | Select-Object $Using:Properties -Last $Using:ResultItems
            } -ErrorAction Stop
        }
    }      
    
    ConvertTo-ResultHtml -Result $Script:output
}
catch{
    throw
}
finally{
}