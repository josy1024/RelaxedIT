
[CmdletBinding()]
param (
    [Parameter()]
    [string]
    $nextversion="0.0.7"
)
function Get-NextFixVersion {
    param (
        [string]$version
    )

    # Split the version string into an array
    $versionParts = $version -split '\.'

    # Increment the fix number (last part of the version)
    $versionParts[2] = [int]$versionParts[2] + 1

    # Join the parts back into a version string
    $newVersion = $versionParts -join '.'

    return $newVersion
}

. .\vars.ps1

Update-ModuleManifest -path ./$module/$module.psd1 -FunctionsToExport Test-$module, Get-ColorText, Get-ConfigfromJSON, Write-customLOG
Update-ModuleManifest -Path ./$module/$module.psd1 -ModuleVersion $nextversion

Test-Modulemanifest -path ./$module/$module.psd1  

$env:DOTNET_CLI_UI_LANGUAGE  = "en-US"
Publish-module -path ./$module/ -Repository "PSGallery" -Nugetapikey $key

$nextbuildversion = Get-NextFixVersion -version $nextversion
$currentScriptPath = $MyInvocation.MyCommand.Path

Write-Host "Prepare Next: $nextbuildversion ($currentScriptPath)"

$fileContent = Get-Content -Path $currentScriptPath

# Update the line containing the version number
$fileContent = $fileContent -replace "$nextversion","$nextbuildversion"

# Write the updated content back to the file
Set-Content -Path $currentScriptPath -Value $fileContent

Start-Sleep -Seconds 5

Find-Module -Name $module
