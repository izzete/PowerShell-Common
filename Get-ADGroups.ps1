[CmdletBinding()]
Param ()

$VerbosePreference = 'SilentlyContinue'             # set to SilentlyContinue to disable, Continue to enable
$DebugPreference   = 'SilentlyContinue'             # set to SilentlyContinue to disable, Continue to enable
$WarningPreference = 'SilentlyContinue'             # set to SilentlyContinue to disable, Continue to enable

# Determine location of work folders
if ($psISE) {
    # If running in debugger
    $global:ScriptName = $psISE.CurrentFile.DisplayName   # -replace ".ps1", ""
    $global:ScriptPath = Split-Path -Parent -Path $psISE.CurrentFile.FullPath
}
else {
    # Else running in powershell console
    $global:ScriptName = $MyInvocation.MyCommand.Name
    $global:ScriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition 
    #$global:ScriptPath  = $PSScriptRoot                         # PowerShell 3+
}

$global:LogPath     = $ScriptPath + "\Logs"
$global:ResultsPath = $ScriptPath + "\Results" 
$global:PicklePath  = $ScriptPath + "\Pickles"

# Create work folders
New-Item -ItemType Directory -Force -Path $LogPath | Out-Null
New-Item -ItemType Directory -Force -Path $ResultsPath | Out-Null
New-Item -ItemType Directory -Force -Path $PicklePath | Out-Null

# Get host info for system the script is running on
$reg = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\" | select "NV Hostname", "NV Domain"
$global:HostFQDN = ($reg.'NV Hostname' + "." + $reg.'NV Domain').ToLower()
$global:Hostname = ($reg.'NV Hostname').ToUpper()

# Setup log file
$global:Timestamp = $(Get-Date -f yyyyMMdd_HHmmss)
$global:LogFile   = $ScriptName -replace ".ps1", "_${Hostname}_${Timestamp}.log"


#Start-Transcript "$LogFolder\$($Server)_$($Timestamp).log" -ErrorAction SilentlyContinue

function Get-RecipientType($Value)  {
<#
    .SYNOPSIS
    Return friendly name for msExchRecipientType field from Active Directory

    .DESCRIPTION
    See SYNOPSIS

    .EXAMPLE
    Get-RecipientDisplayType(1)
    
    .PARAMETER Value
    Integer to convert to friendly name
#>
    switch ($Value) {
        $null        {"NotExchange"}
        1            {"UserMailbox"}
        2            {"LinkedMailbox"}
        4            {"SharedMailbox"}
        8            {"Exchange2003Legacy"}
        16           {"RoomMailbox"}
        32           {"EquipmentMailbox"}
        64           {"MailContact"}
        128          {"MailUser"}
        256          {"MailUniversalDistributionGroup"}
        512          {"MailnonUniversalGroup"}
        1024         {"MailUniversalSecurityGroup"}
        2048         {"DynamicDistributionGroup"}
        4096         {"MailEnabledPublicFolder"}
        8192         {"SystemAttendantMailbox"}
        16384        {"MailboxDatabaseMailbox"}
        32768        {"AcrossForestMailContact"}
        65536        {"User"}
        131072       {"Contact"}
        262144       {"UniversalDistributionGroup"}
        524288       {"UniversalSecurityGroup"}
        1048576      {"NonUniversalGroup"}
        2097152      {"DisabledUser"}
        4194304      {"MicrosoftExchange"}
        8388608      {"MicrosoftExchange"}
        default      {"Unknown:$value"}
    }
}

function Get-RecipientDisplayType($value)  {
<#
    .SYNOPSIS
    Return friendly name for msExchRecipientDisplayType field from Active Directory

    .DESCRIPTION
    See SYNPOSIS

    .EXAMPLE
    Get-RecipientDisplayType(1)
    
    .PARAMETER Value
    Integer to convert to friendly name
#>       switch ($value) {
             $null        {"NotExchange"}
             1            {"MailUniversalDistributionGroup"}
             2            {"MailEnabledPublicFolder"}
             3            {"DynamicDistributionGroup"}
             4            {"Organization"}
             5            {"PrivateDistributionGroup"}
             6            {"MailUser or MailContact"}
             7            {"RoomMailbox"}
             8            {"EquipmentMailbox"}
             10           {"SystemMailbox"}
             1073741824   {"LinkedMailbox, SharedMailbox or UserMailbox"}
             1073741833   {"MailUniversalSecurityGroup"}
             default      {"Unknown:$value"}
       }
}

function Get-ADGroups {
    [CmdletBinding()]
    Param ()

    $Properties = @("Members", "proxyAddresses", "adminCount", "info", "ManagedBy", "msExchRecipientDisplayType", "msExchRecipientTypeDetails", "Modified")
    $Results    = `
        Get-ADGroup -ResultSetSize $null -Filter {Name -like "*"} -Properties $Properties | `
        % {
            $Group = $_

            # Skip groups known to be huge, like Domain Users, which will slow the script
            switch ($Group.Name) {
                "Domain Computers" { return }
            }

            $obj = New-Object –TypeName PSObject
            $obj | Add-Member -MemberType NoteProperty   -Name Status        -Value ""
            $obj | Add-Member -MemberType NoteProperty   -Name Name          -Value $Group.Name
            $obj | Add-Member -MemberType NoteProperty   -Name DN            -Value $Group.DistinguishedName
            $obj | Add-Member -MemberType NoteProperty   -Name MemberCount   -Value $Group.Members.Count
    #        $obj | Add-Member -MemberType NoteProperty   -Name ProxyAddresses -Value $Group.ProxyAddresses.Value
            $obj | Add-Member -MemberType ScriptProperty -Name MailEnabled   -Value { if($Group.ProxyAddresses -ne $null) {$true} else {$false} }
            $obj | Add-Member -MemberType NoteProperty   -Name GroupCategory -Value $Group.GroupCategory
            $obj | Add-Member -MemberType NoteProperty   -Name GroupScope    -Value $Group.GroupScope
            $obj | Add-Member -MemberType NoteProperty   -Name ModifiedDaysAgo -Value ([datetime]::Today - $Group.Modified).Days
            $obj | Add-Member -MemberType NoteProperty   -Name ManagedBy     -Value $Group.ManagedBy
            $obj | Add-Member -MemberType NoteProperty   -Name OutlookNote   -Value $Group.info
            $obj | Add-Member -MemberType ScriptProperty -Name RecipientDisplayType -Value { Get-RecipientDisplayType($Group.msExchRecipientDisplayType) }
            $obj | Add-Member -MemberType ScriptProperty -Name RecipientTypeDetails -Value {        Get-RecipientType($Group.msExchRecipientTypeDetails) }
            $obj | Add-Member -MemberType ScriptProperty -Name Protected     -Value { if ($Group.adminCount -eq 1) {$true} else {$false} }
            $obj | Add-Member -MemberType ScriptProperty -Name Builtin       -Value { if ($Group.DistinguishedName -like "*,CN=Builtin,*") {$true} else {$false} }
    #        $obj | Add-Member -MemberType ScriptProperty -Name MembersBucket -Value { switch ($this.MemberCount) { { [int]$_ -eq   0                      } { "  0 "  }
    #                                                                                                               { [int]$_ -eq   1                      } { "  1 "  }
    #                                                                                                               { [int]$_ -ge   2 -and [int]$_ -lt  10 } { "  2+"  }
    #                                                                                                               { [int]$_ -ge  10 -and [int]$_ -lt 100 } { " 10+"  }
    #                                                                                                               { [int]$_ -ge 100                      } { "100+"  }
    #                                                                                                             }
    #                                                                                }


         # NOTE: Get-ADGroup doesn't count groups, computers or other non-user members
         # If Get-ADGroup returns 0 members then check again with Get-ADGroupMember

        $Count = $Group.Members.Count
        $Name  = $Group.Name

        if ($Count -eq 0) {
            Write-Verbose "[$Name] Get-ADGroup reports zero members"

            $Members = Get-ADGroupMember $Group
            if ($Members -eq $null) {
                Write-Verbose "[$Name] Get-ADGroupMember reports zero members, definitely empty"
                $obj.Status      = "Empty"
                $obj.MemberCount = 0
            } else {
                Write-Verbose "[$Name] Get-ADGroupMember found members, not empty"
                $obj.Status      = "Not Empty"
                $obj.MemberCount = $Members.Count
            }
        } 
        else {
            Write-Verbose "[$Name] Get-ADGroup reports $Count members"

            $obj.Status      = "Not Empty"
            $obj.MemberCount = $Count
        }

        $obj | select *
    }

    # $Results | select Name,mail*,recip*,Protected,Builtin
    $Results | sort Name | Export-Csv "$ResultsPath\ADGroup_$($Timestamp).csv" -NoTypeInformation -Verbose
}

function Get-CachedADGroups {
    Write-Verbose "Reading ADGroup info"
    # Uncomment line below to query AD, otherwise it uses cached results
    $Results = Import-Csv (ls $ResultsFolder\ADGroup* | sort -Descending Name | select -First 1).FullName
    Write-Verbose "Found $($Results.Count) groups"
}

Write-Output "`nMail-Enabled?"
$Results | Group-Object -Property MailEnabled -NoElement | select Name,Count | ft -Property @{Expression="   "},* -AutoSize -HideTableHeaders

Write-Output "`nGroup Category"
$Results | Group-Object -Property GroupCategory -NoElement | select Name,Count | ft -Property @{Expression="   "},* -AutoSize -HideTableHeaders

Write-Output "`nGroup Scope"
$Results | Group-Object -Property GroupScope -NoElement | select Name,Count | ft -Property @{Expression="   "},* -AutoSize -HideTableHeaders

Write-Output "`nMember Count"
$Results | Group-Object -Property Bucket -NoElement | select Name,Count | sort Name | ft -Property @{Expression="   "},* -AutoSize -HideTableHeaders

function Get-SecurityGroupsWithNoMembers() {
    $Results | ? { $_.MemberCount -eq 0 -and $_.MailEnabled -eq $false } # | select Name,MailEnabled,RecipientDisplayType,GroupCategory
}

function Get-DistributionListsWithNoMembers() {
    # This includes both distribution groups and mail-enabled security groups
    $Results | ? { $_.MemberCount -eq 0 -and $_.MailEnabled -eq $true } # | select Name,MailEnabled,RecipientDisplayType,GroupCategory
}

#Stop-Transcript