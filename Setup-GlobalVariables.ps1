﻿<#
.SYNOPSIS
   Sets common global variables 

.DESCRIPTION
   Used to setup global variables used by other scripts

.EXAMPLE
   Setup-GlobalVariables

.NOTES
   2014-06-27   IZZETE   Initial version
#>
function Setup-GlobalVariables
{
    [CmdletBinding()]
    param
    (
        [boolean] $UseSubFolders = $false                # Use subfolder within work folders or place files in root
    )

#    $VerbosePreference = 'SilentlyContinue'             # set to SilentlyContinue to disable, Continue to enable
#    $DebugPreference   = 'SilentlyContinue'             # set to SilentlyContinue to disable, Continue to enable
#    $WarningPreference = 'SilentlyContinue'             # set to SilentlyContinue to disable, Continue to enable

    # Determine location of work folders
    if ($psISE) {
        # If running in debugger
        $global:Script     = $psISE.CurrentFile.FullPath
        $global:ScriptName = $psISE.CurrentFile.DisplayName -replace ".ps1", ""
        $global:ScriptName = $ScriptName -replace "\*", ""
        $global:ScriptPath = Split-Path -Parent -Path $psISE.CurrentFile.FullPath
    }
    else {
        # Else running in powershell console
        $global:ScriptName = $MyInvocation.MyCommand.Name -replace ".ps1", ""
        $global:ScriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition 
        #$global:ScriptPath  = $PSScriptRoot                         # PowerShell 3+
    }

    if ($UseSubFolders)
    {
        $global:ConfigPath  = $ScriptPath + "\Configs\" + $ScriptName
        $global:LogPath     = $ScriptPath + "\Logs\"    + $ScriptName
        $global:PicklePath  = $ScriptPath + "\Pickles\" + $ScriptName
        $global:ResultPath  = $ScriptPath + "\Results\" + $ScriptName
        $global:TempPath    = $ScriptPath + "\Temp\"    + $ScriptName
    }
    else
    {
        $global:ConfigPath  = $ScriptPath + "\Configs\"
        $global:LogPath     = $ScriptPath + "\Logs\"    + $ScriptName
        $global:PicklePath  = $ScriptPath + "\Pickles\"
        $global:ResultPath  = $ScriptPath + "\Results\"
        $global:TempPath    = $ScriptPath + "\Temp\"
    }

    # Create work folders
    New-Item -ItemType Directory -Force -Path $ConfigPath | Out-Null
    New-Item -ItemType Directory -Force -Path $LogPath    | Out-Null
    New-Item -ItemType Directory -Force -Path $PicklePath | Out-Null
    New-Item -ItemType Directory -Force -Path $ResultPath | Out-Null
    New-Item -ItemType Directory -Force -Path $TempPath   | Out-Null

    # Get host info for system the script is running on
    $reg = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\" | select "NV Hostname", "NV Domain"
    $global:HostFQDN = ($reg.'NV Hostname' + "." + $reg.'NV Domain').ToLower()
    $global:Hostname = ($reg.'NV Hostname').ToUpper()

    # Setup log file
    $global:Timestamp = $(Get-Date -f yyyyMMdd_HHmmss)
    $global:LogFile   = $LogPath + "\$($ScriptName)_$($Hostname)_$($Timestamp).log"
}