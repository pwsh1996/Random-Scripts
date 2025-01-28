function Get-MSDownload {
    param (
        [Int32]$Start = 46800,
        [Int32]$End = 46820 
    )
    $url = "https://www.microsoft.com/en-us/download/details.aspx?id="

    $dls = @()

    for ($i = $start; $i -le $end; $i++){
        
        $downs = New-Object psobject

        $bing = Invoke-WebRequest $url+$i
        $binging = $bing.content.split("<title>Download ")
        $really = $binging[1].split("from Official Microsoft Download Center")
        Add-Member -InputObject $downs -MemberType NoteProperty -name Name -Value $really[0]
        Add-Member -InputObject $downs -MemberType NoteProperty -name URL -Value ($url+$i)
        $dls += $downs
        Clear-Host
        write-host "$($end-$i) More to check"
        $host.UI.RawUI.WindowTitle = "$($end-$i) Left"
        Start-Sleep -Seconds 1
    }
    Clear-Host
    $dls
}