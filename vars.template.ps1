# powershell gallery key
# copy vars.template.ps1 to vars.ps1


$key = 'xxx'

$parameters = @{
    Path        = '.'
    NuGetApiKey = $key
    LicenseUri  = 'https://github.com/josy1024/RelaxedIT/blob/main/LICENSE'
    ReleaseNote = 'relaxed IT client management scripts'
}

# Publish-Module @parameters