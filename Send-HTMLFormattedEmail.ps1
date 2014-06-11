function Send-HTMLFormattedEmail {
	<# 
	.SYNOPSIS
    	Sends an HTML formatted e-mail that is based on an XSLT template

    .DESCRIPTION
    	Sends an HTML formatted e-mail that is based on an XSLT template

	.PARAMETER To
		Email address or addresses for whom the message is being sent to

		Addresses should be seperated using semi-colon (';')

	.PARAMETER ToDisName
		Display name for whom the message is being sent to

	.PARAMETER CC
		Email address if you want CC a recipient.
		Addresses should be seperated using semi-colon (';')

	.PARAMETER BCC
		Email address if you want BCC a recipient.
		Addresses should be seperated using semi-colon (';')

	.PARAMETER From
		Email address for whom the message comes from

#	.Parameter FromDisName
#		Display name for whom the message comes from

	.PARAMETER Subject
		The subject line for the message

	.PARAMETER XSLPath
		The full path to the XSL template that is to be used

	.PARAMETER Content
		The content of the message (to be inserted into the XSL Template)

	.PARAMETER Relay
		FQDN or IP of the SMTP relay to send the message using

        Defaults to mail.citrix.com on port 25

    .NOTES
        Based on script downloaded from http://poshcode.org/1035

        2014-06-11  IZZETE  Initial version
	#>
    param(
		[Parameter(Mandatory=$True)]
        [String] $To,

		[Parameter(Mandatory=$True)]
        [String] $ToDisName,

		[String] $CC,

		[String] $BCC,

		[Parameter(Mandatory=$True)]
        [String] $From,

		[Parameter(Mandatory=$True)]
        [String] $FromDisName,

		[Parameter(Mandatory=$True)]
        [String] $Subject,

		[Parameter(Mandatory=$True)]
        [String] $Content,

		[Parameter(Mandatory=$True)]
        [String] $Relay,

		[Parameter(Mandatory=$True)]
        [String]$XSLPath,

		[Boolean]$Async = $false
    )
    
    try {

        Write-Debug "$(Get-Date -Format r) [Send-HTMLFormattedEmail] Starting"

        # Load XSL Argument List
        $XSLArg = New-Object System.Xml.Xsl.XsltArgumentList
        $XSLArg.Clear() 
        $XSLArg.AddParam("To", $Null, $ToDisName)
        $XSLArg.AddParam("Content", $Null, $Content)

        # Load Documents
        $BaseXMLDoc = New-Object System.Xml.XmlDocument
        $BaseXMLDoc.LoadXml("<root/>")

        $XSLTrans = New-Object System.Xml.Xsl.XslCompiledTransform
        $XSLTrans.Load($XSLPath)

        #Perform XSL Transform
        $FinalXMLDoc = New-Object System.Xml.XmlDocument
        $MemStream = New-Object System.IO.MemoryStream
     
        $XMLWriter = [System.Xml.XmlWriter]::Create($MemStream)
        $XSLTrans.Transform($BaseXMLDoc, $XSLArg, $XMLWriter)

        $XMLWriter.Flush()
        $MemStream.Position = 0

        Write-Debug "$(Get-Date -Format r) [Send-HTMLFormattedEmail] XML transform complete"
     
        # Load the results
        $FinalXMLDoc.Load($MemStream) 
        $Body = $FinalXMLDoc.Get_OuterXML()

		# Create Message Object
        $Message = New-Object System.Net.Mail.MailMessage
		
		# Now Populate the Message Object.
        $Message.Subject = $Subject
        $Message.Body = $Body
        $Message.IsBodyHTML = $True
		
		# Add From
        $MessFrom = New-Object System.Net.Mail.MailAddress $From, $FromDisName
		$Message.From = $MessFrom

		# Add To
		$To = $To.Split(";") # Make an array of addresses.
		$To | foreach {$Message.To.Add((New-Object System.Net.Mail.Mailaddress $_.Trim()))} # Add them to the message object.
		
		# Add CC
		if ($CC){
			$CC = $CC.Split(";") # Make an array of addresses.
			$CC | foreach {$Message.CC.Add((New-Object System.Net.Mail.Mailaddress $_.Trim()))} # Add them to the message object.
			}

		# Add BCC
		if ($BCC){
			$BCC = $BCC.Split(";") # Make an array of addresses.
			$BCC | foreach {$Message.BCC.Add((New-Object System.Net.Mail.Mailaddress $_.Trim()))} # Add them to the message object.
			}

        Write-Debug "$(Get-Date -Format r) [Send-HTMLFormattedEmail] Message object created"
     
        # Create SMTP Client
        $Client = New-Object System.Net.Mail.SmtpClient $Relay

        Write-Debug "$(Get-Date -Format r) [Send-HTMLFormattedEmail] SMTP client object created"

        # Send The Message
        if ($Async) {
            $Client.SendAsync($Message,$null)
        }
        else {
            $Client.Send($Message)
        }
        Write-Verbose "$(Get-Date -Format r) [Send-HTMLFormattedEmail] E-mail sent to $To"

        }  
    catch {
		throw $_
        }   
    }

##################################################
# Main
##################################################
#Export-ModuleMember Send-HTMLFormattedEmail

