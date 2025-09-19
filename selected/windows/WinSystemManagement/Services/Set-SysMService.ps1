﻿#Requires -Version 5.0

<#
.SYNOPSIS
    Starts, stops, and suspends a service, and changes its properties

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
    https://github.com/scriptrunner/ActionPacks/tree/master/WinSystemManagement/Services

.Parameter ComputerName
    [sr-en] Gets the service running on the specified computer. The default is the local computer

.Parameter ServiceName
    [sr-en] Service name of the service to be changed

.Parameter DisplayName
    [sr-en] New display name for the service

.Parameter Description
    [sr-en] New description for the service

.Parameter StartupType
    [sr-en] Changes the start mode of the service

.Parameter Status
    [sr-en] Starts, stops, or suspends (pauses) the service
#>

[CmdLetBinding()]
Param(
    [Parameter(Mandatory = $true)]
    [string]$ServiceName,
    [string]$ComputerName,
    [string]$DisplayName ,
    [string]$Description,
    [ValidateSet("Automatic","Manual","Disabled")]
    [string]$StartupType,
    [ValidateSet("Running","Stopped","Paused")]
    [string]$Status
)

try{
    [string[]]$Properties = @('Name','DisplayName','Status','RequiredServices','DependentServices','CanStop','CanShutdown','CanPauseAndContinue')

    if([System.String]::IsNullOrWhiteSpace($ComputerName) -eq $true){
        $ComputerName = "."
    }
    $Script:srv = Get-Service -ComputerName $ComputerName -Name $ServiceName -ErrorAction Stop 
    if($PSBoundParameters.ContainsKey("DisplayName") -eq $true){
        $null = Set-Service -ComputerName $ComputerName -Name $Script:srv.Name -DisplayName $DisplayName -Confirm:$false -ErrorAction Stop
    }
    if($PSBoundParameters.ContainsKey("Description") -eq $true){
        $null = Set-Service -ComputerName $ComputerName -Name $Script:srv.Name -Description $Description -Confirm:$false -ErrorAction Stop
    }
    if($PSBoundParameters.ContainsKey("StartupType") -eq $true){
        $null = Set-Service -ComputerName $ComputerName -Name $Script:srv.Name -StartupType $StartupType -Confirm:$false -ErrorAction Stop
    }
    if($PSBoundParameters.ContainsKey("Status") -eq $true){
        $null = Set-Service -ComputerName $ComputerName -Name $Script:srv.Name -Status $Status -Confirm:$false -ErrorAction Stop
    }

    $result = Get-Service -ComputerName $ComputerName -Name $Script:srv.Name -ErrorAction Stop | Select-Object $Properties
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
}