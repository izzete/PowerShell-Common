
$Apps = @{}
$Apps.Add("Holds-Employees", (New-Object PSCustomObject -Property (
    @{
        ClientID = "test144"
        ClientSecret = "4Y35557Algpz8jyTfOWzWfjvwAHNbJqRaO0azkgg2O5H1h6kQB0R1WuWfdOB4Voe"
        AppID    = "8414194"
        AppToken = "7d29d7628d7248898f36a246c3aa50fd"
     }))
)

<#
.SYNOPSIS
   Get Podio access token
    
.DESCRIPTION
   Connects to Podio and returns access token

   Only the App & User authentication flows are supported

.EXAMPLE
    App authentication flow:

    $SomePodioApp = New-Object PSCustomObject -Property (@{
        ClientID = "xyz123"
        ClientSecret = "4Y35557Algpz8jyTfOWzWfjvwAHNbJqRaO0azkgg2O5H1h6kQB0R1WuWfdOB4Voe"
        AppID    = "8414194"
        AppToken = "7d29d7628d7248898f36a246c3aa50fd"
    })

    $SomePodioApp | Get-PodioAccessToken
    
.NOTES
   2014-06-25   IZZETE   Initial version
#>
function Get-PodioAccessToken
{
    [CmdletBinding()]
#    [OutputType([int])]
    Param
    (
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        $ClientID,

        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=1)]
        $ClientSecret,

        [Parameter(Mandatory=$true,
                   ParameterSetName="AppAuth",
                   ValueFromPipelineByPropertyName=$true,
                   Position=2)]
        $AppID,

        [Parameter(Mandatory=$true,
                   ParameterSetName="AppAuth",
                   ValueFromPipelineByPropertyName=$true,
                   Position=3)]
        $AppToken,

        [Parameter(Mandatory=$true,
                   ParameterSetName="PwdAuth",
                   ValueFromPipelineByPropertyName=$true,
                   Position=2)]
        [PSCredential] $Credential
    )

    begin
    {
        $RequestURL  = "https://podio.com/oauth/token"
    }

    process
    {
        Write-Debug "Get-PodioAccessToken called"

        if ($AppID)
        {
            # Performing application auth flow
            $RequestBody = "grant_type=app&app_id=YOUR_PODIO_APP_ID&app_token=YOUR_PODIO_APP_TOKEN&client_id=YOUR_CLIENT_ID&redirect_uri=YOUR_URL&client_secret=YOUR_CLIENT_SECRET"
            $RequestBody = $RequestBody -replace "YOUR_URL", ""
            $RequestBody = $RequestBody -replace "YOUR_CLIENT_ID", $ClientID
            $RequestBody = $RequestBody -replace "YOUR_CLIENT_SECRET", $ClientSecret
            $RequestBody = $RequestBody -replace "YOUR_PODIO_APP_ID", $AppID
            $RequestBody = $RequestBody -replace "YOUR_PODIO_APP_TOKEN", $AppToken
        }
        else
        {
            # Performing username and password auth flow
            $RequestBody = "grant_type=password&username=YOUR_USERNAME&password=YOUR_PASSWORD&client_id=YOUR_CLIENT_ID&redirect_uri=YOUR_URL&client_secret=YOUR_CLIENT_SECRET"
            $RequestBody = $RequestBody -replace "YOUR_URL", ""
            $RequestBody = $RequestBody -replace "YOUR_CLIENT_ID", $ClientID
            $RequestBody = $RequestBody -replace "YOUR_CLIENT_SECRET", $ClientSecret
            $RequestBody = $RequestBody -replace "YOUR_USERNAME", $Credential.UserName
            $RequestBody = $RequestBody -replace "YOUR_PASSWORD", $Credential.GetNetworkCredential().Password
        }

        Write-Debug "   URL  = $RequestURL"
        Write-Debug "   Body = $RequestBody"

        try
        {
            $Token = Invoke-RestMethod -Uri $RequestURL -Body $RequestBody -Method Post -SessionVariable Session
            $Session.Headers.Add("Authorization", "OAuth2 $($Token.access_token)")
            return New-Object PSCustomObject -Property ([ordered]@{
                        Token   = $Token
                        Session = $Session
                        Expires = (Get-Date).AddSeconds($Token.expires_in)
                        AppID        = $AppID
                        ClientID     = $ClientID
                        ClientSecret = ConvertTo-SecureString $ClientSecret -AsPlainText -Force
                   })
        }
        catch
        {
            Write-Error "Error retrieving access token: $_"
            return $null
        }
    }

    end
    {
    }
}


<#
.SYNOPSIS
   Invalidate Podio access token
    
.DESCRIPTION
   Invalidates all tokens for the currently logged in user. Useful for testing OAuth token refresh.

   Only the App  authentication flow is supported.

.EXAMPLE
    Invalidate-PodioAccessToken -PodioAccessToken $token

    Note: $token must be object returned by Get-PodioAccessToken
    
.NOTES
   2014-06-25   IZZETE   Initial version. Doesn't seem to work; Podio always returns invalid_request error.
#>
function Invalidate-PodioAccessToken
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true,
                   Position=0)]
        $PodioAccessToken
    )
   
    Write-Debug "Invalidate-PodioAccessToken called"
    
    $RequestURL  = "https://podio.com/oauth/token/invalidate"
    $RequestBody = ""
    $AccessToken = $PodioAccessToken.Token.access_token
    $Session     = $PodioAccessToken.Session

    Write-Debug "   URL  = $RequestURL"
    Write-Debug "   Body = $RequestBody"
    Write-Debug "   Access Token = $AccessToken"
    Write-Debug "   Session = `n$($Session | Out-String)"

    try
    {
        Invoke-RestMethod -Uri $RequestURL -Body $RequestBody -Method Post -WebSession $Session
#        return $Token
    }
    catch
    {
        if ($Error[0] -match "error_description")
        {
            Write-Error "Error invalidating access token: `n$(ConvertFrom-Json $_ | Out-String)"
        }
        else
        {
            Write-Error "Error invalidating access token: $_"
        }
    }
}


<#
.SYNOPSIS
    Refresh Podio access token
    
.DESCRIPTION
    Request a new Podio access token using the refresh_token of an existing token

    NOTE: Hangs...not ready for prime time.

.EXAMPLE
    Refresh-PodioAccessToken $token

    Note: $token must be object returned by Get-PodioAccessToken
    
.NOTES
   2014-06-25   IZZETE   Initial version. 
#>
function Refresh-PodioAccessToken
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true,
                   Position=0)]
        $PodioAccessToken
    )
   
    Write-Debug "Update-PodioAccessToken called"
    
    $RequestURL  = "https://podio.com/oauth/token"
    $RequestBody = "grant_type=refresh_token&client_id=YOUR_CLIENT_ID&client_secret=YOUR_CLIENT_SECRET&refresh_token=YOUR_REFRESH_TOKEN"
    $AccessToken = $PodioAccessToken.Token.access_token
    $RefreshToken= $PodioAccessToken.Token.refresh_token
    $ClientID    = $PodioAccessToken.ClientID
    $ClientSecret= Decrypt-SecureString $PodioAccessToken.ClientSecret
    $Session     = $PodioAccessToken.Session

    $RequestBody = $RequestBody -replace "YOUR_CLIENT_ID", $ClientID
    $RequestBody = $RequestBody -replace "YOUR_CLIENT_SECRET", $ClientSecret
    $RequestBody = $RequestBody -replace "YOUR_REFRESH_TOKEN", $RefreshToken

    Write-Debug "   URL  = $RequestURL"
    Write-Debug "   Body = $RequestBody"
#    Write-Debug "   Access Token = $AccessToken"
    Write-Debug "   Refresh Token= $RefreshToken"
    Write-Debug "   Session = `n$($Session | Out-String)"

    try
    {
        #$Session.Headers.Clear()
        $Token = Invoke-RestMethod -Uri $RequestURL -Body $RequestBody -Method Post -WebSession $Session
        $PodioAccessToken.Token = $Token
        #$PodioAccessToken.Session.Headers.Add("Authorization", "OAuth2 $($Token.access_token)")
        return $PodioAccessToken
    }
    catch
    {
        if ($Error[0] -match "error_description")
        {
            Write-Error "Error updating access token: `n$(ConvertFrom-Json $_ | Out-String)"
        }
        else
        {
            Write-Error "Error updating access token: $_"
        }
    }
}


<#
.SYNOPSIS
    Get all views for a given Podio app
    
.DESCRIPTION
    Get all views for a given Podio app

    Requires app authentication

.EXAMPLE
    Get-PodioViews $token

    Note: $token must be object returned by Get-PodioAccessToken
    
.NOTES
   2014-06-25   IZZETE   Initial version. 
#>
function Get-PodioViews
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true,
                   Position=0)]
        $PodioAccessToken
    )
   
    Write-Debug "Get-PodioViews called"
    
    $RequestURL = "https://api.podio.com/view/app/{app_id}/?include_standard_views={inc_std_views}"
    $AppID      = $PodioAccessToken.AppID
    $Session    = $PodioAccessToken.Session

    $RequestURL = $RequestURL -replace "{app_id}", $AppID
    $RequestURL = $RequestURL -replace "{inc_std_views}", "false"

    Write-Debug "   URL  = $RequestURL"
    Write-Debug "   Session = `n$($Session | Out-String)"

    try
    {
        $Result = Invoke-RestMethod -Uri $RequestURL -Method Get -WebSession $Session
        return $Result
    }
    catch
    {
        if ($Error[0] -match "error_description")
        {
            Write-Error "Error getting views: `n$(ConvertFrom-Json $_ | Out-String)"
        }
        else
        {
            Write-Error "Error getting views: $_"
        }
    }
}


<#
.SYNOPSIS
    Get details for a given Podio view
    
.DESCRIPTION
    Get details for a given Podio view

    Requires app authentication

.EXAMPLE
    Get-PodioViewDetails $token $viewid

    Note: $token must be object returned by Get-PodioAccessToken
    
.NOTES
   2014-07-01   IZZETE   Initial version. 
#>
function Get-PodioViewDetails
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true,
                   Position=0)]
        $PodioAccessToken,

        [Parameter(Mandatory=$true,
                   Position=1)]
        $ViewID
    )
   
    Write-Debug "Get-PodioViewDetails called"
    
    $RequestURL = "https://api.podio.com/view/app/{app_id}/{view_id}"
    $AppID      = $PodioAccessToken.AppID
    $Session    = $PodioAccessToken.Session

    $RequestURL = $RequestURL -replace "{app_id}", $AppID
    $RequestURL = $RequestURL -replace "{view_id}", $ViewID

    Write-Debug "   URL  = $RequestURL"
    Write-Debug "   Session = `n$($Session | Out-String)"

    try
    {
        $Result = Invoke-RestMethod -Uri $RequestURL -Method Get -WebSession $Session
        return $Result
    }
    catch
    {
        if ($Error[0] -match "error_description")
        {
            Write-Error "Error getting view details: `n$(ConvertFrom-Json $_ | Out-String)"
        }
        else
        {
            Write-Error "Error getting view details: $_"
        }
    }
}


<#
.SYNOPSIS
   Converts encrypted string to plaintext

.DESCRIPTION
   Converts secure string created by ConvertTo-SecureString into plaintext

.EXAMPLE
   Decrypt-SecureString $securestring

.NOTES
   2014-06-25   IZZETE   Initial version. 
#>
function Decrypt-SecureString
{
    [CmdletBinding()]
    [OutputType([string])]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory=$true,
                   Position=0)]
        [SecureString] $SecureString
    )

    $Credential = New-Object System.Management.Automation.PSCredential -ArgumentList "lola", $SecureString
    return $Credential.GetNetworkCredential().Password 
}


<#
$Employees = New-Object PSCustomObject -Property (@{
    ClientID = "test144"
    ClientSecret = "4Y35557Algpz8jyTfOWzWfjvwAHNbJqRaO0azkgg2O5H1h6kQB0R1WuWfdOB4Voe"
    AppID    = "8414194"
    AppToken = "7d29d7628d7248898f36a246c3aa50fd"
})

$Izzy = New-Object PSCustomObject -Property (@{
    ClientID = "test144"
    ClientSecret = "4Y35557Algpz8jyTfOWzWfjvwAHNbJqRaO0azkgg2O5H1h6kQB0R1WuWfdOB4Voe"
    User    = "izzet.ergas@citrix.com"
    Password = ""
})

$BlankPwd = New-Object PSCustomObject -Property (@{
    ClientID = "test144"
    ClientSecret = "4Y35557Algpz8jyTfOWzWfjvwAHNbJqRaO0azkgg2O5H1h6kQB0R1WuWfdOB4Voe"
    Password = ""
})
#>

