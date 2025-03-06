# Set interval for checking (in seconds)
$interval = 300
$config = "C:\ProgramData\RelaxedIT\EnergySaver.json"

$processnames = (Get-ConfigfromJSON -config $config).id

while ($true) {
    # Check if Minecraft or Jellyfin are running
    $minecraft = Get-Process -Name "bedrock*" -ErrorAction SilentlyContinue
    $jellyfin = Get-Process -Name "Jellyfin*" -ErrorAction SilentlyContinue

    if ($minecraft -or $jellyfin) {
        # Change the terminal title
        $host.ui.RawUI.WindowTitle = "Energy Server Mode"

        # Disable sleep mode
        powercfg -change -standby-timeout-ac 0
        powercfg -change -monitor-timeout-ac 10
        Write-Output $minecraft.ProcessName $jellyfin.ProcessName 
        Write-Output "is running. Sleep mode disabled."
    } else {
        $host.ui.RawUI.WindowTitle = "EnergyTimeout 20 Min"
        # Enable sleep mode after 20 minutes
        powercfg -change -standby-timeout-ac 20
        powercfg -change -monitor-timeout-ac 10
        Write-Output "Neither Minecraft nor Jellyfin is running. Sleep mode enabled after 20 minutes."
    }

    # Wait for the interval before checking again
    Start-Sleep -Seconds $interval
}
