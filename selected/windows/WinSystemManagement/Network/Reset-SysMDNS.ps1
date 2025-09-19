﻿#Requires -Version 5.0

<#
.SYNOPSIS
    Resets the DNS server IP addresses to the default value

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
    https://github.com/scriptrunner/ActionPacks/tree/master/WinSystemManagement/Network


.Parameter AdapterName
    [sr-en] Friendly name of the interface

.Parameter ComputerName
    [sr-en] Name of the computer on which to reset the dns
    
.Parameter AccessAccount
    [sr-en] User account that has permission to perform this action. If Credential is not specified, the current user account is used.
#>

[CmdLetBinding()]
Param(
    [Parameter(Mandatory = $true)]
    [string]$AdapterName,
    [string]$ComputerName,
    [PSCredential]$AccessAccount
)

$Script:Cim
[string[]]$Properties = @('ElementName','Address','EnabledState','InterfaceAlias')
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
    $null = Set-DnsClientServerAddress -CimSession $Script:Cim -InterfaceAlias $AdapterName -ResetServerAddresses -ErrorAction Stop
    
    $result = Get-DnsClientServerAddress -CimSession $Script:Cim -InterfaceAlias $AdapterName -ErrorAction Stop | Select-Object $Properties
    if($SRXEnv) {
        $SRXEnv.ResultMessage = $result 
    }
    else{
        Write-Output $result
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