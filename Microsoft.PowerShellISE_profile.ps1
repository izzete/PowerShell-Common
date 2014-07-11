<#
.SYNOPSIS
   My Powershell ISE profile

.DESCRIPTION
   My custom functions, menu items, etc.

.NOTES
   2014-06-26   IZZETE   Initial version
#>


<#
.SYNOPSIS
Adds indicator for ISE tab to show when it is running a command
 
.DESCRIPTION
See http://jrich523.wordpress.com/2012/03/09/powershell-ise-addon-for-running-tabs/

.EXAMPLE
Add-TabStatusIndicator

.NOTES
   2014-06-27   IZZETE   Initial version
#>
function Add-TabStatusIndicator
{
    [CmdletBinding()]
    param()

    Register-ObjectEvent $psise.CurrentPowerShellTab PropertyChanged -Action {
        If($Event.SourceArgs[1].PropertyName -eq "StatusText")
        { 
            $tab  = $event.Sender 
            $name = $tab.displayname
            if($Event.SourceArgs[0].StatusText -like "Running*")
            { 
                $tab.displayname = "* $name" 
            }
            elseif($Event.SourceArgs[0].StatusText -eq "Completed" -or $Event.SourceArgs[0].StatusText -eq "Stopped")
            { 
                $Tab.DisplayName = $name -replace "\* " 
            }
        } 
    }
}


<#
.SYNOPSIS
Create new ISE tab
 
.DESCRIPTION
Creates an empty ISE tab with an isolated Powershell instance. Use Add-ons menu
to connect to remote servers, import commands, enter sessions, etc.

Note that the items in the Add-Ons menu assume that the tab label is the hostname
of the server you're connecting to. 

.EXAMPLE
New-Tab SERVER

.NOTES
   2014-06-27   IZZETE   Initial version
#>
function New-Tab([string]$Name,[ScriptBlock]$ScriptBlock)
{
    $NewTab = $psISE.PowerShellTabs.Add()
    $NewTab.DisplayName = $Name.ToUpper()

    # Wait until the tab is ready
    while (-not $NewTab.CanInvoke) {
        Start-Sleep -m 100
    }

    $NewTab.Invoke({Add-TabStatusIndicator})

    # Wait until the tab is ready
    while (-not $NewTab.CanInvoke) {
        Start-Sleep -m 100
    }

    $NewTab.Invoke({cd C:\; cls})

    # Wait until the tab is ready
    while (-not $NewTab.CanInvoke) {
        Start-Sleep -m 100
    }
}


$psISE.CurrentPowerShellTab.AddOnsMenu.SubMenus.Add(
    "Connect to server", 
    {
        $Username   = $env:USERDOMAIN.ToUpper() + "\adm_" + $env:USERNAME.ToLower()
        $Credential = Get-Credential $Username
        $Server     = $psISE.CurrentPowerShellTab.DisplayName -replace "\* "
        $Server     = $psISE.CurrentPowerShellTab.DisplayName -replace "-[0-9]$"
        $Session    = New-PSSession -ComputerName $Server -Credential $Credential -Authentication Kerberos
#        Import-PSSession $Session
    },
    "Alt+1"
)

$psISE.CurrentPowerShellTab.AddOnsMenu.SubMenus.Add(
    "Open a remote session", 
    {
        Enter-PSSession $Session
    },
    "Alt+2"
)

$psISE.CurrentPowerShellTab.AddOnsMenu.SubMenus.Add(
    "Import commands", 
    {
        # Find active session manually; shouldn't be needed since $Session should already contain it
        # $Session    = Get-PSSession | ? { $_.ComputerName -eq $psISE.CurrentPowerShellTab.DisplayName -and $_.ConfigurationName -eq "Microsoft.PowerShell" }

        # Uncomment below to use remote AD commands instead of local
        #Invoke-Command -Session $Session -ScriptBlock { Import-Module ActiveDirectory }
        #Import-PSSession -Session $Session -Module ActiveDirectory
    },
    "Alt+3"
)

$psISE.CurrentPowerShellTab.AddOnsMenu.SubMenus.Add(
    "Connect to Exchange 2010 via EMS", {
        Add-PSSnapin Microsoft.Exchange.Management.PowerShell.E2010
        . $env:ExchangeInstallPath\bin\RemoteExchange.ps1
        Connect-ExchangeServer -auto
            },
    "Alt+9"
)

$psISE.CurrentPowerShellTab.AddOnsMenu.SubMenus.Add(
    "Import Exchange commands", 
    {
        $Username   = $env:USERDOMAIN.ToUpper() + "\adm_" + $env:USERNAME.ToLower()
        $Credential = Get-Credential $Username
        $Server     = $psISE.CurrentPowerShellTab.DisplayName -replace "\* "
        $Server     = $psISE.CurrentPowerShellTab.DisplayName -replace "-[0-9]$"
        $ExSession  = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri http://$Server/PowerShell/ -Credential $Credential -Authentication Kerberos
        Import-PSSession $ExSession
    },
    "Alt+0"
)

