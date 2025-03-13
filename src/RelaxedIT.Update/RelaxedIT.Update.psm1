# RelaxedIT.Update


function Test-RelaxedIT.Update {
    Write-RelaxedIT -logtext "Test-RelaxedIT.Update v0.0.29"
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
