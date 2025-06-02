
[CmdletBinding()]
param (
    [Parameter()]
    [string]
    $nextversion="0.0.73",
    [int]$publish=99
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

function Get-AllFunctions {
	<#
.SYNOPSIS
    Retrieves the names of all functions defined in a specified script file.

.DESCRIPTION
    The Get-AllFunctions function reads a script file and extracts the names of all functions defined within it.
    It searches for lines that start with the keyword 'function' and returns the function names.

.PARAMETER path
    Specifies the path to the script file. This parameter is mandatory.

.EXAMPLE
	$module="guglerPFModule"
	$module="guglerModule"
	$functs = Get-AllFunctions -path "$module.psm1"
	Update-ModuleManifest -Path "$module.psd1" -FunctionsToExport $functs
    This command retrieves the names of all functions defined in the script file located at C:\Scripts\MyScript.ps1.

	#>
    param (
        [Parameter(Mandatory = $true)]
        [string]$path
    )

    return Get-Content -Path $path | Select-String -Pattern "^function " | ForEach-Object {
        $_.Line -replace "function ", ""  -replace "\{.*", "" -replace "\(.*", "" -replace " ", ""
    }
}

function Update-VersionInScript {
    param (
        [string]$currentVersion,
        [string]$filePath = $MyInvocation.MyCommand.Path
    )


    $nextbuildversion = Get-NextFixVersion -version $currentVersion

    Write-RelaxedIT -LogText ("Prepare Next: $nextbuildversion ""$filePath"" ($currentVersion)")

    if (test-path -path $filePath) {
        # Read the content of the file
        $fileContent = Get-Content -Path $filePath

        # Update the line containing the version number
        $fileContent = $fileContent -replace "$currentVersion", "$nextbuildversion"

        # Write the updated content back to the file
        Set-Content -Path $filePath -Value $fileContent  -Encoding utf8BOM

        Write-RelaxedIT -LogText "Version updated from $currentVersion to $nextbuildversion in ""$filePath"""
    }
    else {
        Write-RelaxedIT -LogText "[ERR] in Update-VersionInScript: File not found: ""$filePath"""
    }
}

# fix publish errors:
<#
Invoke-WebRequest -Uri https://dist.nuget.org/win-x86-commandline/latest/nuget.exe -OutFile "$env:LOCALAPPDATA\Microsoft\Windows\PowerShell\PowerShellGet\NuGet.exe"
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
Install-PackageProvider -Name PowerShellGet -Force -Scope CurrentUser
#>
set-location -Path $PSScriptRoot

. .\vars.ps1


$functionsToExport = Get-AllFunctions -path "./$module/$module.psm1"
Update-ModuleManifest -Path ./$module/$module.psd1 -FunctionsToExport $functionsToExport
Update-ModuleManifest -Path ./$module/$module.psd1 -ModuleVersion $nextversion

Test-Modulemanifest -path ./$module/$module.psd1  

$env:DOTNET_CLI_UI_LANGUAGE  = "en-US"
$env:NUGET_CLI_LANGUAGE = "en-US"

if ($publish -eq 1 -or $publish -eq 99) {
    
    Publish-module -path ./$module/ -Repository "PSGallery" -Nugetapikey $key
}


$submodules = @("Update", "EnergySaver", "Tools", "AzLog", "3rdParty")

foreach ($submodule in $submodules) {
    Write-RelaxedIT -logtext "progress: ""$module.$submodule/$module.$submodule.psd1"" "
    Update-InFileContent -FilePath "./src/$module.$submodule/$module.$submodule.psm1" -OldText 'Write-Host "' -NewText 'Write-RelaxedIT -logtext "' -ErrorAction SilentlyContinue 
    $functionsToExport = Get-AllFunctions -path "./src/$module.$submodule/$module.$submodule.psm1"    
    Update-ModuleManifest -Path ./src/$module.$submodule/$module.$submodule.psd1 -ModuleVersion $nextversion
    Update-ModuleManifest -Path ./src/$module.$submodule/$module.$submodule.psd1 -FunctionsToExport $functionsToExport
    Update-VersionInScript -currentVersion $nextversion -filePath "./src/$module.$submodule/$module.$submodule.psm1" 

    $ret = Test-Modulemanifest -path ./src/$module.$submodule/$module.$submodule.psd1 
    Write-RelaxedIT -logtext "Test-Modulemanifest: RET: ""$ret"""

    if ($publish -ge 2 -or $publish -eq 99) {
        Publish-module -path ./src/$module.$submodule/ -Repository "PSGallery" -Nugetapikey $key
    }
}


if ($publish -ge 1) {
    Update-VersionInScript -currentVersion $nextversion -filePath  $MyInvocation.MyCommand.Path
    Update-VersionInScript -currentVersion $nextversion -filePath ".\RelaxedIT\RelaxedIT.psm1"
    Start-Sleep -Seconds 5
}

$findmodule  = Find-Module -Name $module
Write-RelaxedIT -LogText "Find_module Check ONLINE: ""$($findmodule.Name)"" ($($findmodule.Version))"

