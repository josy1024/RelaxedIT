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
        $table = (Get-AzStorageTable -Name $tableName -Context $storageContext).CloudTable

        $entity = Get-AzTableRow -table $table -customFilter "(PartitionKey eq 'ping') and (RowKey eq '$($env:computername)')"      
        # Step 2: Modify the entity
        try {
            #$entity.PingTimeUTC = Get-LogDateFileString
            $entitiy.action = $action
            $retadd = Update-AzTableRow -table $table -entity $entity
            return $retadd
        }
        catch {
            Write-RelaxedIT -logtext "[WRN] RelaxedIT.AzLog.Run: Element: PingTimeUTC in ""$tableName"" not found"
            $entity | Remove-AzTableRow -Table $table
            $tryinsert = $true
        }


    }
    catch {
        $tryinsert = $true
    }

    if ($tryinsert)
    {
        try {
            $prop = @{
                PingTimeUTC = Get-LogDateFileString
                $entitiy.action = $action
            }
            $retadd = Add-AzTableRow -Table $table -PartitionKey "ping" -RowKey $env:computername -property $prop
            return $retadd
        }
        catch {
            Write-RelaxedIT -logtext "[WRN] RelaxedIT.AzLog.Run: UPDATE ERR1: open azure cloud shell and create table ""$tableName"" with sas keys!"
        }
    }
}
