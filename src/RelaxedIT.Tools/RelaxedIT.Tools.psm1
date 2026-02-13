function Get-BasePath
{
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    # Resolve the base directory
    $BasePath = Split-Path -Path $Path -Parent
    return $BasePath
}



function Start-ElevatedPwsh
{
    # Prüfen, ob die aktuelle Sitzung als Administrator läuft
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)

    if (-not ($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)))
    {
        Write-RelaxedIT -logtext "Starting an elevated PowerShell session..." -ForegroundColor Yellow

        # Starte eine erhöhte PowerShell-Sitzung
        Start-Process -FilePath "pwsh.exe" -Verb RunAs

        Write-RelaxedIT -logtext "An elevated PowerShell session has been started." -ForegroundColor Green
    }
    else
    {
        Write-RelaxedIT -logtext "This session is already running with Administrator privileges." -ForegroundColor Cyan
    }
}


function Start-Adminpwsh
{
    param(
        [string]$Workspace = (Get-Location).Path,
        [switch]$NoProfile,
        [string[]]$ExtraArgs
    )

    # Prepare argument list
    $argList = @()
    if ($NoProfile) { $argList += '-NoProfile' }
    if ($ExtraArgs) { $argList += $ExtraArgs }

    Write-RelaxedIT -logtext "Starting elevated PowerShell in workspace '$Workspace'..." -ForegroundColor Yellow

    Start-Process -FilePath "pwsh.exe" -Verb RunAs -WorkingDirectory $Workspace -ArgumentList $argList

    Write-RelaxedIT -logtext "Elevated PowerShell started." -ForegroundColor Green
}


function Test-AndCreatePath
{
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    # Check if the path exists
    if (Test-Path -Path $Path)
    {
        Write-RelaxedIT -logtext "Path '$Path' already exists." -ForegroundColor Green -level 3
    }
    else
    {
        # Create the path
        Write-RelaxedIT -logtext "Path '$Path' does not exist. Creating it now..." -ForegroundColor Yellow
        New-Item -ItemType Directory -Path $Path | Out-Null
        Write-RelaxedIT -logtext "Path '$Path' has been created." -ForegroundColor Cyan
    }
}

function Update-InFileContent
{
    param (
        [Parameter(Mandatory = $true)]
        [string]$FilePath,   # The file to modify
        [Parameter(Mandatory = $true)]
        [string]$OldText,    # Text to be replaced
        [Parameter(Mandatory = $true)]
        [string]$NewText     # Replacement text
    )

    # Check if file exists
    if (-Not (Test-Path -Path $FilePath))
    {
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

    foreach ($Computer in $ComputerName)
    {
        # Helper variable for conditional CIM calls (Splatting)
        $CimParams = @{ ErrorAction = 'Stop' }
        if ($Computer -ne $Env:COMPUTERNAME)
        {
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
                ComputerName = $Computer.ToUpper()
                BIOSVersion  = $BIOS.SMBIOSBIOSVersion
                SerialNumber = $BIOS.SerialNumber
                Manufacturer = $System.Manufacturer
                Model        = $System.Model
                SystemFamily = $System.SystemFamily
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

            foreach ($disk in $disks)
            {
                # Get the partitions on the current physical disk
                $partitions = Get-CimInstance -ClassName Win32_DiskPartition @CimParams | Where-Object { $_.DiskIndex -eq $disk.Index }

                foreach ($partition in $partitions)
                {
                    # Get the link between the partition and the logical disk (volume)
                    # Note: We can often use Get-CimAssociatedInstance here, but for simplicity
                    # we will stick to the WMI chaining logic, ensuring CIM is used.
                    $link = Get-CimInstance -ClassName Win32_LogicalDiskToPartition @CimParams |
                    Where-Object { $_.Antecedent -like "*$($partition.DeviceID)*" }

                    if ($link)
                    {
                        # Extract drive letter (DeviceID property from Dependent string)
                        $driveLetter = ($link.Dependent -split '"')[1]
                        $logical = $logicalDisks | Where-Object { $_.DeviceID -eq $driveLetter }

                        if ($logical)
                        {
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
                Status = "Error: $($_.Exception.Message)"
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

function Convert-IpRangeToCidr
{
    param(
        [Parameter(Mandatory = $true)][string]$StartIP,
        [Parameter(Mandatory = $true)][string]$EndIP
    )

    # Convert IPv4 to UInt32
    function IPToUInt32([string]$ip)
    {
        $bytes = [System.Net.IPAddress]::Parse($ip).GetAddressBytes()
        [Array]::Reverse($bytes) # little-endian to match UInt32
        return [BitConverter]::ToUInt32($bytes, 0)
    }

    # Convert UInt32 to IPv4 string
    function UInt32ToIP([uint32]$int)
    {
        $bytes = [BitConverter]::GetBytes($int)
        [Array]::Reverse($bytes)
        return ([System.Net.IPAddress]::new($bytes)).ToString()
    }

    # Count trailing zero bits (0..32)
    function GetTrailingZeroCount([uint32]$value)
    {
        if ($value -eq 0) { return 32 }
        $count = 0
        while ((($value -shr $count) -band 1) -eq 0) { $count++ }
        return $count
    }

    # Highest power-of-two <= n, returns exponent (log2)
    function FloorLog2([uint64]$n)
    {
        $k = 0
        while ((1 -shl ($k + 1)) -le $n) { $k++ }
        return $k
    }

    $start = IPToUInt32 $StartIP
    $end = IPToUInt32 $EndIP

    if ($start -gt $end) { throw "StartIP must be <= EndIP." }

    $cidrs = @()

    while ($start -le $end)
    {
        # Alignment-constrained prefix
        $tz = GetTrailingZeroCount $start           # alignment in bits
        $prefixAlign = 32 - $tz

        # Remaining-size-constrained prefix
        $remaining = [uint64]($end - $start + 1)
        $exp = FloorLog2 $remaining                 # block size exponent
        $prefixSize = 32 - [int]$exp

        # Take the stricter (larger) prefix length
        $prefix = [Math]::Max($prefixAlign, $prefixSize)

        # Emit block
        $cidrs += "$(UInt32ToIP $start)/$prefix"

        # Advance by block size
        $blockSize = [uint32](1 -shl (32 - $prefix))
        $start = $start + $blockSize
    }

    return $cidrs
}

function New-AustriaFirewallRules
{
    <#
.SYNOPSIS
Creates Windows Firewall rules to allow the Minecraft Bedrock Server.

.PARAMETER Name
The base name for the firewall rules (e.g., "Minecraft").

.PARAMETER MinecraftExePath
The full path to the server executable file.

.EXAMPLE
    New-MinecraftFirewallRules -Name "BedrockServer" -MinecraftExePath "D:\Servers\bedrock_server.etxe" -Ports 25565
    New-MinecraftFirewallRules -Name "Minecraft" -MinecraftExePath "C:\MineCraft\bedrock-server-latest\bedrock_server.exe" -Ports @(19132, 19133)
    New-MinecraftFirewallRules -Name "MinecraftJAVA" -MinecraftExePath "C:\MineCraft\java-server\bedrock_server.exe" -Ports @(25565, 25575, 19132, 19133)
#>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name = "Minecraft",

        [Parameter(Mandatory = $true)]
        [string]$MinecraftExePath = "C:\MineCraft\bedrock-server\bedrock_server.exe",

        [Parameter(Mandatory = $true)]
        [int[]]$Ports = @(25565, 25575, 19132, 19133),
        [Parameter(Mandatory = $false)]
        [string]$ipfile = "at.csv"
        # https://www.nirsoft.net/countryip/at.html
    )


    $AustriaIPs = @()
    # Path to at.csv is assumed to be relative to where the script is run
    $CsvPath = Join-Path (Split-Path $MyInvocation.MyCommand.Path) $ipfile

    if (-not (Test-Path $CsvPath))
    {
        Write-RelaxedIT -logtext "ERROR: The required IP CSV file '$ipfile' was not found at '$CsvPath'. Returning without creating rules."
        return
    }

    Import-Csv $CsvPath -Header StartIP, EndIP, Count, Date, Provider | ForEach-Object {
        $AustriaIPs += Convert-IpRangeToCidr -StartIP $_.StartIP -EndIP $_.EndIP
    }

    Write-RelaxedIT -logtext "ℹ️ Found $($AustriaIPs.count) CIDR blocks for Austria IPs."

    # Internal/private ranges (RFC1918)
    $InternalIPs = @(
        "10.0.0.0/8",
        "172.16.0.0/12",
        "192.168.0.0/16"
    )

    # Cleanup old rules
    Write-RelaxedIT -logtext "Cleaning up old firewall rules prefixed with '$Name'..."
    Get-NetFirewallRule -DisplayName "$Name Austria Public TCP" -ErrorAction SilentlyContinue | Remove-NetFirewallRule -Confirm:$false
    Get-NetFirewallRule -DisplayName "$Name Austria Public UDP" -ErrorAction SilentlyContinue | Remove-NetFirewallRule -Confirm:$false
    Get-NetFirewallRule -DisplayName "$Name Internal TCP" -ErrorAction SilentlyContinue | Remove-NetFirewallRule -Confirm:$false
    Get-NetFirewallRule -DisplayName "$Name Internal UDP" -ErrorAction SilentlyContinue | Remove-NetFirewallRule -Confirm:$false
    Write-RelaxedIT -logtext "Cleanup complete."

    # Austria rules (Public profile only)
    Write-RelaxedIT -logtext "Adding rules for Public Profile (Austria IPs)..."
    New-NetFirewallRule `
        -DisplayName "$Name Austria Public TCP" `
        -Direction Inbound `
        -Program $MinecraftExePath `
        -Action Allow `
        -Profile Public `
        -RemoteAddress $AustriaIPs `
        -Protocol TCP `
        -LocalPort $Ports

    New-NetFirewallRule `
        -DisplayName "$Name Austria Public UDP" `
        -Direction Inbound `
        -Program $MinecraftExePath `
        -Action Allow `
        -Profile Public `
        -RemoteAddress $AustriaIPs `
        -Protocol UDP `
        -LocalPort $Ports

    # Internal rules (Private + Domain profiles)
    Write-RelaxedIT -logtext "Adding rules for Private/Domain Profiles (Internal IPs)..."
    New-NetFirewallRule `
        -DisplayName "$Name Internal TCP" `
        -Direction Inbound `
        -Program $MinecraftExePath `
        -Action Allow `
        -Profile Private, Domain `
        -RemoteAddress $InternalIPs `
        -Protocol TCP `
        -LocalPort $Ports

    New-NetFirewallRule `
        -DisplayName "$Name Internal UDP" `
        -Direction Inbound `
        -Program $MinecraftExePath `
        -Action Allow `
        -Profile Private, Domain `
        -RemoteAddress $InternalIPs `
        -Protocol UDP `
        -LocalPort $Ports

    Write-RelaxedIT -logtext "✅ Firewall rules for $Name Server created successfully for ports $($Ports -join ', ')."
}

function Out-NetworkTestPretty
{
    param (
        # The input object is the hostname/IP string
        [Parameter(ValueFromPipeline = $true)]
        [string]$Target,

        # Switch to force IPv6 test for hostnames or addresses
        [switch]$IPv6
    )

    # "172.17.17.17"  | Out-NetworkTestPretty
    # Error handling for empty input
    if (-not $Target)
    {
        return
    }

    # Set parameters for Test-Connection
    $TestParams = @{
        Count          = 1
        ErrorAction    = 'SilentlyContinue'
        TimeoutSeconds = 1
    }

    # Add -IPv6 if the switch is present
    if ($IPv6)
    {
        $TestParams.Add('IPv6', $true)
    }

    # Perform the test, using -ComputerName instead of -Destination
    $PingResult = Test-Connection -ComputerName $Target @TestParams

    # Status determination (Check if any reply was received)
    if ($PingResult)
    {
        # Test-Connection returns an array of PingReply objects (even for -Count 1)
        # We need the first element's status/properties
        $FirstReply = $PingResult | Select-Object -First 1

        if ($FirstReply.Status -eq 'Success')
        {
            $Status = "OK"
            $Latency = "$($FirstReply.Latency)ms"
            # Use the resolved IP if available, otherwise the target name
            $Address = $FirstReply.Address.IPAddressToString -or $Target
        }
        else
        {
            # Test-Connection ran but failed (e.g., 'TimedOut', 'DestinationHostUnreachable')
            $Status = "DOWN (Status: $($FirstReply.Status))"
            if ($IPv6)
            {
                $Status += " ipv6"
            }
            $Latency = ""
            $Address = $Target # Use the original target name
        }
    }
    else
    {
        # No object was returned (Test-Connection failed completely/SilentlyContinue)
        $Status = "DOWN (No Response)"
        $Latency = ""
        $Address = $Target # Use the original target name
    }

    Write-RelaxedIT "  $Target $Address Status: $Status $Latency"
}

function Get-RelaxedProcessStatus
{
    $pids = $env:rit_processes -split ',' | Where-Object { $_ -match '^\d+$' }

    if (-not $pids)
    {
        Write-RelaxedIT -LogText "Keine gespeicherten Prozesse gefunden." -ForegroundColor Yellow
        return $false
    }

    $einerlaueftnoch = $false
    foreach ($ritpid in $pids)
    {
        $proc = Get-Process -Id $ritpid -ErrorAction SilentlyContinue
        if ($proc)
        {
            Write-RelaxedIT -LogText "Prozess $ritpid läuft noch (Name: $($proc.ProcessName)) $($proc.CommandLine))" -ForegroundColor Green
            Write-RelaxedIT -LogText $proc
            $einerlaueftnoch = $true
        }
        else
        {
            Write-RelaxedIT -LogText "Prozess $ritpid ist beendet oder existiert nicht mehr." -ForegroundColor Red
        }
    }
    return $einerlaueftnoch
}

function Invoke-RelaxedSubScript
{
    <#

    $subScripts = @("script1.ps1", "script2.ps1")
	foreach ($script in $subScripts)
	{
		Invoke-RelaxedSubScript -Interpreter "powershell" -ScriptName $script
	}

    Wait-RelaxedProcesses -loop 30 -text "coho"

    #>
    param (
        [string]$Interpreter = "pwsh",
        [string]$ScriptName
    )

    $root = if ($PSScriptRoot) { $PSScriptRoot } else { Get-Location }
    $scriptPath = Join-Path -Path $root -ChildPath $ScriptName
    Write-RelaxedIT -logtext "Invoke-RelaxedSubScript: $Interpreter : '$scriptPath'" -NoNewline
    #   Start-Process $Interpreter -ArgumentList "-File `"$scriptPath`""

    $proc = Start-Process $Interpreter -ArgumentList "-File `"$scriptPath`"" -PassThru
    $ritpid = $proc.Id

    # Hole bestehende Liste und erweitere sie
    $currentPIDs = "" + $env:rit_processes #-split ',' | Where-Object { $_ -ne '' }
    $newpids = "" + $ritpid + "," + $currentPIDs
    Write-RelaxedIT -logtext (" [Proc.Id]: $newpids") -noWriteDate
    $env:rit_processes = $newpids
}


function Reset-RelaxedProcesses
{
    $env:rit_processes = ''
    Write-RelaxedIT -logtext "rit-processes wurde zurückgesetzt." -ForegroundColor Cyan
}

function Wait-RelaxedProcesses
{
    param (
        [int]$loop = 30,
        [string]$text = ""
    )

    $finished = $false

    Write-RelaxedIT -logtext "=== Check: Wait-Processes $text MAX: $loop ===" -ForegroundColor Cyan

    for ($i = 0; $i -lt $loop; $i++)
    {
        if (Get-RelaxedProcessStatus)
        {
            Write-RelaxedIT -logtext "$i." -noWriteDate -NoNewline -ForegroundColor cyan
            Start-Sleep -Seconds 10
        }
        else
        {
            $finished = $true
            break
        }
    }
    Reset-FitProcesses
    if (!$finished)
    {
        $pids = $env:rit_processes -split ',' | Where-Object { $_ -match '^\d+$' }
        Write-RelaxedIT "[WRN]Wait-RelaxedProcesses:-notfinishedintime-$env:computername-max$loop-pids-$pids-$text"
        Write-RelaxedIT -logtext "$i." -noWriteDate -NoNewline -ForegroundColor cyan
    }

}
