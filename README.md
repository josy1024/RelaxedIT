# RelaxedIT
[![PSGallery Version](https://img.shields.io/powershellgallery/v/RelaxedIT.svg?style=flat&logo=powershell&label=PSGallery%20Version)](https://www.powershellgallery.com/packages/RelaxedIT) [![PSGallery Downloads](https://img.shields.io/powershellgallery/dt/RelaxedIT.svg?style=flat&logo=powershell&label=PSGallery%20Downloads)](https://www.powershellgallery.com/packages/RelaxedIT) [![PowerShell](https://img.shields.io/badge/PowerShell-5.1-blue?style=flat&logo=powershell)](https://www.powershellgallery.com/packages/RelaxedIT) [![PSGallery Platform](https://img.shields.io/powershellgallery/p/RelaxedIT.svg?style=flat&logo=powershell&label=PSGallery%20Platform)](https://www.powershellgallery.com/packages/RelaxedIT)

This module contain Modules and cmdlets to Inventory Devices and Manage 3rd Party Apps 

## Table of Contents

- [Release Notes](#Release-Notes)
- [Install](#Install)
- [Module Management (DEV)](#Module-Management)
- [New-Module](#New-Module)

# Release Notes

[CHANGELOG.md](CHANGELOG.md)

# Install

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://github.com/josy1024/RelaxedIT/blob/main/install.ps1'))
```

Published to PowershellGallery: https://www.powershellgallery.com/packages?q=relaxedIT

## Module Management

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
$submodule="3rdParty"
mkdir ./src/$module.$submodule/
New-ModuleManifest -path ./src/$module.$submodule/$module.$submodule.psd1 -Author "Josef Lahmer" -Description "relaxed IT $submodule" -RootModule RelaxedIT.$submodule.psm1 -ModuleVersion 0.0.1 

Write-RelaxedIT -LogText  "# $module.$submodule" | out-file -path  ./src/$module.$submodule/$module.$submodule.psm1 -append
Update-ModuleManifest -path ./src/$module.$submodule/$module.$submodule.psd1 -LicenseUri 'https://github.com/josy1024/RelaxedIT/blob/main/LICENSE' 
Update-ModuleManifest -path ./src/$module.$submodule/$module.$submodule.psd1 -ProjectUri 'https://github.com/josy1024/RelaxedIT'
Update-ModuleManifest -path ./src/$module.$submodule/$module.$submodule.psd1 -IconUri 'https://raw.githubusercontent.com/josy1024/RelaxedIT/refs/heads/main/img/logo.png'

Test-Modulemanifest -path ./src/$module.$submodule/$module.$submodule.psd1

```

## TESTING

