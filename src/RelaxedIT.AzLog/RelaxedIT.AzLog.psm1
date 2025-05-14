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
        
        $cpu_info = Get-WmiObject -Class Win32_Processor | Select-Object -Property Name, NumberOfCores, NumberOfLogicalProcessors

        # Get RAM information
        $ram_info = Get-WmiObject -Class Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum
        $ramGB = $([math]::round($ram_info.Sum / 1GB, 2))
        


    }
    catch {
    }
    try {
        $storageAccountName = (Get-EnvVar -name "RelaxedIT.AzLog.storageAccountName")
        #$sasToken = (Get-EnvVar -name "RelaxedIT.AzLog.sasToken")
        $storageContext = New-AzStorageContext -StorageAccountName $storageAccountName -SasToken (Get-EnvVar -name "RelaxedIT.AzLog.sasToken")
        $table = (Get-AzStorageTable -Name $tableName -Context $storageContext).CloudTable

        # Step 2: Modify the entity
        try {
            $entity = Get-AzTableRow -table $table -customFilter "(PartitionKey eq 'ping') and (RowKey eq '$($env:computername)')"      
            
            $entitiy.action = $action
            $entitiy.displayVersion = $displayVersion
            $entitiy.productName = $productName
            $entitiy.currentBuildNumber = $currentBuildNumber
            $entitiy.biosVersion = $biosVersion
            $entitiy.manufacturer = $manufacturer
            $entitiy.model = $model
            $entitiy.ramGB = $ramGB
            $entitiy.cpu = $cpu_info | convertto-json

            $retadd = Update-AzTableRow -table $table -entity $entity
            return $retadd
        }
        catch {
            Write-RelaxedIT -logtext "[WRN] RelaxedIT.AzLog.Run: Element: ping in ""$tableName"" not found"
            $entity | Remove-AzTableRow -Table $table
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
        try {
            $prop = @{
                PingTimeUTC = Get-LogDateFileString
                action = $action
                displayVersion = $displayVersion
                productName = $productName
                currentBuildNumber = $currentBuildNumber
                biosVersion = $biosVersion
                manufacturer = $manufacturer
                model = $model
                ramGB = $ramGB
                cpu = ($cpu_info | convertto-json)
            }
            $retadd = Add-AzTableRow -Table $table -PartitionKey "ping" -RowKey $env:computername -property $prop
            return $retadd
        }
        catch {
            Write-RelaxedIT -logtext "[WRN] RelaxedIT.AzLog.Run: UPDATE ERR1: open azure cloud shell and create table ""$tableName"" with sas keys!"
            Write-RelaxedIT -logtext ("#(" + ($MyInvocation.ScriptName.Split("\")[-1]) + ") """ + $MyInvocation.MyCommand.Name + """: " + $MyInvocation.PSCommandPath + ": " + $_.Exception.Message + $_.Exception.ItemName)  -ForegroundColor red
            Write-RelaxedIT -logtext ($_ | Format-List * -Force | Out-String) -ForegroundColor red
        }
    }
}
