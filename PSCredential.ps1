﻿# Author: 	Hal Rottenberg <hal@halr9000.com>
# Url:		http://poshcode.org/5175
# Purpose:	These functions allow one to easily save network credentials to disk in a relatively
#			secure manner.  The resulting on-disk credential file can only [1] be decrypted
#			by the same user account which performed the encryption.  For more details, see
#			the help files for ConvertFrom-SecureString and ConvertTo-SecureString as well as
#			MSDN pages about Windows Data Protection API.
#			[1]: So far as I know today.  Next week I'm sure a script kiddie will break it.
#
# Usage:	Export-PSCredential [-Credential <PSCredential object>] [-Path <file to export>]
#
#			If Credential is not specififed, user is prompted by Get-Credential cmdlet.
#			If not specififed, Path is "./credentials.enc.xml".
#			Output: FileInfo object referring to saved credentials
#
#			Import-PSCredential [-Path <file to import>]
#
#			If not specififed, Path is "./credentials.enc.xml".
#			Output: PSCredential object

function Export-PSCredential {
	param ( $Credential = (Get-Credential), $Path = "credentials.enc.xml" )
	
	# Test for valid credential object
	if ( !$Credential -or ( $Credential -isnot [system.Management.Automation.PSCredential] ) ) {
		Throw "You must specify a credential object to export to disk."
	}
	
	# Create temporary object to be serialized to disk
	$export = "" | Select-Object Username, EncryptedPassword
	
	# Give object a type name which can be identified later
	$export.PSObject.TypeNames.Insert(0,’ExportedPSCredential’)
	
	$export.Username = $Credential.Username

	# Encrypt SecureString password using Data Protection API
	# Only the current user account can decrypt this cipher
	$export.EncryptedPassword = $Credential.Password | ConvertFrom-SecureString

	# Export using the Export-Clixml cmdlet
	$export | Export-Clixml $Path
	Write-Host -foregroundcolor Green "Credentials saved to: " -noNewLine

	# Return FileInfo object referring to saved credentials
	Get-Item $Path
}

function Import-PSCredential {
	param ( $Path = "credentials.enc.xml" )

	# Import credential file
	$import = Import-Clixml $Path 
	
	# Test for valid import
	if ( $import.PSObject.TypeNames -notcontains 'Deserialized.ExportedPSCredential' ) {
		Throw "Input is not a valid ExportedPSCredential object, exiting."
	}
	$Username = $import.Username
	
	# Decrypt the password and store as a SecureString object for safekeeping
	$SecurePass = $import.EncryptedPassword | ConvertTo-SecureString
	
	# Build the new credential object
	$Credential = New-Object System.Management.Automation.PSCredential $Username, $SecurePass
	Write-Output $Credential
}

function Get-Credential { 
   # .Synopsis
   #    Gets a credential object based on a user name and password.
   # .Description
   #    The Get-Credential function creates a credential object for a specified username and password, with an optional domain. You can use the credential object in security operations.
   # 
   #    This function is an improvement over the default Get-Credential cmdlet. It accepts more parameters to customize the security prompt (including forcing the call through the console) and also supports storing and retrieving credentials on disk, but otherwise functions identically to the built-in command
   # .Example
   #    Get-Credential -user key -pass secret -store | % { $_.GetNetworkCredential() } | fl *
   # 
   #    Demonstrates the ability to store passwords securely, and pass them in on the command line
   # .Example
   #    Get-Credential key
   # 
   #    If you haven't stored the password for "key", you'll be prompted with the regular PowerShell credential prompt, otherwise it will read the stored password and return credentials without prompting
   # .Example
   #    Get-Credential -inline
   #  
   #    Will prompt for credentials inline in the host instead of in a popup dialog
   #  .Notes
   #    History:
   #     v 2.9 Reformat to my new coding style...
   #     v 2.8 Refactor Encode-SecureString (and add unused Decode-SecureString for completeness)
   #     v 2.7 Fix double prompting issue when using -Inline 
   #           Use full typename for PSCredential to maintain V2 support - Thanks Joe Hayes
   #     v 2.6 Put back support for passing in the domain when getting credentials without prompting
   #     v 2.5 Added examples for the help
   #     v 2.4 Fix a bug in -Store when the UserName isn't passed in as a parameter
   #     v 2.3 Add -Store switch and support putting credentials into the file system
   #     v 2.1 Fix the comment help and parameter names to agree with each other (whoops)
   #     v 2.0 Rewrite for v2 to replace the default Get-Credential
   #     v 1.2 Refactor ShellIds key out to a variable, and wrap lines a bit
   #     v 1.1 Add -Console switch and set registry values accordingly (ouch)
   #     v 1.0 Add Title, Message, Domain, and UserName options to the Get-Credential cmdlet
   [CmdletBinding(DefaultParameterSetName="Prompted")]
   param(
      #   A default user name for the credential prompt, or a pre-existing credential (would skip all prompting)
      [Parameter(ParameterSetName="Prompted",Position=1,Mandatory=$false)]
      [Parameter(ParameterSetName="Promptless",Position=1,Mandatory=$true)]
      [Parameter(ParameterSetName="StoreCreds",Position=1,Mandatory=$true)]
      [Parameter(ParameterSetName="Flush",Position=1,Mandatory=$true)]
      [Alias("Credential")]
      [PSObject]$UserName=$null,

      #  Allows you to override the default window title of the credential dialog/prompt
      #
      #  You should use this to allow users to differentiate one credential prompt from another.  In particular, if you're prompting for, say, Twitter credentials, you should put "Twitter" in the title somewhere. If you're prompting for domain credentials. Being specific not only helps users differentiate and know what credentials to provide, but also allows tools like KeePass to automatically determine it.
      [Parameter(ParameterSetName="Prompted",Position=2,Mandatory=$false)]
      [string]$Title=$null,

      #  Allows you to override the text displayed inside the credential dialog/prompt.
      #  
      #  You can use this for things like presenting an explanation of what you need the credentials for.
      [Parameter(ParameterSetName="Prompted",Position=3,Mandatory=$false)]
      [string]$Message=$null,

      #  Specifies the default domain to use if the user doesn't provide one (by default, this is null)
      [Parameter(ParameterSetName="Prompted",Position=4,Mandatory=$false)]
      [Parameter(ParameterSetName="Promptless",Position=4,Mandatory=$false)]
      [string]$Domain=$null,

      #  The Get-Credential cmdlet forces you to always return DOMAIN credentials (so even if the user provides just a plain user name, it prepends "\" to the user name). This switch allows you to override that behavior and allow generic credentials without any domain name or the leading "\".
      [Parameter(ParameterSetName="Prompted",Mandatory=$false)]
      [switch]$GenericCredentials,

      #  Forces the credential prompt to occur inline in the console/host using Read-Host -AsSecureString (not implemented properly in PowerShell ISE)
      [Parameter(ParameterSetName="Prompted",Mandatory=$false)]
      [switch]$Inline,

      #  Store the credential in the file system (and overwrite them)
      [Parameter(ParameterSetName="Prompted",Mandatory=$false)]
      [Parameter(ParameterSetName="Promptless",Mandatory=$false)]
      [Parameter(ParameterSetName="StoreCreds",Mandatory=$true)]
      [switch]$Store,

      #  Remove stored credentials from the file system
      [Parameter(ParameterSetName="Prompted",Mandatory=$false)]
      [Parameter(ParameterSetName="Promptless",Mandatory=$false)]
      [Parameter(ParameterSetName="Flush",Mandatory=$true)]
      [switch]$Flush,

      #  Allows you to override the path to store credentials in
      [Parameter(ParameterSetName="Prompted",Mandatory=$false)]
      [Parameter(ParameterSetName="Promptless",Mandatory=$false)]
      [Parameter(ParameterSetName="StoreCreds",Mandatory=$false)]
      $CredentialFolder = $(Join-Path ${Env:APPDATA} Credentials),

      #  The password
      [Parameter(ParameterSetName="Promptless",Position=5,Mandatory=$true)]
      $Password = $(
      if($UserName -and (Test-Path "$(Join-Path $CredentialFolder $UserName).cred")) {
            if($Flush) {
               Remove-Item "$(Join-Path $CredentialFolder $UserName).cred"
            } else {
               Get-Content "$(Join-Path $CredentialFolder $UserName).cred" | ConvertTo-SecureString 
            }
      })
   )
   process {
      [Management.Automation.PSCredential]$Credential = $null
      if( $UserName -is [System.Management.Automation.PSCredential]) {
         $Credential = $UserName
      } elseif($UserName -ne $null) {
         $UserName = $UserName.ToString()
      }
      
      if($Password) {
         if($Password -isnot [System.Security.SecureString]) {
            $Password = Encode-SecureString $Password
         }
         if($Domain) {
            $Credential = New-Object System.Management.Automation.PSCredential ${Domain}\${UserName}, ${Password}
         } else {
            $Credential = New-Object System.Management.Automation.PSCredential ${UserName}, ${Password}
         }
      }
      
      if(!$Credential) {
         if($Inline) {
            if($Title)    { Write-Host $Title }
            if($Message)  { Write-Host $Message }
            if($Domain) { 
               if($UserName -and $UserName -notmatch "[@\\]") { 
                  $UserName = "${Domain}\${UserName}"
               }
            }
            if(!$UserName) {
               $UserName = Read-Host "User"
               if(($Domain -OR !$GenericCredentials) -and $UserName -notmatch "[@\\]") {
                  $UserName = "${Domain}\${UserName}"
               }
            }
            $Credential = New-Object System.Management.Automation.PSCredential $UserName,$(Read-Host "Password for user $UserName" -AsSecureString)
         } else {
            if($GenericCredentials) { $Type = "Generic" } else { $Type = "Domain" }
         
            ## Now call the Host.UI method ... if they don't have one, we'll die, yay.
            ## BugBug? PowerShell.exe (v2) disregards the last parameter
            $Credential = $Host.UI.PromptForCredential($Title, $Message, $UserName, $Domain, $Type, "Default")
         }
      }
      
      if($Store) {
         $CredentialFile = "$(Join-Path $CredentialFolder $Credential.GetNetworkCredential().UserName).cred"
         if(!(Test-Path $CredentialFolder)) {
            mkdir $CredentialFolder | out-null
         }
         $Credential.Password | ConvertFrom-SecureString | Set-Content $CredentialFile
      }
      return $Credential
   }
}

function Decode-SecureString {
   #.Synopsis
   #  Decodes a SecureString to a String
   [CmdletBinding()]
   [OutputType("System.String")]
   param(
      # The SecureString to decode
      [SecureString]$secure
   )
   end {
      if($secure -eq $null) { return "" }
      $BSTR = [System.Runtime.InteropServices.marshal]::SecureStringToBSTR($secure)
      Write-Output [System.Runtime.InteropServices.marshal]::PtrToStringAuto($BSTR)
      [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
   }
}

function Encode-SecureString {
   #.Synopsis
   #  Encodes a string as a SecureString (for this computer/user)
   [CmdletBinding()]
   [OutputType("System.Security.SecureString")]
   param(
      # The string to encode into a secure string
      [String]$String
   )
   end {
      [char[]]$Chars = $String.ToString().ToCharArray()
      $SecureString = New-Object System.Security.SecureString
      foreach($c in $chars) { $SecureString.AppendChar($c) }
      Write-Output $SecureString
   }
}
