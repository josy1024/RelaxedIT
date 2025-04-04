function RelaxedIT.3rdParty.Update {
    param (
        [string]$config = "C:\ProgramData\RelaxedIT\3rdParty.json"
    )
   

    if (!(test-path -path $config ))
    {   $base = (Get-Module RelaxedIT.3rdParty).ModuleBase
        Test-AndCreatePath -Path (Get-BasePath -Path $config)
        copy-item -Path (join-path $base "3rdParty.json") -Destination $config
        Write-RelaxedIT "[INF]: copy default config: ""$config"""
    }


    # Load program list from JSON config
    $programList = (Get-RelaxedITConfig -Config $config).programs

    if (-not $programList) {
        Write-RelaxedIT "[ERR] No programs defined in the configuration file."
        return
    }

    # Loop through each program and execute the Chocolatey upgrade command
    foreach ($program in $programList) {
        $id = $program.id
        $params = $program.params

        if ($id) {
            if ($params) {
                Write-RelaxedIT "[Upgrading]: $id with params: $params"
                & "C:\ProgramData\chocolatey\choco.exe" upgrade -y $id -params $params
            } else {
                Write-RelaxedIT "[Upgrading]: $id without params"
                & "C:\ProgramData\chocolatey\choco.exe" upgrade -y $id
            }
        } else {
            Write-RelaxedIT "[WRN] Program ID is missing in the configuration file."
        }
    }
    #clean desktop from shortcuts
    Get-ChildItem -Path "C:\Users\Public\Desktop" -Filter "*.lnk" | foreach-object {
        Remove-Item -Path $_.Fullname
    }
}


