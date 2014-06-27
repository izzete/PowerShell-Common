<#
.SYNOPSIS
   Returns all Citrix offices worldwide

.DESCRIPTION
   Queries web service maintained by Michael Berry
   URL: http://autosvcdata.citrite.net/dataMgmt.svc?wsdl
   
.EXAMPLE
   Get-CtxOffices

.INPUTS
   None

.OUTPUTS
   Custom PSObject with the following properties

   City        : North Ryde
   Country     : Australia
   CountryCode : AU
   GoogleMap   : http://goo.gl/maps/EcRJI
   Postal      : 2113
   Record      : 2
   StateProv   : NSW
   Street      : Level 3, 1 Julius Avenue Riverside Corporate Park

.NOTES
   2014-06-24   IZZETE   Initial version
#>
function Get-CtxOffices
{
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    Param()

    try
    {
        $wsProxy = New-WebServiceProxy -Uri "http://autosvcdata.citrite.net/dataMgmt.svc?wsdl"
        $result  = $wsProxy.getOffices()
        if ($result.HasError)
        {
            throw $result.errormessage
        }
        else
        {
            $data = $result | ConvertFrom-Json
            $data
        } 
    }
    catch 
    {
        Write-Error "Exception encountered: `n" $error
    }
}