function Get-BasePath {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    # Resolve the base directory
    $BasePath = Split-Path -Path $Path -Parent
    return $BasePath
}


function Start-ElevatedPwsh {
    # Check if the current session is running as Administrator
    if (-Not ([Security.Principal.WindowsPrincipal]([Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))) {
        Write-RelaxedIT -logtext "Starting an elevated PowerShell session..." -ForegroundColor Yellow

        # Start an elevated PowerShell session (empty)
        Start-Process -FilePath "pwsh.exe" -Verb RunAs

        Write-RelaxedIT -logtext "An elevated PowerShell session has been started." -ForegroundColor Green
    } else {
        Write-RelaxedIT -logtext "This session is already running with Administrator privileges." -ForegroundColor Cyan
    }
}

function Test-AndCreatePath {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    # Check if the path exists
    if (Test-Path -Path $Path) {
        Write-RelaxedIT -logtext "Path '$Path' already exists." -ForegroundColor Green -level 3
    } else {
        # Create the path
        Write-RelaxedIT -logtext "Path '$Path' does not exist. Creating it now..." -ForegroundColor Yellow
        New-Item -ItemType Directory -Path $Path | Out-Null
        Write-RelaxedIT -logtext "Path '$Path' has been created." -ForegroundColor Cyan
    }
}

function Update-InFileContent {
    param (
        [Parameter(Mandatory = $true)]
        [string]$FilePath,   # The file to modify
        [Parameter(Mandatory = $true)]
        [string]$OldText,    # Text to be replaced
        [Parameter(Mandatory = $true)]
        [string]$NewText     # Replacement text
    )

    # Check if file exists
    if (-Not (Test-Path -Path $FilePath)) {
        Write-RelaxedIT -logtext "[ERR] File not found: $FilePath" -ForegroundColor Red
        return
    }

    # Read the content of the file
    $Content = Get-Content -Path $FilePath

    # Replace the specified text
    $UpdatedContent = $Content -replace [regex]::Escape($OldText), $NewText

    # Write the updated content back to the file
    Set-Content -Path $FilePath -Value $UpdatedContent -Encoding utf8BOM

    Write-RelaxedIT -logtext "Replaced ""$OldText"" with ""$NewText"" in ""$FilePath""" -ForegroundColor Green -level 2
}


Function Get-HwInfo
{
    <#
    .SYNOPSIS
    Queries essential hardware, OS, and disk information from local or remote computers.
    .PARAMETER ComputerName
    Specifies the target computer(s) for which to retrieve the information.
    Defaults to the local computer.
    .EXAMPLE
    Get-HwInfo -ComputerName "Server01", "PC05"
    #>
    [CmdletBinding(SupportsShouldProcess = $True)]
    Param(
        [Parameter(Mandatory = $False, Position = 1)]
        [string[]]$ComputerName = $Env:COMPUTERNAME
    )

    $HWInfoArray = @()

    foreach($Computer in $ComputerName)
    {
        # Helper variable for conditional CIM calls (Splatting)
        $CimParams = @{ ErrorAction = 'Stop' }
        if ($Computer -ne $Env:COMPUTERNAME) {
            $CimParams.Add('ComputerName', $Computer)
        }

        # Assuming Write-RelaxedIT is a custom function for logging
        Write-RelaxedIT -logtext "Query Hardware and OS Infos for ""$Computer""..."

        try
        {
            # --- 1. Basic HW Info ---
            $BIOS = Get-CimInstance -ClassName Win32_BIOS @CimParams
            $System = Get-CimInstance -ClassName Win32_ComputerSystem @CimParams

            $ObjectOutput = [PSCustomObject]@{
                ComputerName       = $Computer.ToUpper()
                BIOSVersion        = $BIOS.SMBIOSBIOSVersion
                SerialNumber       = $BIOS.SerialNumber
                Manufacturer       = $System.Manufacturer
                Model              = $System.Model
                SystemFamily       = $System.SystemFamily
            }

            # --- 2. CPU Info ---
            $Processor = Get-CimInstance -ClassName Win32_Processor @CimParams |
                         Select-Object -Property Name, NumberOfCores, NumberOfLogicalProcessors |
                         ConvertTo-Json -Compress

            $ObjectOutput | Add-Member -MemberType NoteProperty -Name CPUJSON -Value $Processor

            # --- 3. RAM Info ---
            $RAMInfo = Get-CimInstance -ClassName Win32_PhysicalMemory @CimParams
            $TotalRAMBytes = ($RAMInfo | Measure-Object -Property Capacity -Sum).Sum
            $RAM_GB = [math]::Round($TotalRAMBytes / 1GB, 2)

            $ObjectOutput | Add-Member -MemberType NoteProperty -Name RAM_GB -Value $RAM_GB

            # --- 4. OS Details ---
            $OS = Get-CimInstance -ClassName Win32_OperatingSystem @CimParams
            $ObjectOutput | Add-Member -MemberType NoteProperty -Name ProductName -Value $OS.Caption
            $ObjectOutput | Add-Member -MemberType NoteProperty -Name CurrentBuildNumber -Value $OS.BuildNumber

            $DisplayVersion = $null
            if ($CimParams.ContainsKey('ComputerName'))
            {
                $DisplayVersion = Invoke-Command -ComputerName $Computer -ScriptBlock {
                    (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').DisplayVersion
                } -ErrorAction SilentlyContinue
            }
            else
            {
                $DisplayVersion = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').DisplayVersion
            }
            $ObjectOutput | Add-Member -MemberType NoteProperty -Name DisplayVersion -Value $DisplayVersion

            # --- 5. DISK INFO INTEGRATION (Refactored to use Get-CimInstance) ---

            # Get all physical disks
            $disks = Get-CimInstance -ClassName Win32_DiskDrive @CimParams

            # Get logical disk info for size and free space (DriveType=3 is Local Disk)
            $logicalDisks = Get-CimInstance -ClassName Win32_LogicalDisk @CimParams -Filter "DriveType=3"

            $diskInfo = @()
            $totalSizeSum = 0
            $freeSizeSum = 0

            foreach ($disk in $disks) {
                # Get the partitions on the current physical disk
                $partitions = Get-CimInstance -ClassName Win32_DiskPartition @CimParams | Where-Object { $_.DiskIndex -eq $disk.Index }

                foreach ($partition in $partitions) {
                    # Get the link between the partition and the logical disk (volume)
                    # Note: We can often use Get-CimAssociatedInstance here, but for simplicity
                    # we will stick to the WMI chaining logic, ensuring CIM is used.
                    $link = Get-CimInstance -ClassName Win32_LogicalDiskToPartition @CimParams |
                            Where-Object { $_.Antecedent -like "*$($partition.DeviceID)*" }

                    if ($link) {
                        # Extract drive letter (DeviceID property from Dependent string)
                        $driveLetter = ($link.Dependent -split '"')[1]
                        $logical = $logicalDisks | Where-Object { $_.DeviceID -eq $driveLetter }

                        if ($logical) {
                            $diskObj = [PSCustomObject]@{
                                SerialNumber = $disk.SerialNumber
                                DiskModel    = $disk.Model
                                DriveLetter  = $logical.DeviceID
                                TotalSizeGB  = [math]::Round($logical.Size / 1GB, 2)
                                FreeSpaceGB  = [math]::Round($logical.FreeSpace / 1GB, 2)
                            }

                            $diskInfo += $diskObj
                            $totalSizeSum += [long]$logical.Size
                            $freeSizeSum += [long]$logical.FreeSpace
                        }
                    }
                }
            }

            # Add summary properties to the output object
            $ObjectOutput | Add-Member -MemberType NoteProperty -Name DisksJSON -Value ($diskInfo | ConvertTo-Json -Compress)
            $ObjectOutput | Add-Member -MemberType NoteProperty -Name DisksTotalSizeGB -Value ([math]::Round($totalSizeSum / 1GB, 2))
            $ObjectOutput | Add-Member -MemberType NoteProperty -Name DisksTotalFreeGB -Value ([math]::Round($freeSizeSum / 1GB, 2))


            # --- 6. Finalizing Loop ---
            $HWInfoArray += $ObjectOutput
        }
        catch
        {
            # Log the error and move to the next computer
            Write-RelaxedIT -logtext "Error while querying info for ""$Computer"": $($_.Exception.Message)" -Color Red
            # Add an object to the array indicating failure
            $ErrorObject = [PSCustomObject]@{
                ComputerName = $Computer.ToUpper()
                Status       = "Error: $($_.Exception.Message)"
                # Ensure all expected properties are present
                BIOSVersion = $null; SerialNumber = $null; Manufacturer = $null; Model = $null;
                SystemFamily = $null; CPUJSON = $null; RAM_GB = $null; ProductName = $null;
                CurrentBuildNumber = $null; DisplayVersion = $null;
                DisksJSON = $null; DisksTotalSizeGB = $null; DisksTotalFreeGB = $null
            }
            $HWInfoArray += $ErrorObject
        }
    }

    return $HWInfoArray
}
