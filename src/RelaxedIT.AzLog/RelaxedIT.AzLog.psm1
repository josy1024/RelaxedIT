function RelaxedIT.AzLog.Run.Ping {
    param (
        [int]$interval = 300,
        [string]$config = "C:\ProgramData\RelaxedIT\azlog.json",
        [string]$action = "",
        [string]$sasToken = "# initial"
    )


    if (!(test-path -path $config ))
    {   $base = (Get-Module RelaxedIT.AzLog).ModuleBase
        Test-AndCreatePath -Path (Get-BasePath -Path $config)
        copy-item -Path (join-path $base "azlog.json") -Destination $config
        Write-RelaxedIT "[Initial]: copy default config: ""$config"""
    }

    if ($sasToken -ne "# initial")
    {
        $configobj = Get-RelaxedITConfig -config $config
        $configobj.sasToken = $sasToken
        $configobj | ConvertTo-Json | Set-Content -Path $config -Encoding utf8BOM
    }

    set-envvar -name "RelaxedIT.AzLog.sasToken" -value (Get-RelaxedITConfig -config $config).sasToken
    set-envvar -name "RelaxedIT.AzLog.storageAccountName" -value (Get-RelaxedITConfig -config $config).storageAccountName
    set-envvar -name "RelaxedIT.AzLog.tableName" -value (Get-RelaxedITConfig -config $config).tableName

    $tableName = (Get-EnvVar -name "RelaxedIT.AzLog.tableName")

    if ((Get-EnvVar -name "RelaxedIT.AzLog.sasToken").startswith("#"))
    {
        Write-RelaxedIT -logtext "[WRN] RelaxedIT.AzLog.Run: CONFIG: open azure cloud shell and create sys keys for table ""$tableName""!"
        break
    }
    try {
        $displayVersion = (Get-ItemProperty -Path 'HKLM:\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion').DisplayVersion
        $productName = (Get-ItemProperty -Path 'HKLM:\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion').ProductName
        $currentBuildNumber = (Get-ItemProperty -Path 'HKLM:\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion').CurrentBuildNumber
        $biosVersion = (Get-WmiObject -Class Win32_BIOS).SMBIOSBIOSVersion
        $manufacturer = (Get-WmiObject -Class Win32_ComputerSystem).Manufacturer
        $model = (Get-WmiObject -Class Win32_ComputerSystem).Model
        $relaxedver = Test-RelaxedIT

        $cpu_info = Get-WmiObject -Class Win32_Processor | Select-Object -Property Name, NumberOfCores, NumberOfLogicalProcessors

        # Get RAM information
        $ram_info = Get-WmiObject -Class Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum
        $ramGB = $([math]::round($ram_info.Sum / 1GB, 2))

        Import-Module PSWindowsUpdate

        # Alle verfügbaren Updates anzeigen
        $drivers = Get-WindowsUpdate -Category "Drivers"
        $pendingdrivers = ($drivers.Title | Sort-Object -Unique) -join "; "

    }
    catch {
        Write-RelaxedIT -logtext ("# GetOSInventory (" + ($MyInvocation.ScriptName.Split("\")[-1]) + ") """ + $MyInvocation.MyCommand.Name + """: " + $MyInvocation.PSCommandPath + ": " + $_.Exception.Message + $_.Exception.ItemName)  -ForegroundColor red
        Write-RelaxedIT -logtext ($_ | Format-List * -Force | Out-String) -ForegroundColor red

    }
    try {
        $storageAccountName = (Get-EnvVar -name "RelaxedIT.AzLog.storageAccountName")

        if (-not $storageAccountName) {
            throw "Missing storage account name"
        }
        #$sasToken = (Get-EnvVar -name "RelaxedIT.AzLog.sasToken")
        $storageContext = New-AzStorageContext -StorageAccountName $storageAccountName -SasToken (Get-EnvVar -name "RelaxedIT.AzLog.sasToken")
        $table = (Get-AzStorageTable -Name $tableName -Context $storageContext).CloudTable
        $outdated = RelaxedIT.3rdParty.chocolist -ErrorAction SilentlyContinue
        # Step 2: Modify the entity
        try {
            $entity = Get-AzTableRow -table $table -customFilter "(PartitionKey eq 'ping') and (RowKey eq '$($env:computername)')"

                        # Define expected properties and their values
            $expectedProps = @{
                action = $action
                displayVersion = $displayVersion
                productName = $productName
                currentBuildNumber = $currentBuildNumber
                biosVersion = $biosVersion
                manufacturer = $manufacturer
                model = $model
                ramGB = $ramGB
                cpu = ($cpu_info | ConvertTo-Json)
                version = $relaxedver
                pendingdrivers = $pendingdrivers
                SoftwareOutdated = $outdated
                PingTimeUTC = Get-LogDateFileString
            }

            # Ensure all properties exist on the entity
            foreach ($key in $expectedProps.Keys) {
                if (-not $entity.PSObject.Properties[$key]) {
                    Write-RelaxedIT -logtext ("Update-AzTableRow Prop Update: $key : " + $expectedProps[$key])
                    Add-Member -InputObject $entity -NotePropertyName $key -NotePropertyValue $expectedProps[$key]
                } else {
                    $entity.$key = $expectedProps[$key]
                }
            }

            Write-RelaxedIT -logtext "Update-AzTableRow ""$table"" $action" -NoNewline

            $retadd = Update-AzTableRow -table $table -entity $entity
            if ($retadd.HttpStatuscode -eq 204)
            {
                Write-RelaxedIT -logtext "OK" -noWriteDate -ForegroundColor Green
            }
            else
            {
                Write-RelaxedIT -logtext "[ERR] $retadd" -noWriteDate -ForegroundColor Red
            }
            Write-RelaxedIT -LogText ($entity | Out-String) -ForegroundColor Yellow
            return $retadd
        }
        catch {
            Write-RelaxedIT -logtext "[WRN] RelaxedIT.AzLog.Run: Element: ping in ""$tableName"" not found try update!" #TODO: FIX remove maybe not needed?!?!
            try {
                Write-RelaxedIT -logtext "Update: Add-AzTableRow ""$table"" $action" -NoNewline
                $retadd = Update-AzTableRow -table $table -entity $entity
                }
            catch {
                $entity | Remove-AzTableRow -Table $table
            }
            Write-RelaxedIT -logtext ("#(" + ($MyInvocation.ScriptName.Split("\")[-1]) + ") """ + $MyInvocation.MyCommand.Name + """: " + $MyInvocation.PSCommandPath + ": " + $_.Exception.Message + $_.Exception.ItemName)  -ForegroundColor red
            Write-RelaxedIT -logtext ($_ | Format-List * -Force | Out-String) -ForegroundColor red
            $tryinsert = $true
        }


    }
    catch {
        Write-RelaxedIT -logtext ("#(" + ($MyInvocation.ScriptName.Split("\")[-1]) + ") """ + $MyInvocation.MyCommand.Name + """: " + $MyInvocation.PSCommandPath + ": " + $_.Exception.Message + $_.Exception.ItemName)  -ForegroundColor red
        Write-RelaxedIT -logtext ($_ | Format-List * -Force | Out-String) -ForegroundColor red
        $tryinsert = $true
    }

    if ($tryinsert)
    {
        Write-RelaxedIT -logtext ("AzLog: Tryinsert! ") -ForegroundColor red
        try {
            $prop = @{
                PingTimeUTC = (Get-LogDateFileString)
                action = $action
                displayVersion = $displayVersion
                productName = $productName
                currentBuildNumber = $currentBuildNumber
                biosVersion = $biosVersion
                manufacturer = $manufacturer
                model = $model
                ramGB = $ramGB
                cpu = ($cpu_info | convertto-json)
                version = $relaxedver
                pendingdrivers =  $pendingdrivers
                SoftwareOutdated = (RelaxedIT.3rdParty.chocolist)
            }
            Write-RelaxedIT -logtext "Insert: Add-AzTableRow ""$table"" $action" -NoNewline
            $retadd = Add-AzTableRow -Table $table -PartitionKey "ping" -RowKey $env:computername -property $prop
            if ($retadd.HttpStatuscode -eq 204)
            {
                Write-RelaxedIT -logtext "OK"  -noWriteDate -ForegroundColor Green
            }
            else
            {
                Write-RelaxedIT -logtext "[ERR] $retadd" -noWriteDate -ForegroundColor Green
            }
            Write-RelaxedIT -LogText ($prop | Out-String) -ForegroundColor Yellow
            return $retadd
        }
        catch {
            Write-RelaxedIT -logtext "[WRN] RelaxedIT.AzLog.Run: UPDATE ERR1: open azure cloud shell and create table ""$tableName"" with sas keys!"
            Write-RelaxedIT -logtext ("#(" + ($MyInvocation.ScriptName.Split("\")[-1]) + ") """ + $MyInvocation.MyCommand.Name + """: " + $MyInvocation.PSCommandPath + ": " + $_.Exception.Message + $_.Exception.ItemName)  -ForegroundColor red
            Write-RelaxedIT -logtext ($_ | Format-List * -Force | Out-String) -ForegroundColor red
        }
    }
}
