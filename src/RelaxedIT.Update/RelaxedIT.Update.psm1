# RelaxedIT.Update


function Test-RelaxedIT.Update
{
    Write-RelaxedIT -logtext "Test-RelaxedIT.Update v0.0.97"
}

function RelaxedIT.Update.All
{
    param (
        [string]$Scope = "AllUsers"
    )

    if ($Scope -eq "AllUsers")
    {
        if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
        {
            Write-RelaxedIT -logtext "[ERR] Please run this script as an administrator or -`$scope CurrentUser"
            return
        }
    }

    #Update-Module -Name "RelaxedIT*" -Force -Scope AllUsers

    #Fallback to install and update
    Update-RelaxedITModuleAndRemoveOld -ModuleNames @("RelaxedIT", "RelaxedIT.Update", "RelaxedIT.EnergySaver", "RelaxedIT.Tools", "RelaxedIT.AzLog", "RelaxedIT.3rdparty")
    Write-RelaxedIT -logtext "RelaxedIT.Update.All RelaxedIT modules updated and old versions removed."

    # not reliable/hangs?!?
    # Update-PSResource Az -Scope AllUsers -Confirm:$true
    # Write-RelaxedIT -logtext "RelaxedIT.Update.All DONE"
}

function Compare-LastRun
{
    param (
        [string]$LastrunTime,
        [int]$maxHours
    )
    # Check if the file exists
    if (Test-Path $LastrunTime)
    {
        # Read the last run time from the file
        try
        {
            $lastRunData = Get-Content $LastrunTime | ConvertFrom-Json
            $lastRunTimestamp = Get-Date $lastRunData.LastRun

            # Calculate the hours since the last run
            $hoursSinceLastRun = (Get-Date) - $lastRunTimestamp
            $hours = [math]::Round($hoursSinceLastRun.TotalHours, 2)

            # If it ran less than $maxHours ago, skip (return $false)
            if ($hours -lt $maxHours)
            {
                Write-RelaxedIT -LogText  ("[SKIP] Task was executed less than $maxHours hours ago. LastRunHours: " + $hours)
                return $false
            }

            return $true
        }
        catch
        {
            Write-RelaxedIT -LogText ("[ERR] Compare-LastRun: failed to parse timestamp from file $LastrunTime " + $_.Exception.Message) -ForegroundColor Red
            Write-RelaxedIT -LogText  "[WRN] Proceeding with run."
            return $true
        }
    }
    else
    {
        Write-RelaxedIT -LogText  "Timestamp file ""$LastrunTime"" not found. Proceeding with run."
        return $true
    }
}

function Update-LastRunTime
{
    param (
        [string]$LastrunTime
    )

    # Ensure the folder exists
    $folderPath = Split-Path $LastrunTime
    if (-not (Test-Path $folderPath))
    {
        New-Item -ItemType Directory -Path $folderPath -Force
    }

    # Update the timestamp in the file
    $timestampData = @{
        LastRun = (Get-Date).ToString("o") # ISO 8601 format
    } | ConvertTo-Json -Depth 1
    $timestampData | Set-Content -Path $LastrunTime -Force

    Write-RelaxedIT -LogText  "Timestamp updated to ""$timestampData"" at File: ""$LastrunTime""."
}

function RelaxedIT.Resources.Install
{
    param (
        [string]$Scope = "AllUsers"
    )

    # Define the modules to check and install
    $modules = @("Az.Resources", "Az.Storage", "AzTable", "PSWindowsUpdate")


    #DAUERT EWIG => CHOCO! Install-Package Azure.Data.Tables -ProviderName NuGet -Scope $Scope -Force -Confirm:$false -ErrorAction SilentlyContinue

    foreach ($module in $modules)
    {
        # Check if the module is installed
        if (-not (Get-Module -ListAvailable -Name $module))
        {
            Write-RelaxedIT -LogText  "Module '$module' is not installed. Installing now..."
            Install-Module -Name $module -Force -Scope $Scope
        }
        else
        {
            Write-RelaxedIT -LogText  "Module '$module' is already installed."
        }
    }

    if (!(test-path -path "C:\ProgramData\chocolatey"))
    {
        Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    }

    # TODO: test pwsh7 installed or pwsh7 shell?
    if (!(test-path -path "C:\Program Files\PowerShell\7\pwsh.exe"))
    {
        choco install pwsh -y
    }

}
# https://learn.microsoft.com/en-us/azure/storage/tables/table-storage-how-to-use-powershell

function RelaxedIT.Resources.OneclickInstall
{
    param (
        [string]$Scope = "AllUsers"
    )
    RelaxedIT.Resources.Install -Scope $Scope

    try
    {
        & pwsh -NoProfile -Command "Import-Module RelaxedIT; RelaxedIT.Update.All -Scope '$Scope'"
    }
    catch
    {
        Write-RelaxedIT -LogText ("[ERR] Could not run RelaxedIT.Update.All: " + $_.Exception.Message) -ForegroundColor Red
    }

    try
    {
        & pwsh -NoProfile -Command "Import-Module RelaxedIT; RelaxedIT.Update.Task"
    }
    catch
    {
        Write-RelaxedIT -LogText ("[ERR] Could not run RelaxedIT.Update.Task: " + $_.Exception.Message) -ForegroundColor Red
    }

    try
    {
        & pwsh -NoProfile -Command "Import-Module RelaxedIT; RelaxedIT.Update.Task.Install"
    }
    catch
    {
        Write-RelaxedIT -LogText ("[ERR] Could not run RelaxedIT.Update.Task.Install: " + $_.Exception.Message) -ForegroundColor Red
    }
}

function RelaxedIT.Update.Task
{
    param (
        [string]$LastrunTime = "C:\ProgramData\RelaxedIT\Update.Task.json",
        [int]$writemode = 1,
        [int]$maxhours = 72
    )



    # Run the RelaxedIT.Update.All command
    try
    {
        Start-RelaxedLog -action "Update.Task"
        Write-RelaxedIT -logtext "RelaxedIT.Update.All"
        RelaxedIT.Update.All
    }
    catch
    {
        Write-RelaxedIT -logtext ("# RelaxedIT.Update.All(" + ($MyInvocation.ScriptName.Split("\")[-1]) + ") """ + $MyInvocation.MyCommand.Name + """: " + $MyInvocation.PSCommandPath + ": " + $_.Exception.Message + $_.Exception.ItemName)  -ForegroundColor red
        Write-RelaxedIT -logtext ($_ | Format-List * -Force | Out-String) -ForegroundColor red
    }

    try
    {
        Write-RelaxedIT -logtext "RelaxedIT.Resources.Install"
        RelaxedIT.Resources.Install
    }
    catch
    {
        Write-RelaxedIT -logtext ("# RelaxedIT.Resources.Install(" + ($MyInvocation.ScriptName.Split("\")[-1]) + ") """ + $MyInvocation.MyCommand.Name + """: " + $MyInvocation.PSCommandPath + ": " + $_.Exception.Message + $_.Exception.ItemName)  -ForegroundColor red
        Write-RelaxedIT -logtext ($_ | Format-List * -Force | Out-String) -ForegroundColor red
    }

    try
    {
        Write-RelaxedIT -logtext "RelaxedIT.AzLogPackage"
        Install-RelaxedITAzLogPackage
    }
    catch
    {
        Write-RelaxedIT -logtext ("# RelaxedIT.Install-RelaxedITAzLogPackage(" + ($MyInvocation.ScriptName.Split("\")[-1]) + ") """ + $MyInvocation.MyCommand.Name + """: " + $MyInvocation.PSCommandPath + ": " + $_.Exception.Message + $_.Exception.ItemName)  -ForegroundColor red
        Write-RelaxedIT -logtext ($_ | Format-List * -Force | Out-String) -ForegroundColor red
    }

    try
    {
        Write-RelaxedIT -logtext "Update.Task"

        if ($writemode -gt 1)
        {
            Write-RelaxedIT -LogText "Remove Timestamp file ""$LastrunTime""" -ForegroundColor Magenta
            remove-item -Path $LastrunTime -ErrorAction silentlycontinue
        }
        # Check if task should run using Compare-LastRun
        if (-not (Compare-LastRun -LastrunTime $LastrunTime -maxHours ($maxhours)))
        {
            $ret = RelaxedIT.AzLog.Run.Ping -action "Skip"
            return
        }
        $ret = RelaxedIT.AzLog.Run.Ping -action "Start"
    }
    catch
    {
        Write-RelaxedIT -logtext ("# Ping (" + ($MyInvocation.ScriptName.Split("\")[-1]) + ") """ + $MyInvocation.MyCommand.Name + """: " + $MyInvocation.PSCommandPath + ": " + $_.Exception.Message + $_.Exception.ItemName)  -ForegroundColor red
        Write-RelaxedIT -logtext ($_ | Format-List * -Force | Out-String) -ForegroundColor red
    }

    try
    {
        #RelaxedIT.3rdParty.upgrade
        Start-Process pwsh.exe -ArgumentList '-NoProfile -Command "Import-Module RelaxedIT.3rdParty; RelaxedIT.3rdParty.Update"'
    }
    catch
    {
        Write-RelaxedIT -logtext ("#     RelaxedIT.3rdParty.upgrade(" + ($MyInvocation.ScriptName.Split("\")[-1]) + ") """ + $MyInvocation.MyCommand.Name + """: " + $MyInvocation.PSCommandPath + ": " + $_.Exception.Message + $_.Exception.ItemName)  -ForegroundColor red
        Write-RelaxedIT -logtext ($_ | Format-List * -Force | Out-String) -ForegroundColor red
    }


    # Update the timestamp
    Update-LastRunTime -LastrunTime $LastrunTime

    $ret = RelaxedIT.AzLog.Run.Ping -action "Done"
    Write-RelaxedIT "Task completed and timestamp updated."

    # TODO driver updates
    RelaxedIT.3rdParty.WindowsDrivers

    # 3rd party updates!
    #    RelaxedIT.3rdParty.Update
}

function RelaxedIT.Update.Task.Install
{

    # Define the scheduled task name
    $taskBaseName = "RelaxedIT Update Task"
    $taskName = "RelaxedIT\$taskBaseName"
    # Check if the task already exists and remove it
    if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue)
    {
        Write-RelaxedIT "Task '$taskName' already exists. Removing it..."
        Get-ScheduledTask -TaskName $taskName | Unregister-ScheduledTask -Confirm:$false
        Write-RelaxedIT "Task '$taskName' has been removed."
    }

    $taskDescription = "Runs the RelaxedIT.Update.Task PowerShell command"
    $taskCommand = "pwsh.exe"
    $taskArguments = "-NoProfile -ExecutionPolicy Bypass -Command RelaxedIT.Update.Task"

    # Create a daily trigger (run at 00:20)
    $taskTriggerTime = (Get-Date).Date.AddHours(0).AddMinutes(20)
    $trigger = New-ScheduledTaskTrigger -Daily -At $taskTriggerTime

    # Create a reboot trigger with a random delay of up to 1 hour
    $rebootTrigger = New-ScheduledTaskTrigger -AtStartup -RandomDelay (New-TimeSpan -Minutes 60)

    # Create an action to run the PowerShell command
    $action = New-ScheduledTaskAction -Execute $taskCommand -Argument $taskArguments

    # (Optional) Set up the task to run with highest privileges (admin rights)
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
        -StartWhenAvailable -RunOnlyIfNetworkAvailable -DontStopOnIdleEnd `
        -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Hours 1)

    # Register the scheduled task
    try
    {
        Register-ScheduledTask -TaskName $taskName -Description $taskDescription `
            -Trigger $trigger, $rebootTrigger -Action $action -Settings $settings `
            -User "SYSTEM" -RunLevel Highest

        Write-RelaxedIT -logtext  "Scheduled task '$taskName' has been successfully created."
    }
    catch
    {
        Write-RelaxedIT -logtext ("[ERR] Could not register scheduled task: " + $_.Exception.Message) -ForegroundColor Red
    }

}
# Define the scheduled task name and other parameters

function RelaxedIT.Install.All
{
    param (
        [string]$Scope = "AllUsers"
    )

    if ($Scope -eq "AllUsers")
    {
        if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
        {
            Write-RelaxedIT -logtext "[ERR] Please run this script as an administrator or use -Scope CurrentUser"
            return
        }
    }

    try
    {
        Install-Module -Name "RelaxedIT" -Force -Scope $Scope -AllowClobber -ErrorAction Stop
        Install-Module -Name "RelaxedIT.Update" -Force -Scope $Scope -AllowClobber -ErrorAction Stop
        Write-RelaxedIT -logtext "RelaxedIT.Install.All DONE"
    }
    catch
    {
        Write-RelaxedIT -logtext ("[ERR] RelaxedIT.Install.All failed: " + $_.Exception.Message) -ForegroundColor Red
    }
}

Function Update-RelaxedITModuleAndRemoveOld
{
    param (
        [string[]]$ModuleNames,
        [string]$Scope = 'AllUsers'
    )

    foreach ($ModuleName in $ModuleNames)
    {
        Write-RelaxedIT -logtext "Update-RelaxedITModuleAndRemoveOld Module: '$ModuleName'"

        try
        {
            Install-Module -Name $ModuleName -Force -Scope $Scope -AllowClobber -ErrorAction Stop
        }
        catch
        {
            Write-RelaxedIT -logtext ("[ERR] Failed to install/update module $ModuleName " + $_.Exception.Message) -ForegroundColor Red
            continue
        }

        try
        {
            $installed = Get-InstalledModule -Name $ModuleName -ErrorAction SilentlyContinue
            if (-not $installed)
            {
                Write-RelaxedIT -logtext ("[WARN] Installed module $ModuleName not found after install.")
                continue
            }

            $LatestVersion = $installed.Version

            $older = Get-InstalledModule -Name $ModuleName -AllVersions | Where-Object { $_.Version -ne $LatestVersion }
            foreach ($old in $older)
            {
                Write-RelaxedIT -logtext  "Removing old version: ""$($old.Version)"" of module ""$ModuleName"""
                try { Uninstall-Module -Name $ModuleName -RequiredVersion $old.Version -Force -ErrorAction SilentlyContinue } catch { Write-RelaxedIT -logtext ("[WARN] Could not remove old version: " + $_.Exception.Message) -ForegroundColor Yellow }
            }
        }
        catch
        {
            Write-RelaxedIT -logtext ("[ERR] Error while cleaning old versions of $ModuleName " + $_.Exception.Message) -ForegroundColor Red
        }
    }
}


function Test-RelaxedITCompareLastRun
{
    <#
    .SYNOPSIS
        Prüft die Compare-LastRun-Logik mit mehreren Testfällen.
    .DESCRIPTION
        Legt temporäre Timestamp-Dateien an und vergleicht das Ergebnis von Compare-LastRun.
        Gibt am Ende $true zurück, wenn alle Tests erfolgreich sind, sonst $false.
    #>

    param (
        [string]$LastrunTime = "C:\ProgramData\RelaxedIT\Update.Task.json",
        [int]$MaxHours = 72
    )

    $TempDir = Split-Path -Path $LastrunTime
    if (-not (Test-Path $TempDir)) { New-Item -ItemType Directory -Path $TempDir -Force | Out-Null }

    $failures = @()

    # Case A: Missing file -> should return $true (proceed)
    $fileA = Join-Path $TempDir "missing.json"
    if (Test-Path $fileA) { Remove-Item $fileA -Force }
    $resA = Compare-LastRun -LastrunTime $fileA -maxHours $MaxHours
    if (-not $resA) { $failures += "MissingFile expected true, got false" }

    # Case B: Recent run (1 hour ago) -> should return $false (skip)
    $fileB = Join-Path $TempDir "recent.json"
    $payloadB = @{ LastRun = ((Get-Date).AddHours(-1)).ToString("o") } | ConvertTo-Json
    $payloadB | Set-Content -Path $fileB -Force
    $resB = Compare-LastRun -LastrunTime $fileB -maxHours $MaxHours
    if ($resB) { $failures += "RecentRun expected false, got true" }

    # Case C: Old run (100 hours ago) -> should return $true (proceed)
    $fileC = Join-Path $TempDir "old.json"
    $payloadC = @{ LastRun = ((Get-Date).AddHours(-100)).ToString("o") } | ConvertTo-Json
    $payloadC | Set-Content -Path $fileC -Force
    $resC = Compare-LastRun -LastrunTime $fileC -maxHours $MaxHours
    if (-not $resC) { $failures += "OldRun expected true, got false" }

    # Case D: Malformed JSON -> should return $true (proceed, error handled)
    $fileD = Join-Path $TempDir "malformed.json"
    "{ NotAValidJson }" | Set-Content -Path $fileD -Force
    $resD = Compare-LastRun -LastrunTime $fileD -maxHours $MaxHours
    if (-not $resD) { $failures += "MalformedJSON expected true, got false" }

    # Clean up temp files
    # Remove-Item (Join-Path $TempDir "*") -ErrorAction SilentlyContinue

    if ($failures.Count -eq 0)
    {
        Write-RelaxedIT -LogText "Test-CompareLastRun: ALL TESTS PASSED"
        return $true
    }
    else
    {
        Write-RelaxedIT -LogText ("Test-CompareLastRun: FAILURES: " + ($failures -join "; ")) -ForegroundColor Red
        return $false
    }
}
