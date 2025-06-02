

# EXECUTE THIS ONE CLICK TIME INSTALL SCRIPT
<# 

Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://github.com/josy1024/RelaxedIT/blob/main/install.ps1'))

#>


Install-module RelaxedIT -Force -Scope AllUsers -AllowClobber
Install-Module RelaxedIT.Update -Force -Scope AllUsers -AllowClobber

Import-Module RelaxedIT
Import-Module RelaxedIT.Update

RelaxedIT.Resources.OneclickInstall

write-relaxedlog -logtext "Change ""C:\ProgramData\RelaxedIT\azlog.json"" with your own log-settings!"