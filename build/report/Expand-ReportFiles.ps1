<#
    .SYNOPSIS
        Expand the JSON report files from the archive file
#>
[CmdletBinding()]
param (
    [Parameter()]
    [System.String] $Path = ([System.IO.Path]::Combine($env:SYSTEM_DEFAULTWORKINGDIRECTORY, "reports")),

    [Parameter()]
    [System.String] $ZipFile = "Installed.zip"
)

try {
    $params = @{
        Path            = $(Join-Path -Path $Path -ChildPath $ZipFile)
        DestinationPath = $Path
        Force           = $True
        Verbose         = $True
    }
    Expand-Archive @params
}
catch {
    Write-Warning -Message " ERR: Expand-Archive failed with: $($_.Exception.Message)."
}
