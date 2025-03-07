
[CmdletBinding()]
param (
    [Parameter()]
    [string]
    $nextversion="0.0.15"
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

function Update-VersionInScript {
    param (
        [string]$currentVersion,
        [string]$filePath = $MyInvocation.MyCommand.Path
    )


    $nextbuildversion = Get-NextFixVersion -version $currentVersion

    Write-customLOG -LogText ("Prepare Next: $nextbuildversion ""($currentScriptPath)""")

    # Read the content of the file
    $fileContent = Get-Content -Path $filePath

    # Update the line containing the version number
    $fileContent = $fileContent -replace "$currentVersion", "$nextVersion"

    # Write the updated content back to the file
    Set-Content -Path $filePath -Value $fileContent

    Write-customLOG -LogText "Version updated from $currentVersion to $nextVersion in ""$filePath"""
}

# fix publish errors:
<#
Invoke-WebRequest -Uri https://dist.nuget.org/win-x86-commandline/latest/nuget.exe -OutFile "$env:LOCALAPPDATA\Microsoft\Windows\PowerShell\PowerShellGet\NuGet.exe"
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
Install-PackageProvider -Name PowerShellGet -Force -Scope CurrentUser
#>

. .\vars.ps1

Update-ModuleManifest -path ./$module/$module.psd1 -FunctionsToExport Test-$module, Get-ColorText, Get-ConfigfromJSON, Write-customLOG
Update-ModuleManifest -Path ./$module/$module.psd1 -ModuleVersion $nextversion

Test-Modulemanifest -path ./$module/$module.psd1  

$env:DOTNET_CLI_UI_LANGUAGE  = "en-US"
Publish-module -path ./$module/ -Repository "PSGallery" -Nugetapikey $key


$submodules = @("EnergySaver", "Update")

foreach ($submodule in $submodules) {
    Write-customLOG -logtext "progress: ""$module.$submodule/$module.$submodule.psd1"" "
    Update-ModuleManifest -Path ./src/$module.$submodule/$module.$submodule.psd1 -ModuleVersion $nextversion
    Test-Modulemanifest -path ./src/$module.$submodule/$module.$submodule.psd1 
    Publish-module -path ./src/$module.$submodule/ -Repository "PSGallery" -Nugetapikey $key
}


Update-VersionInScript -currentVersion $nextversion -filePath  $MyInvocation.MyCommand.Path

Update-VersionInScript -currentVersion $nextversion -filePath ".\RelaxedIT\RelaxedIT.psm1"

Start-Sleep -Seconds 5

Find-Module -Name $module
