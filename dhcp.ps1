param(
    [int]$Port = 67
)

function CheckPortInUse {
    param (
        [int]$PortNumber
    )

    $output = netstat -aon | FindStr ":$PortNumber"
    if ($output) {
        $processId = ($output -split '\s+')[-1]
        $process = Get-Process -Id $processId -ErrorAction SilentlyContinue
        return $process
    }

    return $null
}

function ParseDHCPMessage {
    param (
        [byte[]]$messageBytes
    )

    if ($messageBytes.Length -lt 34) {
        Write-Host "Invalid DHCP message length."
        return
    }

    $macAddressBytes = $messageBytes[28..33]
    $macAddress = ($macAddressBytes | ForEach-Object { $_.ToString("X2") }) -join ":"

    return @{
        MacAddress = $macAddress
    }
}

$process = CheckPortInUse -PortNumber $Port
if ($process) {
    Write-Host "Port $Port is already in use by process $($process.ProcessName) (PID: $($process.Id)). Please choose a different port or close the conflicting process."
    exit
}

$udpClient = New-Object System.Net.Sockets.UdpClient($Port)
$endpoint = New-Object System.Net.IPEndPoint ([System.Net.IPAddress]::Any, $Port)

Write-Host "Listening for DHCP messages on port $Port..."

# Define clean-up function that will be called when the script is stopped
function CleanUp {
    Write-Host "Closing UDP client and releasing port $Port..."
    $udpClient.Close()
}

# Catch script termination event and call the clean-up function
trap {
    CleanUp
    break
}

while ($true) {
    do {
        try {
            $receivedBytes = $udpClient.Receive([ref]$endpoint)
            $errorOccured = $false
        } catch {
            Write-Host "Error receiving DHCP message. Retrying..."
            $errorOccured = $true
            Start-Sleep -Seconds 1
        }
    } while ($errorOccured)

    $dhcpMessage = ParseDHCPMessage -messageBytes $receivedBytes

    if ($dhcpMessage) {
        Write-Host "Received a DHCP message from $($dhcpMessage.MacAddress)"
    }
}
