﻿#Requires -Version 5.0

<#
.SYNOPSIS
    Gets the user remote sessions on the computer

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
    https://github.com/scriptrunner/ActionPacks/tree/master/WinSystemManagement/_QUERY_

.Parameter ComputerName
    [sr-en] Remote computer, if the name empty the local computer is used

.Parameter AccessAccount
    [sr-en] User account that has permission to perform this action. If Credential is not specified, the current user account is used.
#>

[CmdLetBinding()]
Param(
    [string]$ComputerName,    
    [PSCredential]$AccessAccount
)

try{
    [string[]]$Script:Header = @("SessionName","UserName","ID","Status","Type","Device") 
    $Script:result

    if([System.String]::IsNullOrWhiteSpace($ComputerName) -eq $true){
        $Script:result = qwinsta | ForEach-Object { (($_.Trim() -replace "\s+",","))} | ConvertFrom-Csv -Header $Script:Header
    }
    else {
        if($null -eq $AccessAccount){            
            $Script:result = Invoke-Command -ComputerName $ComputerName -ScriptBlock{
                (qwinsta | ForEach-Object { (($_.Trim() -replace "\s+",","))} | ConvertFrom-Csv -Header $Using:Header) 
            } -ErrorAction Stop
        }
        else {
            $Script:result = Invoke-Command -ComputerName $ComputerName -Credential $AccessAccount -ScriptBlock{
                (qwinsta | ForEach-Object { (($_.Trim() -replace "\s+",","))} | ConvertFrom-Csv -Header $Using:Header) 
            } -ErrorAction Stop
        }
    }      
    foreach($item in $Script:result){
        if(([System.Char]::IsLetter($item.UserName.ToCharArray()[0])) -and `
            [System.Char]::IsDigit($item.ID.ToCharArray()[0])){
                if($SRXEnv) {
                    $null = $SRXEnv.ResultList.Add($item.ID.toString())
                    $null = $SRXEnv.ResultList2.Add($item.UserName) # Display
                }
                else{
                    Write-Output $UserName
                }    
        }
    }
}
catch{
    throw
}
finally{
}