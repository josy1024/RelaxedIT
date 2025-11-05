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

	#>

	[CmdletBinding(SupportsShouldProcess = $True)]
	Param(
		[Parameter(Mandatory = $False, Position = 1)]
		[string[]]$ComputerName = $Env:COMPUTERNAME
		)

	$HWInfoArray = @()

	foreach($Computer in $ComputerName)
	{
		Write-RelaxedIT -logtext "Query Hardware Infos for ""$Computer""..."

		try
		{
			$ObjectOutput = "" | Select-Object ComputerName, BIOSVersion, SerialNumber, Manufacturer, Model, SystemFamily
			$Win32_BIOS_Object = Get-WMIObject -Class Win32_BIOS -ComputerName $Computer -ErrorAction Stop
			if($Computer -eq $Env:COMPUTERNAME)
			{
					$Win32_ComputerSystem_Object = Get-CimInstance -ClassName Win32_ComputerSystem
			}
			else
			{
				$Win32_ComputerSystem_Object = Get-CimInstance -ClassName Win32_ComputerSystem -ComputerName $Computer -ErrorAction Stop
			}
			$ObjectOutput.ComputerName = $Computer.ToUpper()
			$ObjectOutput.BIOSVersion = $Win32_BIOS_Object.SMBIOSBIOSVersion
			$ObjectOutput.SerialNumber = $Win32_BIOS_Object.SerialNumber
			$ObjectOutput.Manufacturer = $Win32_ComputerSystem_Object.Manufacturer
			$ObjectOutput.Model = $Win32_ComputerSystem_Object.Model
			$ObjectOutput.SystemFamily = $Win32_ComputerSystem_Object.SystemFamily

			$HWInfoArray += $ObjectOutput
		}
		catch
		{
			Write-RelaxedIT -logtext "Error while query bios version for ""$Computer""!" -Color Red
		}
	}

    $HWInfoArray | Add-Member -MemberType NoteProperty -Name Key -Value $env:COMPUTERNAME

    $cpu_info = Get-WmiObject -Class Win32_Processor | Select-Object -Property Name, NumberOfCores, NumberOfLogicalProcessors | convertto-json
	$HWInfoArray | Add-Member -MemberType NoteProperty -Name CPUJSON -Value $cpu_info

        # Get RAM information
    $ram_info = Get-WmiObject -Class Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum
    $ramGB = $([math]::round($ram_info.Sum / 1GB, 2))
	$HWInfoArray | Add-Member -MemberType NoteProperty -Name RAM_GB -Value $ramGB

	# OS details
	$displayVersion = (Get-ItemProperty -Path 'HKLM:\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion').DisplayVersion
	$HWInfoArray | Add-Member -MemberType NoteProperty -Name displayVersion -Value $displayVersion

	$productName = (Get-CimInstance -ClassName Win32_OperatingSystem).Caption
	$HWInfoArray | Add-Member -MemberType NoteProperty -Name productName -Value $productName

	$currentBuildNumber = (Get-ItemProperty -Path 'HKLM:\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion').CurrentBuildNumber
	$HWInfoArray | Add-Member -MemberType NoteProperty -Name currentBuildNumber -Value $currentBuildNumber

	return $HWInfoArray
}