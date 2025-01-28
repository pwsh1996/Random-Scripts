function boxplot {
    [CmdletBinding()]
    param(
        [Parameter(, Position = 0)]
        [string]$counterName = '\Processor Information(_Total)\% Processor Time',
        [Parameter(Mandatory = $true, Position = 1)]
        [int]$history = 15,
        [Parameter(Mandatory = $true, Position = 2)]
        [int]$width = 20,
        [Parameter(Mandatory = $true, Position = 3)]
        [string]$DisplayName = "% Processor Time"
    )
    process {
        $counter = [math]::round(((get-counter $counterName).countersamples).cookedvalue)

        # Add the counter to the queue
        $queue.Enqueue($counter)
    
        # If the queue has more than 15 elements, remove the oldest one
        if ($queue.Count -gt $history) {
            $trashqueue = $queue.Dequeue()
        }
    
        # Sort the data in the queue
        $sortedData = $queue | Sort-Object
    
        # Calculate the positions of the lower and upper quartiles
        $lowerQuartilePosition = [math]::floor($sortedData.Count * 0.25)
        $medianPosition = [math]::floor($sortedData.Count * 0.5)
        $upperQuartilePosition = [math]::floor($sortedData.Count * 0.75)
        
        # Find the values at these positions
        $lowerQuartile = $sortedData[$lowerQuartilePosition]
        $upperQuartile = $sortedData[$upperQuartilePosition]
        #calculate the min and max
        $min = $sortedData[0]
        $max = $sortedData[$sortedData.Count - 1]
    
        # Calculate the median
        if ($sortedData.Count % 2 -eq 0) {
            # If the number of data points is even, the median is the average of the two middle numbers
            $median = ($sortedData[$medianPosition] + $sortedData[$medianPosition - 1]) / 2
        }
        else {
            # If the number of data points is odd, the median is the middle number
            $median = $sortedData[$medianPosition]
        }
    
        $a = @(
            " ", #Empty
            [char]0x2582, #1/4 block 0x(unicode hex value)
            [char]0x2584, #1/2 block
            [char]0x2586    #3/4 block
        )
        $b = @(
            [char]0x255a, #0 boarder bottom left
            [char]0x2554, #1 boarder top left
            [char]0x2557, #2 boarder top right
            [char]0x255d, #3 boarder bottom right
            [char]0x2551, #4 boarder vertical
            [char]0x2550   #5 boarder horizontal
        )
        $c = @(
            [char]0x2514, #0 box bottom left
            [char]0x2510, #1 box top right
            [char]0x251c, #2 box right T
            [char]0x2524, #3 box left T
            [char]0x2500, #4 box horizantal
            [char]0x2502, #5 box vertical
            [char]0x250c, #6 box top left
            [char]0x2518  #7 box bottom right
        )
        # Initialize an empty array for the graph
        #$graph = @(@($b[1], $b[5], $b[5], $b[5], $b[5], $b[5], $b[5], $b[5], $b[5], $b[5], $b[5], $b[5], $b[5], $b[5], $b[5], $b[5], $b[5], $b[5], $b[5], , $b[5], $b[5], $b[5], $b[5], $b[5], $b[5], $b[5], $b[5], $b[5], $b[5], $b[5], $b[5], $b[5], $b[5], $b[5], $b[5], $b[5], $b[5], $b[5], $b[5], $b[2]), @($b[4], " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", $b[4]), @($b[4], " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", $b[4]), @($b[4], " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", $b[4]), @($b[0], $b[5], $b[5], $b[5], $b[5], $b[5], $b[5], $b[5], $b[5], $b[5], $b[5], $b[5], $b[5], $b[5], $b[5], $b[5], $b[5], $b[5], $b[5], , $b[5], $b[5], $b[5], $b[5], $b[5], $b[5], $b[5], $b[5], $b[5], $b[5], $b[5], $b[5], $b[5], $b[5], $b[5], $b[5], $b[5], $b[5], $b[5], $b[5], $b[3]), @())
        # Initialize an empty array for the graph
        $graph = @()
        for ($i = 0; $i -lt 5; $i++) {
            # Create a row with $width spaces
            $row = New-Object System.Collections.ArrayList
            for ($j = 0; $j -lt $width; $j++) {
                $row.Add(" ") | Out-Null
            }
        
            # Add the row to the graph
            $graph += ,$row
        }
        $graph[4][0] = $b[0]
        $graph[4][$width - 1] = $b[3]
        $graph[0][0] = $b[1]
        $graph[0][$width - 1] = $b[2]
        $graph[1][0] = $b[4]
        $graph[1][$width - 1] = $b[4]
        $graph[2][0] = $b[4]
        $graph[2][$width - 1] = $b[4]
        $graph[3][0] = $b[4]
        $graph[3][$width - 1] = $b[4]
        for ($i = 1; $i -lt $width - 1; $i++) {
            $graph[0][$i] = $b[5]
            $graph[4][$i] = $b[5]
        }


        # Calculate the position of the data point in the graph
        $ratio = 100 / ($width - 2)
        $position_min = [math]::round($min / $ratio)
        $position_max = [math]::round($max / $ratio)
        $position_median = [math]::round($median / $ratio)
        $position_upper = [math]::round($upperQuartile / $ratio)
        $position_lower = [math]::round($lowerQuartile / $ratio)
    
        # Replace the corresponding element in the array with a pipe
        $graph[2][$position_median] = "|"
        $graph[2][$position_min] = $c[2]
        $graph[2][$position_max] = $c[3]
        if ($position_lower -eq $position_min) {
            $graph[2][$position_lower] = $c[5]
        }
        else { $graph[2][$position_lower] = $c[3] }
        $graph[1][$position_lower] = $c[6]
        $graph[3][$position_lower] = $c[0]
        if ($position_upper -eq $position_max) {
            $graph[2][$position_upper] = $c[5]
        }
        else { $graph[2][$position_upper] = $c[2] }
        if ($position_upper -eq $position_lower) {
            $graph[1][$position_upper] = $c[5]
        }
        else { $graph[1][$position_upper] = $c[1] }
        if ($position_upper -eq $position_lower) {
            $graph[3][$position_upper] = $c[5]
        }
        else { $graph[3][$position_upper] = $c[7] }
        if ($position_upper -lt $position_max) {
            for ($i = $position_upper + 1; $i -lt $position_max; $i++) {
                $graph[2][$i] = $c[4]
            }
        }
        if ($position_lower -gt $position_min) {
            for ($i = $position_min + 1; $i -lt $position_lower; $i++) {
                $graph[2][$i] = $c[4]
            }
        }
        if ($position_lower -lt $position_upper) {
            for ($i = $position_lower + 1; $i -lt $position_upper; $i++) {
                $graph[1][$i] = $c[4]
                $graph[3][$i] = $c[4]
            }
        }

        #Label the graph
        if ($DisplayName.Length -lt ($width - 4)) {
            for ($i = 0; $i -lt $DisplayName.Length; $i++) {
                $graph[0][$i + 2] = $DisplayName[$i]
            }
        }
        Write-Output $graph
    }
}

function DisplayBox {
    [CmdletBinding()]
    param(
        [array]$chartData,
        [string]$color
    )
    process{
        foreach ($one in $graph[0]) { write-host $one -nonewline } write-host ""
    foreach ($one in $graph[1]) { write-host $one -nonewline } write-host ""
    foreach ($one in $graph[2]) { write-host $one -nonewline } write-host ""
    foreach ($one in $graph[3]) { write-host $one -nonewline } write-host ""
    foreach ($one in $graph[4]) { write-host $one -nonewline } write-host ""
    foreach ($one in $graph[5]) { write-host $one -nonewline } write-host ""
    }

}

# Create a queue to store the data points
$queue = New-Object System.Collections.Queue

# Get the processor time counter every second
while ($true) {

    $graph = boxplot -counterName '\Processor Information(_Total)\% Processor Time' -history 15 -width 50 -DisplayName ' % Processor Time '

    clear-host

    DisplayBox -chartdata $graph -color "blue"

    Start-Sleep -Seconds .5
}
