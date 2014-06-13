$json1 = @"
[
  {"type": "user",     "id": 3},
  {"type": "profile",  "id": 123456},
  {"type": "mail",     "id": "example@example.com"},
  {"type": "space",    "id": 123456},
  {"type": "external", "id": {"linked_account_id": 123, "external_contact_id": "my_ext_id"}}
]
"@

$x = ConvertFrom-Json $json1


#######


$ClientID     = "test144"
$ClientSecret = "4Y35557Algpz8jyTfOWzWfjvwAHNbJqRaO0azkgg2O5H1h6kQB0R1WuWfdOB4Voe"
$EmployeesAppID    = "8414194"
$EmployeesAppToken = "7d29d7628d7248898f36a246c3aa50fd"

$RequestBody = "grant_type=app&app_id=YOUR_PODIO_APP_ID&app_token=YOUR_PODIO_APP_TOKEN&client_id=YOUR_CLIENT_ID&redirect_uri=YOUR_URL&client_secret=YOUR_CLIENT_SECRET"


$RequestBody = $RequestBody -replace "YOUR_URL", ""
$RequestBody = $RequestBody -replace "YOUR_CLIENT_ID", $ClientID
$RequestBody = $RequestBody -replace "YOUR_CLIENT_SECRET", $ClientSecret
$RequestBody = $RequestBody -replace "YOUR_PODIO_APP_ID", $EmployeesAppID
$RequestBody = $RequestBody -replace "YOUR_PODIO_APP_TOKEN", $EmployeesAppToken


$AppAuthURL = "https://podio.com/oauth/token"
$AppAuthToken = Invoke-RestMethod -Uri $AppAuthURL -Body $RequestBody -Method Post -SessionVariable AppAuthSession
$AppAuthSession.Headers.Add("Authorization", "OAuth2 $($AppAuthToken.access_token)")




##############


$URL = "https://api.podio.com/file/app/{app_id}/?limit=20&offset=0&sort_by=name&sort_desc=false"
$URL = $URL -replace "{app_id}", $EmployeesAppID

Invoke-RestMethod -Uri $URL -Method Get -WebSession $AppAuthSession

##############


$URL = "https://api.podio.com/item/app/{app_id}/filter/"
$URL = $URL -replace "{app_id}", $EmployeesAppID
$RequestBody = @"
{
  "sort_by": created_on,
  "sort_desc": false,
  "filters": The filters to apply
  {
    "{key}": The value for the key filtering,
    ... (more filters)
  },
  "limit": 1,
  "offset": 0,
  "remember": false
}
"@

Invoke-RestMethod -Uri $URL -Method Get -WebSession $AppAuthSession