<?xml version="1.0"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
 
<xsl:output media-type="xml" omit-xml-declaration="yes" />
    <xsl:param name="To"/>
    <xsl:param name="Content"/>
    <xsl:template match="/">
        <html>
            <head>
                <title>My First Formatted Email</title>
            </head>
            <body>
            <div width="400px">
                <p>Dear <xsl:value-of select="$To" />,</p>
                <p></p>
                <p><xsl:value-of select="$Content" /></p>
                <p></p>
				<p><strong>Please do not respond to this email!</strong><br />
					An automated system sent this email, if any point you have any questions or concerns please open a help desk ticket.</p>
				<p></p>
            <Address>
			Many thanks from your:<br />	
            Really Cool IT Team<br />
            </Address>
        </div>
      </body>
    </html>
    </xsl:template> 
</xsl:stylesheet>
