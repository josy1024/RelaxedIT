function Import-RelaxedITAzLogAssembly
{
    [CmdletBinding()]
    param (
        [string]$PackageRoot = "C:\ProgramData\RelaxedIT\packages"
    )

    if (-not (Test-Path -Path $PackageRoot))
    {
        Write-RelaxedIT -logtext "[WRN] RelaxedIT.AzLog: Package root path '$PackageRoot' does not exist. Run Install-RelaxedITAzLogPackage to install dependencies.... " -ForegroundColor Yellow
        Install-RelaxedITAzLogPackage

        return $false
    }

    if ([System.Type]::GetType("Azure.Data.Tables.TableClient, Azure.Data.Tables") -ne $null)
    {
        return $true
    }

    # In PowerShell 7 / .NET 8, load dependencies in order prior to primary assembly
    $dependencyDlls = @(
        "System.Memory.Data\lib\net8.0\System.Memory.Data.dll",
        "System.ClientModel\lib\net8.0\System.ClientModel.dll",
        "Azure.Core\lib\net8.0\Azure.Core.dll",
        "Azure.Data.Tables\lib\net8.0\Azure.Data.Tables.dll"
    )

    foreach ($relPath in $dependencyDlls)
    {
        $fullPath = Join-Path $PackageRoot $relPath
        if (Test-Path -Path $fullPath)
        {
            Add-Type -Path $fullPath -ErrorAction SilentlyContinue
        }
    }

    # Explicitly check primary assembly requested path
    $primaryPath = "C:\ProgramData\RelaxedIT\packages\Azure.Data.Tables\lib\net8.0\Azure.Data.Tables.dll"
    if (Test-Path -Path $primaryPath)
    {
        Add-Type -Path $primaryPath -ErrorAction SilentlyContinue
    }

    # Fallback scan for net8.0 assemblies if relocated
    if ([System.Type]::GetType("Azure.Data.Tables.TableClient, Azure.Data.Tables") -eq $null -and (Test-Path -Path $PackageRoot))
    {
        $net8Dlls = Get-ChildItem -Path $PackageRoot -Filter "*.dll" -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -match 'net8\.0' }
        foreach ($dll in $net8Dlls)
        {
            try { [System.Reflection.Assembly]::LoadFrom($dll.FullName) | Out-Null } catch {}
        }
    }

    return ([System.Type]::GetType("Azure.Data.Tables.TableClient, Azure.Data.Tables") -ne $null)
}

# Pre-load assembly when module is loaded
$null = Import-RelaxedITAzLogAssembly

function Send-RelaxedITAzLogPing
{
    [CmdletBinding()]
    param (
        [int]$interval = 300,
        [string]$config = "C:\ProgramData\RelaxedIT\azlog.json",
        [string]$action = "",
        [string]$sasToken = "# initial",
        [string]$accountKey = ""
    )

    if (!(Test-Path -Path $config))
    {
        $base = (Get-Module RelaxedIT.AzLog).ModuleBase
        if (-not $base)
        {
            $base = $PSScriptRoot
        }
        Test-AndCreatePath -Path (Get-BasePath -Path $config)
        Copy-Item -Path (Join-Path $base "azlog.json") -Destination $config
        Write-RelaxedIT "[Initial]: copy default config: ""$config"""
    }

    $configobj = Get-RelaxedITConfig -config $config

    if ($sasToken -ne "# initial")
    {
        $configobj.sasToken = $sasToken
        $configobj | ConvertTo-Json | Set-Content -Path $config -Encoding utf8BOM
    }

    if (-not [string]::IsNullOrWhiteSpace($accountKey))
    {
        $configobj | Add-Member -NotePropertyName "accountKey" -NotePropertyValue $accountKey -Force
        $configobj | ConvertTo-Json | Set-Content -Path $config -Encoding utf8BOM
    }

    $cfg = Get-RelaxedITConfig -config $config

    $currentSas = if ($cfg.sasToken) { [string]$cfg.sasToken } else { [string](Get-EnvVar -name "RelaxedIT.AzLog.sasToken") }
    $currentKey = if ($cfg.accountKey) { [string]$cfg.accountKey } else { [string](Get-EnvVar -name "RelaxedIT.AzLog.accountKey") }
    $storageAccountName = if ($cfg.storageAccountName) { [string]$cfg.storageAccountName } else { [string](Get-EnvVar -name "RelaxedIT.AzLog.storageAccountName") }
    $tableName = if ($cfg.tableName) { [string]$cfg.tableName } else { [string](Get-EnvVar -name "RelaxedIT.AzLog.tableName") }

    if (-not [string]::IsNullOrWhiteSpace($currentSas))
    {
        Set-EnvVar -name "RelaxedIT.AzLog.sasToken" -value $currentSas
    }
    if (-not [string]::IsNullOrWhiteSpace($currentKey))
    {
        Set-EnvVar -name "RelaxedIT.AzLog.accountKey" -value $currentKey
    }
    if (-not [string]::IsNullOrWhiteSpace($storageAccountName))
    {
        Set-EnvVar -name "RelaxedIT.AzLog.storageAccountName" -value $storageAccountName
    }
    if (-not [string]::IsNullOrWhiteSpace($tableName))
    {
        Set-EnvVar -name "RelaxedIT.AzLog.tableName" -value $tableName
    }

    $hasSas = (-not [string]::IsNullOrWhiteSpace($currentSas)) -and (-not $currentSas.StartsWith("#"))
    $hasKey = (-not [string]::IsNullOrWhiteSpace($currentKey)) -and (-not $currentKey.StartsWith("#"))

    if (-not $hasSas -and -not $hasKey)
    {
        Write-RelaxedIT -logtext "[WRN] RelaxedIT.AzLog.Run: CONFIG: No valid sasToken or accountKey configured for table ""$tableName""!"
        return
    }

    if (-not $storageAccountName)
    {
        Write-RelaxedIT -logtext "[ERR] RelaxedIT.AzLog.Run: Missing storage account name in config: $config" -ForegroundColor Red
        return
    }

    # Ensure Azure.Data.Tables assembly is loaded
    if (-not (Import-RelaxedITAzLogAssembly))
    {
        Write-RelaxedIT -logtext "[ERR] RelaxedIT.AzLog.Run: Azure.Data.Tables.dll could not be loaded from C:\ProgramData\RelaxedIT\packages. Run Install-RelaxedITAzLogPackage." -ForegroundColor Red
        return
    }

    # Collect OS & Hardware inventory using PowerShell 7 compatible CIM cmdlets
    try
    {
        $winNtReg = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction SilentlyContinue
        $displayVersion = $winNtReg.DisplayVersion
        $currentBuildNumber = $winNtReg.CurrentBuildNumber

        $productName = (Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue).Caption
        $biosVersion = (Get-CimInstance -ClassName Win32_BIOS -ErrorAction SilentlyContinue).SMBIOSBIOSVersion

        $cs = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue
        $manufacturer = $cs.Manufacturer
        $model = $cs.Model

        $relaxedver = Test-RelaxedIT -ErrorAction SilentlyContinue

        $cpu_info = Get-CimInstance -ClassName Win32_Processor -ErrorAction SilentlyContinue |
        Select-Object -Property Name, NumberOfCores, NumberOfLogicalProcessors

        $ram_info = Get-CimInstance -ClassName Win32_PhysicalMemory -ErrorAction SilentlyContinue |
        Measure-Object -Property Capacity -Sum
        $ramGB = if ($ram_info.Sum) { [math]::round($ram_info.Sum / 1GB, 2) } else { 0 }

        # Optional driver updates check
        $pendingdrivers = ""
        try
        {
            if (Get-Command Get-WindowsUpdate -ErrorAction SilentlyContinue)
            {
                $drivers = Get-WindowsUpdate -Category "Drivers" -ErrorAction SilentlyContinue
                if ($drivers)
                {
                    $pendingdrivers = ($drivers.Title | Sort-Object -Unique) -join "; "
                }
            }
        }
        catch {}

        # Outdated third-party packages check
        $outdated = $null
        try
        {
            if (Get-Command RelaxedIT.3rdParty.chocolist -ErrorAction SilentlyContinue)
            {
                $outdated = RelaxedIT.3rdParty.chocolist -ErrorAction SilentlyContinue
            }
        }
        catch {}
    }
    catch
    {
        Write-RelaxedIT -logtext ("# GetOSInventory (" + ($MyInvocation.ScriptName.Split("\")[-1]) + ") """ + $MyInvocation.MyCommand.Name + """: " + $MyInvocation.PSCommandPath + ": " + $_.Exception.Message + $_.Exception.ItemName) -ForegroundColor Red
        Write-RelaxedIT -logtext ($_ | Format-List * -Force | Out-String) -ForegroundColor Red
    }

    # Initialize Azure Table Client
    try
    {
        $tableClient = $null

        if ($hasKey)
        {
            # SharedKeyCredential (Account Name + Account Key)
            $endpoint = [Uri]"https://$storageAccountName.table.core.windows.net"
            $credentials = [Azure.Data.Tables.TableSharedKeyCredential]::new($storageAccountName, $currentKey)
            $tableClient = [Azure.Data.Tables.TableClient]::new($endpoint, $tableName, $credentials)
        }
        elseif ($hasSas)
        {
            # SAS Credential
            $cleanSas = $currentSas.TrimStart('?')
            $tableUri = [Uri]"https://$storageAccountName.table.core.windows.net/$tableName"
            $credentials = [Azure.AzureSasCredential]::new($cleanSas)
            $tableClient = [Azure.Data.Tables.TableClient]::new($tableUri, $credentials)
        }

        if (-not $tableClient)
        {
            throw "Failed to initialize Azure.Data.Tables.TableClient."
        }

        # Automatically create table if it does not exist
        try
        {
            $null = $tableClient.CreateTableIfNotExists()
        }
        catch
        {
            # SAS tokens without table management permissions may throw; continue to entity upsert
            Write-RelaxedIT -logtext "[DBG] RelaxedIT.AzLog.Run: CreateTableIfNotExists notice: $($_.Exception.Message)"
        }

        # Build TableEntity using PowerShell 7 hashtable
        $partitionKey = "ping"
        $rowKey = $env:COMPUTERNAME

        $entityData = @{
            PartitionKey       = $partitionKey
            RowKey             = $rowKey
            ServerName         = $env:COMPUTERNAME
            action             = $action
            displayVersion     = $displayVersion
            productName        = $productName
            currentBuildNumber = $currentBuildNumber
            biosVersion        = $biosVersion
            manufacturer       = $manufacturer
            model              = $model
            ramGB              = $ramGB
            cpu                = ($cpu_info | ConvertTo-Json -Compress)
            version            = $relaxedver
            pendingdrivers     = $pendingdrivers
            SoftwareOutdated   = $outdated
            PingTimeUTC        = (Get-LogDateFileString)
            Timestamp          = [DateTimeOffset]::UtcNow
        }

        $cleanEntityData = @{}
        foreach ($entry in $entityData.GetEnumerator())
        {
            if ($null -ne $entry.Value)
            {
                $cleanEntityData[$entry.Key] = $entry.Value
            }
        }

        $entity = [Azure.Data.Tables.TableEntity]::new($cleanEntityData)

        # Upsert entity (Insert or Merge in a single atomic call)
        Write-RelaxedIT -logtext "Upsert: [Azure.Data.Tables] ""$model"" $action " -NoNewline

        $response = $tableClient.UpsertEntity($entity, [Azure.Data.Tables.TableUpdateMode]::Merge)
        $etag = $response.Headers.ETag

        if ($response.Status -in 200, 201, 204)
        {
            Write-RelaxedIT -logtext "OK (Status: $($response.Status); ETag: $etag)" -noWriteDate -ForegroundColor Green
        }
        else
        {
            Write-RelaxedIT -logtext "[ERR] Status: $($response.Status) | ETag: $etag" -noWriteDate -ForegroundColor Red
        }

        Write-RelaxedIT -LogText ($entity | Out-String) -ForegroundColor Yellow
        return $response
    }
    catch
    {
        Write-RelaxedIT -logtext ("#(" + ($MyInvocation.ScriptName.Split("\")[-1]) + ") """ + $MyInvocation.MyCommand.Name + """: " + $MyInvocation.PSCommandPath + ": " + $_.Exception.Message + $_.Exception.ItemName) -ForegroundColor Red
        Write-RelaxedIT -logtext ($_ | Format-List * -Force | Out-String) -ForegroundColor Red
    }
}

function Install-RelaxedITAzLogPackage
{
    [CmdletBinding()]
    param (
        [string]$PackageDestination = "C:\ProgramData\RelaxedIT\packages"
    )

    Test-AndCreatePath -Path $PackageDestination

    if (Get-Command choco -ErrorAction SilentlyContinue)
    {
        choco upgrade nuget.commandline -y
    }

    if (Get-Command nuget -ErrorAction SilentlyContinue)
    {
        nuget install Azure.Data.Tables -OutputDirectory $PackageDestination -ExcludeVersion -Framework net8.0
    }
    else
    {
        Write-RelaxedIT -logtext "[WRN] nuget command not found. Ensure nuget.commandline is installed." -ForegroundColor Yellow
    }

    $null = Import-RelaxedITAzLogAssembly -PackageRoot $PackageDestination
}

function Add-RelaxedITAzLogToken
{
    [CmdletBinding()]
    param(
        [string]$config = "C:\ProgramData\RelaxedIT\azlog.json",
        [int]$years = 5,
        [string]$accountKey = ""
    )

    if (!(Test-Path -Path $config))
    {
        $base = (Get-Module RelaxedIT.AzLog).ModuleBase
        if (-not $base)
        {
            $base = $PSScriptRoot
        }
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

    if (-not [string]::IsNullOrWhiteSpace($accountKey))
    {
        $configobj | Add-Member -NotePropertyName "accountKey" -NotePropertyValue $accountKey -Force
        $configobj | ConvertTo-Json | Set-Content -Path $config -Encoding utf8BOM
        Write-RelaxedIT -logtext "Account key saved to $config" -ForegroundColor Green
        return $accountKey
    }

    $expiry = (Get-Date).AddYears($years).ToUniversalTime().ToString("yyyy-MM-ddTHH:mmZ")

    $azCmd = Get-Command az -ErrorAction SilentlyContinue
    if (-not $azCmd)
    {
        Write-RelaxedIT -logtext "[ERR] Azure CLI 'az' not found. Install Azure CLI and login ('az login') or configure accountKey/sasToken manually." -ForegroundColor Red
        return
    }

    # Try table-level SAS first (requires az extension / permissions)
    $sas = $null
    try
    {
        $sas = & az storage table generate-sas --name $tableName --account-name $storageAccountName --expiry $expiry --permissions rau --https-only --auth-mode login -o tsv 2>$null
    }
    catch {}

    if (-not $sas -or $sas -eq "")
    {
        try
        {
            # Fallback to account-level SAS for table service
            $sas = & az storage account generate-sas --account-name $storageAccountName --expiry $expiry --permissions rwdlacup --services t --resource-types sco --https-only -o tsv 2>$null
        }
        catch {}
    }

    if (-not $sas -or $sas -eq "")
    {
        Write-RelaxedIT -logtext "[ERR] Could not generate SAS via Azure CLI. Ensure 'az login' and proper RBAC or provide SAS/accountKey manually." -ForegroundColor Red
        return
    }

    if ($sas.StartsWith("?")) { $sas = $sas.Substring(1) }

    $configobj.sasToken = $sas
    $configobj | ConvertTo-Json | Set-Content -Path $config -Encoding utf8BOM

    Write-RelaxedIT -logtext "SAS token generated and saved to $config" -ForegroundColor Green
    return $sas
}

# Export Aliases for backwards compatibility with dot-separated names
Set-Alias -Name 'RelaxedIT.AzLog.Run.Ping' -Value 'Send-RelaxedITAzLogPing'
Set-Alias -Name 'RelaxedIT.AzLog.AddToken' -Value 'Add-RelaxedITAzLogToken'
Set-Alias -Name 'RelaxedIT.AzLog.InstalRequiredPackages' -Value 'Install-RelaxedITAzLogPackage'
Set-Alias -Name 'RelaxedIT.AzLog.InstallRequiredPackages' -Value 'Install-RelaxedITAzLogPackage'

Export-ModuleMember -Function 'Send-RelaxedITAzLogPing', 'Add-RelaxedITAzLogToken', 'Install-RelaxedITAzLogPackage', 'Import-RelaxedITAzLogAssembly' -Alias 'RelaxedIT.AzLog.Run.Ping', 'RelaxedIT.AzLog.AddToken', 'RelaxedIT.AzLog.InstalRequiredPackages', 'RelaxedIT.AzLog.InstallRequiredPackages'
