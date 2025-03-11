# RelaxedIT.Update


function Test-RelaxedIT.Update {
    Write-customLOG -logtext "Test-RelaxedIT.Update"
}

function RelaxedIT.Update.All {
    #test if user is admin?

    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-customLOG -logtext "[ERR] Please run this script as an administrator."
        return
    }


    Install-module RelaxedIT -Force -Scope AllUsers -AllowClobber
    Install-Module RelaxedIT.EnergySaver -Force -Scope AllUsers -AllowClobber
    Install-Module RelaxedIT.Update -Force -Scope AllUsers -AllowClobber

    Write-customLOG -logtext "RelaxedIT.Update.All"
}


