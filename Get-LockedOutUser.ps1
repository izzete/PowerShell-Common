#Requires -Version 3.0
<#
.SYNOPSIS
    Returns a list of users who are locked out in Active Directory

.DESCRIPTION
    Returns a list of users who were locked out in Active Directory by querying the event logs on the PDC emulator

    See http://mikefrobbins.com/2013/11/29/powershell-script-to-determine-what-device-is-locking-out-an-active-directory-user-account/

.PARAMETER UserName
    The userid of the specific user you are looking for lockouts for. The default is all locked out users.

.PARAMETER StartTime
    The datetime to start searching from. The default is all datetimes that exist in the event logs.

.EXAMPLE
    Get-LockedOutUser.ps1

.EXAMPLE
    Get-LockedOutUser.ps1 -UserName 'mikefrobbins'

.EXAMPLE
    Get-LockedOutUser.ps1 -StartTime (Get-Date).AddDays(-1)

.EXAMPLE
    Get-LockedOutUser.ps1 -UserName 'mikefrobbins' -StartTime (Get-Date).AddDays(-1)
#>

[CmdletBinding()]
param (
    [ValidateNotNullOrEmpty()]
    [string]$DomainName = $env:USERDOMAIN,
    [ValidateNotNullOrEmpty()]
    [string]$UserName = "*",
    [ValidateNotNullOrEmpty()]
    [datetime]$StartTime = (Get-Date).AddDays(-3)
)

$DomainName  = "CITRITE"
$DirContext  = New-Object System.DirectoryServices.ActiveDirectory.DirectoryContext('Domain', $DomainName)
$PDCEmulator = [System.DirectoryServices.ActiveDirectory.Domain]::GetDomain($DirContext).PdcRoleOwner.Name

$SearchEventLog = 
{
    Get-WinEvent -FilterHashtable @{LogName='Security';Id=4740;StartTime=$Using:StartTime} |
    Where-Object {$_.Properties[0].Value -like "$Using:UserName"} |
    Select-Object -Property TimeCreated,
        @{Label='UserName';Expression={$_.Properties[0].Value}},
        @{Label='ClientName';Expression={$_.Properties[1].Value}}
}

Invoke-Command -ComputerName $PDCEmulator -Credential (Get-Credential) -ScriptBlock $SearchEventLog  `
    | Select-Object -Property TimeCreated, UserName, ClientName