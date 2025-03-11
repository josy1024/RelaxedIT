# RelaxedIT.Update


function Test-RelaxedIT.Update {
    Write-customLOG -logtext "Test-RelaxedIT.Update v0.0.26"
}

function RelaxedIT.Update.All {
    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-customLOG -logtext "[ERR] Please run this script as an administrator."
        return
    }

    Update-Module -Name "RelaxedIT*" -Force -Scope AllUsers
    
    #Fallback to install and update
    Update-RelaxedITModuleAndRemoveOld -ModuleNames @("RelaxedIT", "RelaxedIT.EnergySaver", "RelaxedIT.Update")

    Write-customLOG -logtext "RelaxedIT.Update.All"
}


Function Update-RelaxedITModuleAndRemoveOld {
    param (
        [string[]]$ModuleNames
    )

    foreach ($ModuleName in $ModuleNames) {
        Write-customLOG -logtext "Update-RelaxedITModuleAndRemoveOld Module: ""$ModuleName""" 
        
        # Install or update the module
        Install-Module -Name $ModuleName -Force -Scope AllUsers -AllowClobber

        # Retrieve the latest version
        $LatestVersion = (Get-InstalledModule -Name $ModuleName).Version

        # Remove older versions, if any
        Get-InstalledModule -Name $ModuleName -AllVersions | Where-Object { $_.Version -ne $LatestVersion } | ForEach-Object {
            Write-customLOG -logtext  "Removing old version: ""$($_.Version)"" of module ""$ModuleName"""
            Uninstall-Module -Name $_.Name -RequiredVersion $_.Version -Force
        }
    }

    Write-Host "Update and cleanup complete!" -ForegroundColor
}
