function RelaxedIT.AzLog.Run.Ping
{
    param (
        [int]$interval = 300,
        [string]$config = "C:\ProgramData\RelaxedIT\azlog.json",
        [string]$action = "",
        [string]$sasToken = "# initial"
    )


    if (!(test-path -path $config ))
    {
        $base = (Get-Module RelaxedIT.AzLog).ModuleBase
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
        return
    }
    try
    {
        $displayVersion = (Get-ItemProperty -Path 'HKLM:\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion').DisplayVersion
        #$productName = (Get-ItemProperty -Path 'HKLM:\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion').ProductName
        $productName = (Get-CimInstance -ClassName Win32_OperatingSystem).Caption

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
    catch
    {
        Write-RelaxedIT -logtext ("# GetOSInventory (" + ($MyInvocation.ScriptName.Split("\")[-1]) + ") """ + $MyInvocation.MyCommand.Name + """: " + $MyInvocation.PSCommandPath + ": " + $_.Exception.Message + $_.Exception.ItemName)  -ForegroundColor red
        Write-RelaxedIT -logtext ($_ | Format-List * -Force | Out-String) -ForegroundColor red

    }
    try
    {
        $storageAccountName = (Get-EnvVar -name "RelaxedIT.AzLog.storageAccountName")

        if (-not $storageAccountName)
        {
            throw "Missing storage account name"
        }
        $sasToken = (Get-EnvVar -name "RelaxedIT.AzLog.sasToken")
        #-SasToken (Get-EnvVar -name "RelaxedIT.AzLog.sasToken")
        $storageContext = New-AzStorageContext -StorageAccountName $storageAccountName -SasToken $sasToken
        $table = (Get-AzStorageTable -Name $tableName -Context $storageContext).CloudTable
        if (-not $table)
        {
            Write-RelaxedIT -logtext "[WRN] RelaxedIT.AzLog.Run: Table '$tableName' not found or inaccessible. Check SAS token and storage account." -ForegroundColor Yellow
            $tryinsert = $true
        }
        $outdated = RelaxedIT.3rdParty.chocolist -ErrorAction SilentlyContinue
        # Step 2: Modify the entity
        try
        {
            $entity = Get-AzTableRow -table $table -customFilter "(PartitionKey eq 'ping') and (RowKey eq '$($env:computername)')"
            if (-not $table) { throw "Table object is null" }

            # Define expected properties and their values
            $expectedProps = @{
                action             = $action
                displayVersion     = $displayVersion
                productName        = $productName
                currentBuildNumber = $currentBuildNumber
                biosVersion        = $biosVersion
                manufacturer       = $manufacturer
                model              = $model
                ramGB              = $ramGB
                cpu                = ($cpu_info | ConvertTo-Json)
                version            = $relaxedver
                pendingdrivers     = $pendingdrivers
                SoftwareOutdated   = $outdated
                PingTimeUTC        = Get-LogDateFileString
            }

            # Ensure all properties exist on the entity
            foreach ($key in $expectedProps.Keys)
            {
                if (-not $entity.PSObject.Properties[$key])
                {
                    Write-RelaxedIT -logtext ("Update-AzTableRow Prop Update: $key : " + $expectedProps[$key])
                    Add-Member -InputObject $entity -NotePropertyName $key -NotePropertyValue $expectedProps[$key]
                }
                else
                {
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
        catch
        {
            Write-RelaxedIT -logtext "[WRN] RelaxedIT.AzLog.Run: Element: ping in ""$tableName"" not found try update!" #TODO: FIX remove maybe not needed?!?!
            try
            {
                Write-RelaxedIT -logtext "Update: Add-AzTableRow ""$table"" $action" -NoNewline
                $retadd = Update-AzTableRow -table $table -entity $entity
            }
            catch
            {
                $entity | Remove-AzTableRow -Table $table
            }
            Write-RelaxedIT -logtext ("#(" + ($MyInvocation.ScriptName.Split("\")[-1]) + ") """ + $MyInvocation.MyCommand.Name + """: " + $MyInvocation.PSCommandPath + ": " + $_.Exception.Message + $_.Exception.ItemName)  -ForegroundColor red
            Write-RelaxedIT -logtext ($_ | Format-List * -Force | Out-String) -ForegroundColor red
            $tryinsert = $true
        }


    }
    catch
    {
        Write-RelaxedIT -logtext ("#(" + ($MyInvocation.ScriptName.Split("\")[-1]) + ") """ + $MyInvocation.MyCommand.Name + """: " + $MyInvocation.PSCommandPath + ": " + $_.Exception.Message + $_.Exception.ItemName)  -ForegroundColor red
        Write-RelaxedIT -logtext ($_ | Format-List * -Force | Out-String) -ForegroundColor red
        $tryinsert = $true
    }

    if ($tryinsert)
    {
        Write-RelaxedIT -logtext ("AzLog: Tryinsert! ") -ForegroundColor red
        try
        {
            $prop = @{
                PingTimeUTC        = (Get-LogDateFileString)
                action             = $action
                displayVersion     = $displayVersion
                productName        = $productName
                currentBuildNumber = $currentBuildNumber
                biosVersion        = $biosVersion
                manufacturer       = $manufacturer
                model              = $model
                ramGB              = $ramGB
                cpu                = ($cpu_info | convertto-json)
                version            = $relaxedver
                pendingdrivers     = $pendingdrivers
                SoftwareOutdated   = (RelaxedIT.3rdParty.chocolist)
            }
            Write-RelaxedIT -logtext "Insert: Add-AzTableRow ""$table"" $action" -NoNewline
            if (-not $table)
            {
                Write-RelaxedIT -logtext "[ERR] RelaxedIT.AzLog.Run: Cannot insert because table object is null. Aborting insert." -ForegroundColor Red
                return
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
        catch
        {
            Write-RelaxedIT -logtext "[WRN] RelaxedIT.AzLog.Run: UPDATE ERR1: open azure cloud shell and create table ""$tableName"" with sas keys!"
            Write-RelaxedIT -logtext ("#(" + ($MyInvocation.ScriptName.Split("\")[-1]) + ") """ + $MyInvocation.MyCommand.Name + """: " + $MyInvocation.PSCommandPath + ": " + $_.Exception.Message + $_.Exception.ItemName)  -ForegroundColor red
            Write-RelaxedIT -logtext ($_ | Format-List * -Force | Out-String) -ForegroundColor red
        }
    }
}

function RelaxedIT.AzLog.AddToken
{
    param(
        [string]$config = "C:\ProgramData\RelaxedIT\azlog.json",
        [int]$years = 5
    )

    if (!(Test-Path -Path $config))
    {
        $base = (Get-Module RelaxedIT.AzLog).ModuleBase
        Test-AndCreatePath -Path (Get-BasePath -Path $config)
        Copy-Item -Path (Join-Path $base "azlog.json") -Destination $config
        Write-RelaxedIT "[Initial]: copy default config: '$config'"
    }

    $configobj = Get-RelaxedITConfig -config $config

    $storageAccountName = $configobj.storageAccountName
    if (-not $storageAccountName)
    {
        $storageAccountName = Read-Host "Enter storage account name"
        if (-not $storageAccountName) { Write-RelaxedIT -logtext "No storage account name provided. Aborting." -ForegroundColor Red; return }
        $configobj.storageAccountName = $storageAccountName
    }

    $tableName = $configobj.tableName
    if (-not $tableName)
    {
        $tableName = Read-Host "Enter table name (default: table01)"
        if (-not $tableName) { $tableName = "table01" }
        $configobj.tableName = $tableName
    }

    $expiry = (Get-Date).AddYears($years).ToUniversalTime().ToString("yyyy-MM-ddTHH:mmZ")

    $azCmd = Get-Command az -ErrorAction SilentlyContinue
    if (-not $azCmd)
    {
        Write-RelaxedIT -logtext "[ERR] Azure CLI 'az' not found. Install Azure CLI and login ('az login') then retry." -ForegroundColor Red
        return
    }

    # Try table-level SAS first (requires az extension / permissions)
    $sas = $null
    <#
    $tableName = "table01"
    $storageAccountName = "endpointlogger"
    $expiry = (Get-Date).AddYears(5).ToUniversalTime().ToString("yyyy-MM-ddTHH:mmZ")
    $sas = & az storage account generate-sas --account-name $storageAccountName --expiry $expiry --permissions rwdlacup --services t --resource-types s --https-only -o tsv 2>$null
    #>
    try
    {
        $sas = & az storage table generate-sas --name $tableName --account-name $storageAccountName --expiry $expiry --permissions rau --https-only --auth-mode login -o tsv 2>$null
    }
    catch {}

    if (-not $sas -or $sas -eq "")
    {
        try
        {
            # Fallback to account-level SAS for table service (broader permissions)
            $sas = & az storage account generate-sas --account-name $storageAccountName --expiry $expiry --permissions rwdlacup --services t --resource-types s --https-only -o tsv 2>$null
        }
        catch {}
    }

    if (-not $sas -or $sas -eq "")
    {
        Write-RelaxedIT -logtext "[ERR] Could not generate SAS via Azure CLI. Ensure 'az login' and proper RBAC or provide SAS manually." -ForegroundColor Red
        return
    }

    if ($sas.StartsWith("?")) { $sas = $sas.Substring(1) }

    $configobj.sasToken = $sas
    $configobj | ConvertTo-Json | Set-Content -Path $config -Encoding utf8BOM

    Write-RelaxedIT -logtext "SAS token generated and saved to $config" -ForegroundColor Green
    return $sas
}
