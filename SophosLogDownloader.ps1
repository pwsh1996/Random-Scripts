<#
.SYNOPSIS
  Pull the last 24 hours of SIEM events from Sophos Central.

.PARAMETER ClientId
  Your OAuth2 client ID from Sophos Central API credentials.

.PARAMETER ClientSecret
  Your OAuth2 client secret from Sophos Central API credentials.

.EXAMPLE
  .\Get-SophosSiemEvents.ps1 -ClientId 'abc123' -ClientSecret 'shhh!'
#>

param(
  [Parameter(Mandatory=$true)]
  [string]$ClientId,

  [Parameter(Mandatory=$true)]
  [string]$ClientSecret
)

# === 1) Authenticate ===

$tokenResp = Invoke-RestMethod -Method Post `
    -Uri 'https://id.sophos.com/api/v2/oauth2/token' `
    -ContentType 'application/x-www-form-urlencoded' `
    -Body @{
        grant_type    = 'client_credentials'
        client_id     = $ClientId
        client_secret = $ClientSecret
        scope         = 'token'
    }

$BearerToken = $tokenResp.access_token


# === 2) WhoAmI → get Tenant ID & API Host ===

$whoami = Invoke-RestMethod -Method Get `
    -Uri 'https://api.central.sophos.com/whoami/v1' `
    -Headers @{ Authorization = "Bearer $BearerToken" }

$OrgId   = $whoami.id
$ApiHost = $whoami.apiHosts.dataRegion.TrimEnd('/')

Write-Host "Using Tenant ID: $OrgId" -ForegroundColor Cyan
Write-Host "API Host: $ApiHost" -ForegroundColor Cyan


# === 3) Pull one max-size page of SIEM events ===

$limit   = 1000
$url     = "$ApiHost/siem/v1/events?limit=$limit"

Write-Host "Requesting up to $limit events: $url" -ForegroundColor Yellow

$eventsPage = Invoke-RestMethod -Method Get -Uri $url `
    -Headers @{
        Authorization = "Bearer $BearerToken"
        'X-Tenant-ID' = $OrgId
        Accept        = 'application/json'
    }

# === 4) Output / Process ===

$outFile = "SIEM_Events_Last24h_$(Get-Date -Format yyyyMMdd).json"
$eventsPage | ConvertTo-Json -Depth 6 | Out-File $outFile -Encoding UTF8

Write-Host "Wrote $($eventsPage.items.Count) events to $outFile" -ForegroundColor Green
