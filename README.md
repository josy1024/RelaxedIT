# RelaxedIT

RelaxedIT powershell module

* [Changelog](CHANGELOG.md)

## Module Management

```powershell
. .\vars.ps1
New-ModuleManifest -path ./RelaxedIT/RelaxedIT.psd1 -Author "Josef Lahmer" -Description "relaxed IT client management scripts" -RootModule RelaxedIT -ModuleVersion 0.0.1 -PassThru

Update-ModuleManifest -path ./RelaxedIT/RelaxedIT.psd1 -FunctionsToExport Test-RelaxedIT, Get-ColorText

Test-Modulemanifest -path ./RelaxedIT/RelaxedIT.psd1  

$env:DOTNET_CLI_UI_LANGUAGE  = "en-US"
$exclusions = @("*.md", "vars.ps1")
Publish-module -path ./RelaxedIT/ -Repository "PSGallery" -Nugetapikey $key

```
