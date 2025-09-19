﻿#Requires -Version 5.0

<#
.SYNOPSIS
    Retrieves DNS interface aliases

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
    [sr-en] Name of the computer from which to retrieve the dns client
    
.Parameter AccessAccount
    [sr-en] User account that has permission to perform this action. If Credential is not specified, the current user account is used.
#>

[CmdLetBinding()]
Param(
    [string]$ComputerName,
    [PSCredential]$AccessAccount
)

$Script:Cim
try{
    if([System.String]::IsNullOrWhiteSpace($ComputerName)){
        $ComputerName = [System.Net.DNS]::GetHostByName('').HostName
    }          
    if($null -eq $AccessAccount){
        $Script:Cim = New-CimSession -ComputerName $ComputerName -ErrorAction Stop
    }
    else {
        $Script:Cim = New-CimSession -ComputerName $ComputerName -Credential $AccessAccount -ErrorAction Stop
    }

    $result = Get-DnsClientServerAddress -CimSession $Script:Cim | Select-Object InterfaceAlias,ServerAddresses | Sort-Object InterfaceAlias
    foreach($item in $result)
    {
        if($SRXEnv) {
            $null = $SRXEnv.ResultList.Add($item.InterfaceAlias)
            $null = $SRXEnv.ResultList2.Add("$($item.InterfaceAlias) | $($item.ServerAddresses)")
        }
        else{
            Write-Output $item.InterfaceAlias
        }
    }
}
catch{
    throw
}
finally{
    if($null -ne $Script:Cim){
        Remove-CimSession $Script:Cim 
    }
}