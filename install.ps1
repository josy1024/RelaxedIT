

# EXECUTE THIS ONE CLICK TIME INSTALL SCRIPT
<# #>
Set-ExecutionPolicy Bypass -Scope Process -Force

# Ensure modern TLS for PSGallery
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072

# Choose installation scope depending on elevation
$Scope = 'AllUsers'
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator'))
{
	Write-Host "Not running as Administrator; installing to CurrentUser scope instead." -ForegroundColor Yellow
	$Scope = 'CurrentUser'
}

try
{
	Install-Module -Name RelaxedIT -Force -Scope $Scope -AllowClobber -ErrorAction Stop
	Install-Module -Name RelaxedIT.Update -Force -Scope $Scope -AllowClobber -ErrorAction Stop
}
catch
{
	Write-Host "Install-Module failed: $($_.Exception.Message)" -ForegroundColor Red
	throw
}

try { Import-Module RelaxedIT -ErrorAction Stop } catch { Write-Host "Import-Module RelaxedIT failed: $($_.Exception.Message)" -ForegroundColor Red }
try { Import-Module RelaxedIT.Update -ErrorAction Stop } catch { Write-Host "Import-Module RelaxedIT.Update failed: $($_.Exception.Message)" -ForegroundColor Red }

try
{
	RelaxedIT.Resources.OneclickInstall -Scope $Scope
}
catch
{
	Write-Host "One-click install step failed: $($_.Exception.Message)" -ForegroundColor Red
}

write-relaxedlog -logtext "Change ""C:\ProgramData\RelaxedIT\azlog.json"" with your own log-settings!"

