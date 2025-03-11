
function Test-RelaxedIT
{
    write-host (Get-ColorText -text "[Test] ""RelaxedIT.module"" - optimized for pwsh7 v: 0.0.10 :-)")
    
}

function Get-ColorText {
    <#
    .SYNOPSIS
    Colors specific patterns in the input text. " ( nummber and dates "

    .DESCRIPTION
    The Get-ColorText function takes a string input and applies color formatting to specific patterns such as dates, digits, quoted text, and text within parentheses.

    .PARAMETER text
    The input text to be color formatted.

    .EXAMPLE
    $sampleText = "01/03/2025 [ERR][INF][Bracket] This is a null ""sample text"" dbNull @varname with a date 2023-03-04 18:15 (komment) and a number 123. bollean true and false "
    Get-ColorText -text $sampleText

    .NOTES
    Author: Josef Lahmer
    Date: 5.3.2025
    #>
    param (
        [string]$text
    )

    # Define regex patterns
    $digitPattern = '\b\d+\b'
    $digitPattern = '\ \d+\b'
    $varPattern = '@\w+'
    $datePatternDDMMYYYY = '\b\d{2}\.\d{2}\.\d{4}\b'
    $datePatternYYYYMMDD = '\b\d{4}-\d{2}-\d{2}\b'
    $datePatternDDMMYYYY_slash = '\b\d{2}/\d{2}/\d{4}\b'
    $hourPattern = '\b\d{2}:\d{2}(:\d{2})?\b'
    $quotePattern = '\"[^\"]*\"'
    $darkGrayPattern = '\(.*?\)'
    $BracketPattern = '\[.*?\]'
    $bluePattern = '(?i)\b(true|false|null|DBNull)\b'
    $redPattern = '\b\!\b' # red match !
    $keywordPattern = '\b(BUG|ERR|WARN|WRN|INF|DEBUG|TRACE|TODO)\b'


    # Replace patterns with colored text
    try {
        $text = [regex]::Replace($text, $darkGrayPattern, {param($match) "`e[90m$($match.Value)`e[0m"})  # DarkGray
        $text = [regex]::Replace($text, $BracketPattern, {param($match) "`e[90m$($match.Value)`e[0m"})  # DarkGray
        $text = [regex]::Replace($text, $datePatternYYYYMMDD, {param($match) "`e[32m$($match.Value)`e[0m"})   # Green for YYYY-MM-DD
        $text = [regex]::Replace($text, $datePatternDDMMYYYY_slash, {param($match) "`e[32m$($match.Value)`e[0m"})   # Green for DD/MM/YYYY
        $text = [regex]::Replace($text, $datePatternDDMMYYYY, {param($match) "`e[32m$($match.Value)`e[0m"})   # Green for DD.MM.YYYY
        $text = [regex]::Replace($text, $hourPattern, {param($match) "`e[32m$($match.Value)`e[0m"})   # Green for HH:MM:SS
        $text = [regex]::Replace($text, $digitPattern, {param($match) "`e[35m$($match.Value)`e[0m"})  # DarkMagenta
        $text = [regex]::Replace($text, $varPattern, {param($match) "`e[93m$($match.Value)`e[0m"}) # @variablename
        $text = [regex]::Replace($text, $quotePattern, {param($match) "`e[96m$($match.Value)`e[0m"})  # Cyan
        $text = [regex]::Replace($text, $bluePattern, {param($match) "`e[34m$($match.Value)`e[0m"})  # blue 
        $text = [regex]::Replace($text, $redPattern, {param($match) "`e[31m$($match.Value)`e[0m"})  # red
        $text = [regex]::Replace($text, $keywordPattern, {param($match) "`e[31m$($match.Value)`e[0m"})  # red
        
    }
    catch {
        write-host "Get-ColorText ERROR: $text" -ForegroundColor Red
    }

    # Output the colored text
    return $text
}

function Get-ConfigfromJSON {
    <#
    .SYNOPSIS
        json array config file
    .DESCRIPTION
        use a json config file
    .NOTES
        Information or caveats about the function e.g. 'This function is not supported in Linux'
    .LINK
        Specify a URI to a help page, this will show when Get-Help -Online is used.
    .EXAMPLE
        # $config = Get-ConfigfromJSON -match "2" -config .\mandant.json
        # $config.ConfigValue    
    #>
    param (
        [String]$config="config.json",
        [String]$id="id",
        [String]$match=""
    )

    # Read the JSON file
    $jsonobj = Get-Content -Path $config | ConvertFrom-Json

    # Find the object with the matching "anbieternr"
    if ($match -ne "")
    {
        $result = $jsonobj | Where-Object { $_.($id) -eq $match }
    }
    else {
        $result = $jsonobj
    }

    if ($result) {
        return $result
    } else {
        Write-customLOG -logtext ("No configuration found for $id : $match")
    }
}

function Write-customLOG
{   [CmdletBinding()]
    param (
        [Parameter()]
        [string]$logtext,
        [string]$logfilepath="c:\temp\ps\default.log"
    )
    write-host ("" + (Get-LogDateString) + " " + (Get-ColorText -text $logtext))

    # Überprüfen der Umgebungsvariable "relaxedlog"
    $relaxedlog = Get-EnvVar -name "relaxedlog"

    if (-not $relaxedlog) {

        $psscript = $MyInvocation.MyCommand.Name + "_" +(Get-LogDateString) + ".log"
        # logPath = "$logfilepath\$psscript.log"
        $logfilepath = $logfilepath -replace "default.log",  $psscript
        Set-EnvVar -name "relaxedlog" -value $logfilepath
        $baseDirectory = Split-Path -Path $logfilepath    

        if (-not (Test-Path -Path $baseDirectory)) {
            New-Item -ItemType Directory -Path $baseDirectory -Force | Out-Null
            Write-Host "Base directory created: $baseDirectory"
        } 
    }

    if ($relaxedlog -ne "nolog") {
        # Logtext in die Datei schreiben
        Add-Content -Path $logfilepath -Value ("" + (Get-LogDateString) + " " + $logtext) 
    }
}

Function Get-LogDateString 
{
	[CmdletBinding()]
	param (
		[Parameter()]
		[datetime] $date = [datetime]::UtcNow
	)
	<#
	.SYNOPSIS
		#GET-LogDateString #get-date
	.DESCRIPTION
		gibt #z_templates standard schoen formatiertes datum innerhalb der logfiles zurück 
	#>
	return ([datetime]::UtcNow).toString("yyyy-MM-dd  HH:mm:ss U\tc")
}

function Get-EnvVar {
    param (
        [Parameter(Mandatory = $true)]
        [string]$name
    )
    return [System.Environment]::GetEnvironmentVariable($name)
}

# Funktion zum Setzen einer Umgebungsvariablen
function Set-EnvVar {
    param (
        [Parameter(Mandatory = $true)]
        [string]$name,
        [Parameter(Mandatory = $true)]
        [string]$value
    )
    [System.Environment]::SetEnvironmentVariable($name, $value)
}
