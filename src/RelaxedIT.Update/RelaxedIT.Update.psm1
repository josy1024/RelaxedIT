# RelaxedIT.Update


function Test-RelaxedIT.Update {
    Write-customLOG -logtext "Test-RelaxedIT.Update"
}

function RelaxedIT.Update.All {

    Install-module RelaxedIT -Force -Scope AllUsers -AllowClobber
    Install-Module RelaxedIT.EnergySaver -Force -Scope AllUsers -AllowClobber
    Install-Module RelaxedIT.Update -Force -Scope AllUsers -AllowClobber

    Write-customLOG -logtext "Test-RelaxedIT.Update"
}


