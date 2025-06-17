function RelaxedIT.3rdParty.Update {
    param (
        [string]$config = "C:\ProgramData\RelaxedIT\3rdParty.json",
         [string]$uninstallConfig = "C:\ProgramData\RelaxedIT\3rdPartyUninstallPrograms.json"
    )


    #enable Optional Windows Updates

    try {
       # Ensure the registry path exists
       if (-not (Test-Path "HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate")) {
            New-Item -Path "HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate" -Force | Out-Null
       }
       # Set the registry values
       Set-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate" -Name "AllowOptionalContent" -Value 2 -Type DWord
       Set-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate" -Name "SetAllowOptionalContent" -Value 2 -Type DWord

        # Delete the 'ExcludeWUDriversInQualityUpdate' value
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Name "ExcludeWUDriversInQualityUpdate" -ErrorAction SilentlyContinue

        # Set 'SearchOrderConfig' to 1
        New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching" -Force | Out-Null
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching" -Name "SearchOrderConfig" -Value 1 -Type DWord

        # Set 'ExcludeWUDrivers' to 0
        New-Item -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UpdatePolicy\PolicyState" -Force | Out-Null
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UpdatePolicy\PolicyState" -Name "ExcludeWUDrivers" -Value 0 -Type DWord

    }
    catch {
        <#Do this if a terminating exception happens#>
        Write-RelaxedIT "An error occurred while applying registry settings: $_"
        # Optional: log to a file
        # Add-Content -Path "$env:TEMP\RegistryUpdateError.log" -Value "$(Get-Date): $_"
    }


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
    # winget upgrade --all --include-unknown -i
    # winget upgrade $package --include-unknown --silent --accept-source-agreements --accept-package-agreements  --uninstall-previous
    #

    #clean desktop from shortcuts
    Get-ChildItem -Path "C:\Users\Public\Desktop" -Filter "*.lnk" | foreach-object {
        Remove-Item -Path $_.Fullname
    }
}

function RelaxedIT.3rdParty.chocolist {
    param (
        [string]$returnformat = "json"
    )

    # Get the list of outdated programs once
    $outdatedPrograms = & "C:\ProgramData\chocolatey\choco.exe" outdated --limit-output
    $outdatedData = $outdatedPrograms | ConvertFrom-Csv -Delimiter '|' -Header packagename,currentversion,availableversion,pinned

    if ($returnformat -eq "json")
    {
        $json = $outdatedData | ConvertTo-Json
        return $json
    }
    else {
        return $outdatedData
    }

}

function RelaxedIT.3rdParty.WindowsDrivers {
    param (
        [string]$config = "C:\ProgramData\RelaxedIT\3rdParty.json",
          [string]$category ="Drivers"
    )


    # Modul importieren
    Import-Module PSWindowsUpdate

    # Alle verfügbaren Updates anzeigen
    $drivers = Get-WindowsUpdate -Category $category
    $lastdriverupdate = ($drivers.Title | Sort-Object -Unique) -join "; "

    # Alle Updates automatisch installieren und ggf. neu starten
    Install-WindowsUpdate -AcceptAll -IgnoreReboot -Category $category


}

