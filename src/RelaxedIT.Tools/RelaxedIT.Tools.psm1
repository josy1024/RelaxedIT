function Get-BasePath {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    # Resolve the base directory
    $BasePath = Split-Path -Path $Path -Parent
    return $BasePath
}


function Start-ElevatedPwsh {
    # Check if the current session is running as Administrator
    if (-Not ([Security.Principal.WindowsPrincipal]([Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))) {
        Write-RelaxedIT -logtext "Starting an elevated PowerShell session..." -ForegroundColor Yellow

        # Start an elevated PowerShell session (empty)
        Start-Process -FilePath "pwsh.exe" -Verb RunAs

        Write-RelaxedIT -logtext "An elevated PowerShell session has been started." -ForegroundColor Green
    } else {
        Write-RelaxedIT -logtext "This session is already running with Administrator privileges." -ForegroundColor Cyan
    }
}

function Test-AndCreatePath {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    # Check if the path exists
    if (Test-Path -Path $Path) {
        Write-RelaxedIT -logtext "Path '$Path' already exists." -ForegroundColor Green -level 3
    } else {
        # Create the path
        Write-RelaxedIT -logtext "Path '$Path' does not exist. Creating it now..." -ForegroundColor Yellow
        New-Item -ItemType Directory -Path $Path | Out-Null
        Write-RelaxedIT -logtext "Path '$Path' has been created." -ForegroundColor Cyan
    }
}

function Update-InFileContent {
    param (
        [Parameter(Mandatory = $true)]
        [string]$FilePath,   # The file to modify
        [Parameter(Mandatory = $true)]
        [string]$OldText,    # Text to be replaced
        [Parameter(Mandatory = $true)]
        [string]$NewText     # Replacement text
    )

    # Check if file exists
    if (-Not (Test-Path -Path $FilePath)) {
        Write-RelaxedIT -logtext "[ERR] File not found: $FilePath" -ForegroundColor Red
        return
    }

    # Read the content of the file
    $Content = Get-Content -Path $FilePath 

    # Replace the specified text
    $UpdatedContent = $Content -replace [regex]::Escape($OldText), $NewText

    # Write the updated content back to the file
    Set-Content -Path $FilePath -Value $UpdatedContent -Encoding utf8BOM

    Write-RelaxedIT -logtext "Replaced ""$OldText"" with ""$NewText"" in ""$FilePath""" -ForegroundColor Green
}

