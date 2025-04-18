function RelaxedIT.EnergySaver.Run {
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

    $configOBJ = (Get-RelaxedITConfig -config $config)
    $processnames = $configOBJ.id


    $monitorTimeouts = @{}
    foreach ($item in $configOBJ) {
        $processNamePattern = $item.id
        $monitorTimeout = $null -ne $item.'monitor-timeout-ac' ? $item.'monitor-timeout-ac' : 10
        $monitorTimeouts[$processNamePattern] = $monitorTimeout
    }
    


    while ($true) {
        # Check if EnergySaverBlockingapps are running?
        $anyrunning = Get-Process -Name $processnames -ErrorAction SilentlyContinue
        
    
        if ($anyrunning) {
            # Change the terminal title
            $host.ui.RawUI.WindowTitle = "NO: Energy Server Mode"
            # Disable sleep mode
            powercfg -change -standby-timeout-ac 0
            foreach ($process in $anyrunning) {
                $processName = $process.ProcessName
                $matchingPattern = $monitorTimeouts.Keys | Where-Object { $processName -match $_ }
                if ($matchingPattern) {
                    $monitorTimeout = $monitorTimeouts[$matchingPattern]
                    powercfg -change -monitor-timeout-ac $monitorTimeout
                    Write-RelaxedIT -logtext """$processName"" is running. Monitor timeout set to $monitorTimeout."
                }
            }

        } elseif ($null -eq $anyrunning) {
            # Change the terminal title
            $host.ui.RawUI.WindowTitle = "EnergyTimeout 10 Min"
            # Enable sleep mode after 10 minutes
            powercfg -change -standby-timeout-ac 10
            powercfg -change -monitor-timeout-ac 10
            Write-RelaxedIT -logtext "No ""$config"" is running. Sleep mode enabled after 10 minutes."
                    
    
        } else {
            $host.ui.RawUI.WindowTitle = "EnergyTimeout 20 Min"
            # Enable sleep mode after 20 minutes
            powercfg -change -standby-timeout-ac 20
            powercfg -change -monitor-timeout-ac 20
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

