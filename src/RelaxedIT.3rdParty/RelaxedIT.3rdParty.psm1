function RelaxedIT.3rdParty.Update {
    param (
        [string]$config = "C:\ProgramData\RelaxedIT\3rdParty.json",
         [string]$uninstallConfig = "C:\ProgramData\RelaxedIT\3rdPartyUninstallPrograms.json"
    )
   
    # uninstall first
    if (Test-path -path $uninstallConfig)
    {
        $uninstallList = (Get-Content -Path $uninstallConfig | ConvertFrom-Json).programs

        if (-not $uninstallList) {
            Write-RelaxedIT "[ERR] No programs defined in the uninstall configuration file ""$uninstallConfig""."
            return
        }
    
        # Loop through each program and uninstall
        foreach ($program in $uninstallList) {
            $id = $program.id
    
            if ($id) {
                Write-RelaxedIT "[Uninstalling]: ""$id"""
                & "C:\ProgramData\chocolatey\choco.exe" uninstall -y $id
            } else {
                Write-RelaxedIT "[WRN] Program ID is missing in the uninstall configuration file."
            }
        }
    }

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

    # Get the list of outdated programs once
    $outdatedPrograms = & "C:\ProgramData\chocolatey\choco.exe" outdated

    # Loop through each program and execute the Chocolatey upgrade command
    foreach ($program in $programList) {
        $id = $program.id
        $params = $program.params

        if ($outdatedPrograms -match $id) {
            Write-RelaxedIT "[Upgrading]: ""$id"" is outdated, upgrading now..."
            if ($params) {
                & "C:\ProgramData\chocolatey\choco.exe" upgrade -y $id -params $params
            } else {
                & "C:\ProgramData\chocolatey\choco.exe" upgrade -y $id
            }
        } else {
            Write-RelaxedIT "[Skipping]: ""$id"" is already up-to-date."
        }

    }


    # error handling for untested apps 
    # Write-RelaxedIT "[Upgrading]: upgrading all ..."
    # & "C:\ProgramData\chocolatey\choco.exe" upgrade -y $id

   

    #clean desktop from shortcuts
    Get-ChildItem -Path "C:\Users\Public\Desktop" -Filter "*.lnk" | foreach-object {
        Remove-Item -Path $_.Fullname
    }
}


