# RelaxedIT

RelaxedIT powershell module

* [Changelog](CHANGELOG.md)

## Install (as ADMIN)

```powershell
Install-module RelaxedIT -Force -Scope AllUsers -AllowClobber
Install-Module RelaxedIT.EnergySaver -Force -Scope AllUsers -AllowClobber
Install-Module RelaxedIT.Update -Force -Scope AllUsers -AllowClobber
Install-Module RelaxedIT* -Force -Scope AllUsers -AllowClobber

# Install Auto-Updater Task
RelaxedIT.Update.Task.Install

```
* Published to PowershellGallery: https://www.powershellgallery.com/packages?q=relaxedIT


## Module Management (DEV)

```powershell

just:
 .\publish.ps1


. .\vars.ps1

Install-Module -Name PowerShellGet
New-ModuleManifest -path ./RelaxedIT/RelaxedIT.psd1 -Author "Josef Lahmer" -Description "relaxed IT client management scripts" -RootModule RelaxedIT -ModuleVersion 0.0.1 -PassThru

Update-ModuleManifest -path ./RelaxedIT/RelaxedIT.psd1 -FunctionsToExport Test-RelaxedIT, Get-ColorText
Update-ModuleManifest -Path ./RelaxedIT/RelaxedIT.psd1 -ModuleVersion "0.0.3"



Test-Modulemanifest -path ./RelaxedIT/RelaxedIT.psd1  

$env:DOTNET_CLI_UI_LANGUAGE  = "en-US"
Publish-module -path ./RelaxedIT/ -Repository "PSGallery" -Nugetapikey $key

```

### New Module

```powershell
$module="RelaxedIT"
$submodule="Tools"
mkdir ./src/$module.$submodule/
New-ModuleManifest -path ./src/$module.$submodule/$module.$submodule.psd1 -Author "Josef Lahmer" -Description "relaxed IT $submodule" -RootModule RelaxedIT.$submodule.psm1 -ModuleVersion 0.0.1 

Write-RelaxedIT -LogText  "# $module.$submodule" | out-file -path  ./src/$module.$submodule/$module.$submodule.psm1 -append
Update-ModuleManifest -path ./src/$module.$submodule/$module.$submodule.psd1 -LicenseUri 'https://github.com/josy1024/RelaxedIT/blob/main/LICENSE' 
Update-ModuleManifest -path ./src/$module.$submodule/$module.$submodule.psd1 -ProjectUri 'https://github.com/josy1024/RelaxedIT'
Update-ModuleManifest -path ./src/$module.$submodule/$module.$submodule.psd1 -IconUri 'https://raw.githubusercontent.com/josy1024/RelaxedIT/refs/heads/main/img/logo.png'

Test-Modulemanifest -path ./src/$module.$submodule/$module.$submodule.psd1

```

## TESTING

