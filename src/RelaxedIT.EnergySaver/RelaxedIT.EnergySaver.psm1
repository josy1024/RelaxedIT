﻿function RelaxedIT.EnergySaver.Run {
    param (
        [int]$interval = 300,
        [string]$config = "C:\ProgramData\RelaxedIT\EnergySaver.json"
    )
   
    
    if (!(test-path -path $config ))
    {   $base = (Get-Module RelaxedIT.EnergySaver).ModuleBase
        Test-AndCreatePath -Path (Get-BasePath -Path $config)
        copy-item -Path (join-path $base "EnergySaver.json") -Destination $config
        Write-RelaxedIT "[Initial]: copy default config: ""$config"""
    }

    $processnames = (Get-RelaxedITConfig -config $config).id

    while ($true) {
        # Check if EnergySaverBlockingapps are running?
        $anyrunning = Get-Process -Name $processnames -ErrorAction SilentlyContinue

        if ($anyrunning) {
            # Change the terminal title
            $host.ui.RawUI.WindowTitle = "NO: Energy Server Mode"

            # Disable sleep mode
            powercfg -change -standby-timeout-ac 0
            powercfg -change -monitor-timeout-ac 10
            Write-RelaxedIT -logtext ($anyrunning.ProcessName -join ";")
            Write-RelaxedIT -logtext "is running. Sleep mode disabled."
        } else {
            $host.ui.RawUI.WindowTitle = "EnergyTimeout 20 Min"
            # Enable sleep mode after 20 minutes
            powercfg -change -standby-timeout-ac 20
            powercfg -change -monitor-timeout-ac 10
            Write-RelaxedIT -logtext "Neither ""$config"" is running. Sleep mode enabled after 20 minutes."
        }

        # Wait for the interval before checking again
        Start-Sleep -Seconds $interval
    }

}


# function RelaxedIT.EnergySaver.CreateTask
# {
#     Register-ScheduledTask -Xml EnergySaver.xml -TaskName "RelaxedIT.EnergySaver.Run" -TaskPath "RelaxedIT"
# } 
# pwsh.exe -windowstyle Minimized -command "RelaxedIT.EnergySaver.Run"
# }

