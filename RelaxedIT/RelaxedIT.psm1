
function Test-RelaxedIT
{
    write-host Get-ColorText("[Test]-""RelaxedIT.module"" - optimized for pwsh7 :-)")
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
    $sampleText = "01/03/2025 [INF] This is a null ""sample text"" dbNull @varname with a date 2023-03-04 18:15 (komment) and a number 123. bollean true and false "
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
        
    }
    catch {
        write-host "Get-ColorText ERROR: $text" -ForegroundColor Red
    }

    # Output the colored text
    return $text
}
