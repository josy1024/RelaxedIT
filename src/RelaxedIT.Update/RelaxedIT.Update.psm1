# RelaxedIT.Update


function Test-RelaxedIT.Update {
    Write-RelaxedIT -logtext "Test-RelaxedIT.Update v0.0.68"
}

function RelaxedIT.Update.All {
    param (
        [string]$Scope = "AllUsers"
    )

    if ($Scope = "AllUsers")
    {
        if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
            Write-RelaxedIT -logtext "[ERR] Please run this script as an administrator or -`$scope CurrentUser"
            return
        }
    }

    #Update-Module -Name "RelaxedIT*" -Force -Scope AllUsers
    
    #Fallback to install and update
    Update-RelaxedITModuleAndRemoveOld -ModuleNames @("RelaxedIT", "RelaxedIT.Update", "RelaxedIT.EnergySaver", "RelaxedIT.Tools", "RelaxedIT.AzLog")

    Write-RelaxedIT -logtext "RelaxedIT.Update.All DONE"
}

function Compare-LastRun {
    param (
        [string]$LastrunTime,
        [int]$maxHours
    )
    # Check if the file exists
    if (Test-Path $LastrunTime) {
        # Read the last run time from the file
        $lastRunData = Get-Content $LastrunTime | ConvertFrom-Json
        $lastRunTimestamp = Get-Date $lastRunData.LastRun

        # Calculate the hours since the last run
        $hoursSinceLastRun = (Get-Date) - $lastRunTimestamp
        $skipcheck = ($hoursSinceLastRun.TotalHours -ge $maxHours)
        if ($skipcheck)
        {
            Write-RelaxedIT -LogText  ("[SKIP] Task was executed less than $maxhours hours ago. LastRunHours: " + $hoursSinceLastRun.TotalHours)
        }

        return ($skipcheck)
    } else {
       Write-RelaxedIT -LogText  "Timestamp file ""$LastrunTime"" not found."
       return $true
    }
}

function Update-LastRunTime {
    param (
        [string]$LastrunTime
    )

    # Ensure the folder exists
    $folderPath = Split-Path $LastrunTime
    if (-not (Test-Path $folderPath)) {
        New-Item -ItemType Directory -Path $folderPath -Force
    }

    # Update the timestamp in the file
    $timestampData = @{
        LastRun = (Get-Date).ToString("o") # ISO 8601 format
    } | ConvertTo-Json -Depth 1
    $timestampData | Set-Content -Path $LastrunTime -Force

   Write-RelaxedIT -LogText  "Timestamp updated to ""$timestampData"" at File: ""$LastrunTime""."
}

function RelaxedIT.Resources.Install {
    param (
        [string]$Scope = "AllUsers"
    )

    # Define the modules to check and install
    $modules = @("Az.Resources", "Az.Storage", "AzTable", "PSWindowsUpdate")

    

    foreach ($module in $modules) {
        # Check if the module is installed
        if (-not (Get-Module -ListAvailable -Name $module)) {
            Write-RelaxedIT -LogText  "Module '$module' is not installed. Installing now..."
            Install-Module -Name $module -Force -Scope $Scope
        } else {
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
	
function RelaxedIT.Resources.OneclickInstall {
    param (
        [string]$Scope = "AllUsers"
    )
    RelaxedIT.Resources.Install
    pwsh -c RelaxedIT.Update.All
    pwsh -c Relaxedit.Update.Task
    pwsh -c RelaxedIT.Update.Task.Install
}

function RelaxedIT.Update.Task {
    param (
        [string]$LastrunTime = "C:\ProgramData\RelaxedIT\Update.Task.json",
        [int]$writemode = 1,
        [int]$maxhours = 168
    )

    try {
        Start-RelaxedLog -action "Update.Task"

        if ($writemode -gt 1) {
            Write-RelaxedIT -LogText "Remove Timestamp file ""$LastrunTime""" -ForegroundColor Magenta
            remove-item -Path $LastrunTime -ErrorAction silentlycontinue
        }
        # Check if task should run using Compare-LastRun
        if (-not (Compare-LastRun -LastrunTime $LastrunTime -maxHours ($maxhours))) {
            $ret = RelaxedIT.AzLog.Run.Ping -action "Skip"
            return
        }
        $ret = RelaxedIT.AzLog.Run.Ping -action "Start"
    }
    catch {
        Write-RelaxedIT -logtext ("# Ping (" + ($MyInvocation.ScriptName.Split("\")[-1]) + ") """ + $MyInvocation.MyCommand.Name + """: " + $MyInvocation.PSCommandPath + ": " + $_.Exception.Message + $_.Exception.ItemName)  -ForegroundColor red
        Write-RelaxedIT -logtext ($_ | Format-List * -Force | Out-String) -ForegroundColor red
    }    

    # Run the RelaxedIT.Update.All command
    try {
        RelaxedIT.Update.All
    }
    catch {
        Write-RelaxedIT -logtext ("# RelaxedIT.Update.All(" + ($MyInvocation.ScriptName.Split("\")[-1]) + ") """ + $MyInvocation.MyCommand.Name + """: " + $MyInvocation.PSCommandPath + ": " + $_.Exception.Message + $_.Exception.ItemName)  -ForegroundColor red
        Write-RelaxedIT -logtext ($_ | Format-List * -Force | Out-String) -ForegroundColor red
    }    

    try {
        RelaxedIT.Resources.Install
    }
    catch {
        Write-RelaxedIT -logtext ("# RelaxedIT.Resources.Install(" + ($MyInvocation.ScriptName.Split("\")[-1]) + ") """ + $MyInvocation.MyCommand.Name + """: " + $MyInvocation.PSCommandPath + ": " + $_.Exception.Message + $_.Exception.ItemName)  -ForegroundColor red
        Write-RelaxedIT -logtext ($_ | Format-List * -Force | Out-String) -ForegroundColor red
    }    

    try {
        #RelaxedIT.3rdParty.upgrade
        Start-Process pwsh.exe -ArgumentList '-NoProfile -Command "Import-Module RelaxedIT.3rdParty; RelaxedIT.3rdParty.Update"'
    }
    catch {
        Write-RelaxedIT -logtext ("#     RelaxedIT.3rdParty.upgrade(" + ($MyInvocation.ScriptName.Split("\")[-1]) + ") """ + $MyInvocation.MyCommand.Name + """: " + $MyInvocation.PSCommandPath + ": " + $_.Exception.Message + $_.Exception.ItemName)  -ForegroundColor red
        Write-RelaxedIT -logtext ($_ | Format-List * -Force | Out-String) -ForegroundColor red
    }    


    # Update the timestamp
    Update-LastRunTime -LastrunTime $LastrunTime

    $ret = RelaxedIT.AzLog.Run.Ping -action "Done"
    Write-RelaxedIT "Task completed and timestamp updated."

}

function RelaxedIT.Update.Task.Install {

    # Define the scheduled task name
    $taskBaseName = "RelaxedIT Update Task"
    $taskName = "RelaxedIT\$taskBaseName"

    # Check if the task already exists and remove it

    if (Get-ScheduledTask -TaskName $taskBaseName -ErrorAction SilentlyContinue) {
        Write-RelaxedIT "Task '$taskName' already exists. Removing it..."
        Get-ScheduledTask -TaskName $taskBaseName | Unregister-ScheduledTask -Confirm:$false
        Write-RelaxedIT "Task '$taskName' has been removed."
    }

    $taskDescription = "Runs the RelaxedIT.Update.Task PowerShell command"
    $taskCommand = "pwsh.exe"
    $taskArguments = "-NoProfile -ExecutionPolicy Bypass -Command RelaxedIT.Update.Task"
    $taskTriggerTime = "00:20PM"  # Example: Set to run at 3:00 AM
    
    # Create a daily trigger
    $trigger = New-ScheduledTaskTrigger -Daily -At (Get-Date $taskTriggerTime)
    
    # Create a reboot trigger with a random delay of up to 1 hour
    $rebootTrigger = New-ScheduledTaskTrigger -AtStartup -RandomDelay (New-TimeSpan -Minutes 60)

    # Create an action to run the PowerShell command
    $action = New-ScheduledTaskAction -Execute $taskCommand -Argument $taskArguments
    
    # (Optional) Set up the task to run with highest privileges (admin rights)
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
        -StartWhenAvailable -RunOnlyIfNetworkAvailable -DontStopOnIdleEnd `
        -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Hours 1)
    
    # Register the scheduled task
    Register-ScheduledTask -TaskName $taskName -Description $taskDescription `
        -Trigger $trigger,$rebootTrigger -Action $action -Settings $settings `
        -User "SYSTEM" -RunLevel Highest
    
    Write-RelaxedIT -logtext  "Scheduled task '$taskName' has been successfully created."
    
}
# Define the scheduled task name and other parameters

function RelaxedIT.Install.All {
    param (
        [string]$Scope = "AllUsers"
    )

    if ($Scope = "AllUsers")
    {
        if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
            Write-RelaxedIT -logtext "[ERR] Please run this script as an administrator or -`$scope CurrentUser"
            return
        }
    }

    Install-Module -Name "RelaxedIT*" -Force -Scope $Scope
    
    Write-RelaxedIT -logtext "RelaxedIT.Install.All DONE"
}

Function Update-RelaxedITModuleAndRemoveOld {
    param (
        [string[]]$ModuleNames
    )

    foreach ($ModuleName in $ModuleNames) {
        Write-RelaxedIT -logtext "Update-RelaxedITModuleAndRemoveOld Module: ""$ModuleName""" 
        
        # Install or update the module
        Install-Module -Name $ModuleName -Force -Scope AllUsers -AllowClobber

        # Retrieve the latest version
        $LatestVersion = (Get-InstalledModule -Name $ModuleName).Version

        # Remove older versions, if any
        Get-InstalledModule -Name $ModuleName -AllVersions | Where-Object { $_.Version -ne $LatestVersion } | ForEach-Object {
            Write-RelaxedIT -logtext  "Removing old version: ""$($_.Version)"" of module ""$ModuleName"""
            Uninstall-Module -Name $_.Name -RequiredVersion $_.Version -Force
        }
        Import-Module -Name $ModuleName -Force -Scope AllUsers -AllowClobber
    }
}
