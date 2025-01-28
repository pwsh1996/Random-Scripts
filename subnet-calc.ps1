<#
 Declaring script parameters
 IP address parameter is mandatory and validated with a regex pattern
 CIDR notation parameter is also mandatory and it's a number between 1 to 32
#>
param(
    [Parameter(Mandatory=$true)]
    [string]
    [ValidatePattern("^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$")]
    $IPAddress,

    [Parameter(Mandatory=$true)]
    [ValidateRange(1,32)]
    [int]
    $CIDR
)

function Check-IPType {
    param(
        [string] $ip
    )
    
    $firstOctet = $ip.Split('.')[0]
    
    if ((10 -eq $firstOctet) -or ((172 -le $firstOctet) -and (31 -ge $firstOctet)) -or ((192 -eq $firstOctet) -and (168 -eq $ip.Split('.')[1]))) {
        return "Private"
    } else {
        return "Public"
    }
}

$subnetBinary = "".PadLeft($CIDR, '1').PadRight(32, '0')
$subnetMaskParts = @()

for($i = 0; $i -lt 4; $i++) {
    $subnetMaskParts += [convert]::ToInt32($subnetBinary.Substring($i*8, 8), 2)
}

$subnetMask = [string]::Join(".", $subnetMaskParts)

$ipParts = $IPAddress.Split('.')
$maskParts = $subnetMask.Split('.')
$networkParts = @()
$broadcastParts = @()

for($i=0; $i -lt 4; $i++){
    $networkParts += ([int]$ipParts[$i] -band [int]$maskParts[$i])
}

$networkAddress = [string]::Join(".", $networkParts)

$inverseMaskParts = $maskParts | ForEach-Object { 255 - $_ }

for($i=0; $i -lt 4; $i++){
    $broadcastParts += ([int]$networkParts[$i] -bor [int]$inverseMaskParts[$i])
}

$broadcastAddress = [string]::Join(".", $broadcastParts)

<#
 Compute total number of hosts possible for the given subnet mask
 Subtract 2 from total hosts for network and broadcast addresses to get usable hosts
#>
$totalHosts = [math]::Pow(2, (32 - $CIDR)) 
$usableHosts = $totalHosts - 2

$ipType = Check-IPType -ip $IPAddress

<#
 Displaying the output to console
 The output consists of the input IP address, type of the IP address (Public/Private), Subnet mask, Network address, Broadcast address, Total number of possible hosts and Total number of usable hosts
 PSStyle is used to alter the colors of the displayed output in the console for easy readability
#>
write-host "IP Address:                   $IPAddress $($PSStyle.Reset)"-BackgroundColor Gray -ForegroundColor black
write-host "IP Type:                      $ipType $($PSStyle.Reset)"-BackgroundColor Black -ForegroundColor gray
write-host "Subnet Mask:                  $subnetMask $($PSStyle.Reset)" -BackgroundColor Gray -ForegroundColor black
write-host "Network Address:              $networkAddress $($PSStyle.Reset)" -BackgroundColor Black -ForegroundColor gray
write-host "Broadcast Address:            $broadcastAddress $($PSStyle.Reset)" -BackgroundColor Gray -ForegroundColor black
write-host "Total Number of Hosts:        $totalHosts $($PSStyle.Reset)" -BackgroundColor Black -ForegroundColor gray
write-host "Total Number of Usable Hosts: $usableHosts $($PSStyle.Reset)" -BackgroundColor Gray -ForegroundColor black
