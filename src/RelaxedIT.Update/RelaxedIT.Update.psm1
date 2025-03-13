# RelaxedIT.Update


function Test-RelaxedIT.Update {
    Write-RelaxedIT -logtext "Test-RelaxedIT.Update v0.0.35"
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

    Update-Module -Name "RelaxedIT*" -Force -Scope AllUsers
    
    #Fallback to install and update
    Update-RelaxedITModuleAndRemoveOld -ModuleNames @("RelaxedIT", "RelaxedIT.EnergySaver", "RelaxedIT.Update")

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
        return $hoursSinceLastRun.TotalHours -ge $maxHours
    } else {
       Write-RelaxedIT -LogText  "Timestamp file not found. Task will run for the first time."
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

   Write-RelaxedIT -LogText  "Timestamp updated at $LastrunTime."
}

function RelaxedIT.Resources.Install {
    param (
        [string]$Scope = "AllUsers"
    )

    # Define the modules to check and install
    $modules = @("Az.Resources", "Az.Storage", "AzTable")

    foreach ($module in $modules) {
        # Check if the module is installed
        if (-not (Get-Module -ListAvailable -Name $module)) {
            Write-RelaxedIT -LogText  "Module '$module' is not installed. Installing now..."
            Install-Module -Name $module -Force -Scope $Scope
        } else {
            Write-RelaxedIT -LogText  "Module '$module' is already installed."
        }
    }
}
# https://learn.microsoft.com/en-us/azure/storage/tables/table-storage-how-to-use-powershell
	
function RelaxedIT.Update.Task {
    param (
        [string]$LastrunTime = "C:\ProgramData\RelaxedIT\Update.Task.json"
    )

    Start-RelaxedLog -action "Update.Task"

    # Check if task should run using Compare-LastRun
    if (-not (Compare-LastRun -LastrunTime $LastrunTime -maxHours (7 * 24))) {
       Write-RelaxedIT -LogText  "Task was executed less than 7 days ago. Skipping."
        return
    }

    # Run the RelaxedIT.Update.All command
    RelaxedIT.Update.All
    RelaxedIT.Resources.Install

    # Update the timestamp
    Update-LastRunTime -LastrunTime $LastrunTime

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
    }
}
