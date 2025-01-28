<#
.SYNOPSIS
    A tool to send ICMP messages natively in Windows
.DESCRIPTION
    Created by Jacob Petrie, AI assisted, 5/2/23
#>

#requires -version 5.1
#requires -RunAsAdministrator

[CmdletBinding()]
param(
    $destination = "194.195.219.225",
    [switch]$TimestampRequest,
    [switch]$EchoRequest
)

class ICMP {
    [System.Net.Sockets.Socket]$socket

    ICMP() {
        $this.socket = New-Object System.Net.Sockets.Socket -ArgumentList @([System.Net.Sockets.SocketType]::Raw, [System.Net.Sockets.ProtocolType]::Icmp)
    }

    # Method to create an ICMP timestamp request packet.
    [byte[]] BuildICMPTimestampPacket() {
        #    0                   1                   2                   3
        #    0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
        #   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
        #   |     Type      |      Code     |          Checksum             |
        #   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
        #   |           Identifier          |        Sequence Number        |
        #   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
        #   |     Originate Timestamp                                       |
        #   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
        #   |     Receive Timestamp                                         |
        #   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
        #   |     Transmit Timestamp                                        |
        #   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

        # Create a 20-byte ICMP timestamp request packet according to RFC 792.
        $packet = New-Object byte[] 20


        $packet[0] = 13 # Type field to 13 for ICMP timestamp request.
        $packet[1] = 0 # Code field to 0.

        # Checksum field to 0 initially.
        $packet[2] = 0
        $packet[3] = 0

        # Identifier field to 0.
        $packet[4] = 0
        $packet[5] = 0

        # Sequence Number field to 0.
        $packet[6] = 0
        $packet[7] = 0

        # Set the Originate Timestamp field to the current time since midnight UTC in milliseconds.
        $currentUtcTime = [System.DateTime]::UtcNow
        $midnightUtcTime = [System.DateTime]::new($currentUtcTime.Year, $currentUtcTime.Month, $currentUtcTime.Day, 0, 0, 0, [System.DateTimeKind]::Utc)
        $millisecondsSinceMidnight = $currentUtcTime.Subtract($midnightUtcTime).TotalMilliseconds
        $origTimestampBytes = [BitConverter]::GetBytes([System.Convert]::ToUInt32($millisecondsSinceMidnight))
        $packet[8] = $origTimestampBytes[0]
        $packet[9] = $origTimestampBytes[1]
        $packet[10] = $origTimestampBytes[2]
        $packet[11] = $origTimestampBytes[3]

        # Calculate and set the Checksum field.
        $checksum = $this.CalculateChecksum($packet)
        $packet[2] = $checksum[0]
        $packet[3] = $checksum[1]

        return $packet
    }

    # Method to handle an ICMP timestamp reply.
    [psobject] HandleICMPTimestampReply([byte[]]$receiveBuffer) {
        # Check if the received packet is an ICMP timestamp reply (Type field = 14).
        if ($receiveBuffer[20] -eq 14) {
            # Extract the Originate, Receive, and Transmit Timestamp fields.
            $origTimestamp = [BitConverter]::ToUInt32($receiveBuffer, 28)
            $recvTimestamp = [BitConverter]::ToUInt32($receiveBuffer, 32)
            $transTimestamp = [BitConverter]::ToUInt32($receiveBuffer, 36)

            # Create a result object with the extracted timestamp values and a success flag.
            $result = New-Object -TypeName PSObject -Property @{
                OriginalTimestamp = $origTimestamp
                ReceiveTimestamp  = $recvTimestamp
                TransmitTimestamp = $transTimestamp
                Success           = $true
            }

            return $result
        }
        else {
            Write-Host "Received a response, but not a timestamp reply."
        }

        return New-Object -TypeName PSObject -Property @{
            Success = $false
        }
    }

    # Method to create an ICMP echo request packet.
    [byte[]] BuildICMPEchoPacket() {
        #    0                   1                   2                   3
        #    0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
        #   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
        #   |     Type      |     Code      |          Checksum             |
        #   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
        #   |           Identifier          |        Sequence Number        |
        #   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
        #   |     Data ...
        #   +-+-+-+-+-

        # Create an 8-byte ICMP echo request packet according to RFC 792.
        # in Windows this is 40 bytes
        # in Linux this is 64 bytes
        $packet = New-Object byte[] 8

        
        $packet[0] = 8 # Type field to 8 for ICMP echo request.
        $packet[1] = 0 # Code field to 0.

        # Checksum field to 0 initially.
        $packet[2] = 0
        $packet[3] = 0

        # Identifier field
        # in Windows the default is (0x0001)
        $packet[4] = 0
        $packet[5] = 1

        # Sequence Number field
        # in Windows this number increments each time till the system is rebooted
        # in Linux this number increments till the ping command is stopped then next time it's run it starts again starting at (0x0001)
        $packet[6] = 0
        $packet[7] = 1

        # Calculate and set the Checksum field.
        $checksum = $this.CalculateChecksum($packet)
        $packet[2] = $checksum[0]
        $packet[3] = $checksum[1]

        # Data Field
        # in Windows this is a 32 byte field that contains (0x6162636465666768696a6b6c6d6e6f7071727374757677616263646566676869) and if you are using the `ping -l` to send any other size, it will repeate from 61 to 77
        # in Linux this is a 48 byte field that contains (0x32130b0000000000101112131415161718191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f3031323334353637)
        return $packet
    }

    # Method to handle an ICMP echo reply.
    [psobject] HandleICMPEchoReply([byte[]]$receiveBuffer) {
        # Check if the received packet is an ICMP echo reply (Type field = 0).
        if ($receiveBuffer[20] -eq 0) {
            # Extract the Identifier and Sequence Number fields.
            $identifier = [BitConverter]::ToUInt16($receiveBuffer, 25)
            $sequenceNumber = [BitConverter]::ToUInt16($receiveBuffer, 27)

            # Create a result object with the extracted values and a success flag.
            $result = New-Object -TypeName PSObject -Property @{
                Identifier     = $identifier
                SequenceNumber = $sequenceNumber
                Success        = $true
            }

            return $result
        }
        else {
            Write-Host "Received a response, but not an echo reply."
        }

        return New-Object -TypeName PSObject -Property @{
            Success = $false
        }
    }

    [byte[]] CalculateChecksum([byte[]]$data) {
        $sum = 0
        $i = 0
    
        # Loop through the data, processing 2 bytes at a time
        while ($i -lt $data.Length - 1) {
            # Add the 16-bit integer value from the data to the sum
            $sum += [BitConverter]::ToUInt16($data, $i)
    
            # Increment the index by 2 to process the next 2 bytes
            $i += 2
        }
    
        # Add any potential carry-over (higher 16 bits) back to the lower 16 bits
        $sum = ($sum -shr 16) + ($sum -band 0xFFFF)
    
        # Add any remaining carry-over
        $sum += $sum -shr 16
    
        # Calculate the one's complement of the sum and mask it with 0xFFFF
        $checksum = -bnot $sum -band 0xFFFF
    
        # Return the checksum as a 2-byte array
        return [BitConverter]::GetBytes([UInt16]$checksum)
    }
    
    [System.Net.IPEndPoint] CreateEndPoint([string]$destination) {
        $ipAddress = $null
        if ([System.Net.IPAddress]::TryParse($destination, [ref]$ipAddress)) {
            return New-Object System.Net.IPEndPoint -ArgumentList $ipAddress, 0
        }
        else {
            $ipAddress = [System.Net.Dns]::GetHostAddresses($destination)[0]
            return New-Object System.Net.IPEndPoint -ArgumentList $ipAddress, 0
        }
    }

    [psobject] SendICMPRequest([string]$destination, [int]$timeout, [switch]$TimestampRequest, [switch]$EchoRequest) {
    
        $endPoint = $this.CreateEndPoint($destination)

        if ($TimestampRequest) {
            $packet = $this.BuildICMPTimestampPacket()
        }
        elseif ($EchoRequest) {
            $packet = $this.BuildICMPEchoPacket()
        }
        else {
            throw "No ICMP request type specified. Use -TimestampRequest or -EchoRequest."
        }

        $this.socket.SendTo($packet, $endPoint)
    
        $receiveBuffer = New-Object byte[] 1024
        $this.socket.ReceiveTimeout = $timeout
        try {
            $bytesReceived = $this.socket.Receive($receiveBuffer)
            if ($bytesReceived -gt 0) {
                if ($TimestampRequest) {
                    return $this.HandleICMPTimestampReply($receiveBuffer)
                }
                elseif ($EchoRequest) {
                    return $this.HandleICMPEchoReply($receiveBuffer)
                }
            }
            else {
                Write-Host "No response received."
            }
        }
        catch {
            Write-Host "No response received or timed out."
        }
    
        return New-Object -TypeName PSObject -Property @{
            Success = $false
        }
    }
    
}

# Usage
$icmp = New-Object ICMP
$timeout = 5000

if ($TimestampRequest) {
    # Send an ICMP timestamp request.
    $response = $icmp.SendICMPRequest($destination, $timeout, $TimestampRequest, $EchoRequest)

    # Handle the timestamp response.
    if ($response.Success) {
        Write-Host "Original Timestamp: $($response.OriginalTimestamp)"
        Write-Host "Receive Timestamp: $($response.ReceiveTimestamp)"
        Write-Host "Transmit Timestamp: $($response.TransmitTimestamp)"
    }
    else {
        Write-Host "Failed to retrieve timestamps."
    }
}
elseif ($EchoRequest) {
    # Send an ICMP echo request.
    $response = $icmp.SendICMPRequest($destination, $timeout, $TimestampRequest, $EchoRequest)

    # Handle the echo response.
    if ($response.Success) {
        Write-Host "Echo request was successful"
        Write-Host "Identifier: $($response.Identifier)"
        Write-Host "Sequence Number: $($response.SequenceNumber)"
    }
    else {
        Write-Host "Failed to send echo request."
    }
}
else {
    Write-Host "No ICMP request type specified. Use -TimestampRequest or -EchoRequest."
}

