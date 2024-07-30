<#
    .SYNOPSIS
        Install line-of-business applications from an Azure storage account
        Assumes applications are installed via the PSAppDeployToolkit
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "", Justification = "Outputs progress to the pipeline log")]
[CmdletBinding()]
param (
    [Parameter(Mandatory = $False)]
    [System.String] $Path = "$env:SystemDrive\Apps"
)

#region Functions
function Get-AzureBlobItem {
    <#
        .SYNOPSIS
            Returns an array of items and properties from an Azure blog storage URL.

        .DESCRIPTION
            Queries an Azure blog storage URL and returns an array with properties of files in a Container.
            Requires Public access level of anonymous read access to the blob storage container.
            Works with PowerShell Core.

        .NOTES
            Author: Aaron Parker
            Twitter: @stealthpuppy

        .PARAMETER Url
            The Azure blob storage container URL. The container must be enabled for anonymous read access.
            The URL must include the List Container request URI. See https://docs.microsoft.com/en-us/rest/api/storageservices/list-containers2 for more information.

        .EXAMPLE
            Get-AzureBlobItems -Uri "https://aaronparker.blob.core.windows.net/folder/?comp=list"

            Description:
            Returns the list of files from the supplied URL, with Name, URL, Size and Last Modifed properties for each item.
    #>
    [CmdletBinding(SupportsShouldProcess = $False)]
    [OutputType([System.Management.Automation.PSObject])]
    param (
        [Parameter(ValueFromPipeline = $True, Mandatory = $True, HelpMessage = "Azure blob storage URL with List Containers request URI '?comp=list'.")]
        [ValidatePattern("^(http|https)://")]
        [System.String] $Uri
    )

    begin {}
    process {

        # Get response from Azure blog storage; Convert contents into usable XML, removing extraneous leading characters
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            $iwrParams = @{
                Uri             = $Uri
                UseBasicParsing = $True
                ContentType     = "application/xml"
                ErrorAction     = "Stop"
            }
            $list = Invoke-WebRequest @iwrParams
        }
        catch [System.Exception] {
            throw $_.Exception.Message
        }
        if ($Null -ne $list) {
            [System.Xml.XmlDocument] $xml = $list.Content.Substring($list.Content.IndexOf("<?xml", 0))

            # Build an object with file properties to return on the pipeline
            $fileList = New-Object -TypeName System.Collections.ArrayList
            foreach ($node in (Select-Xml -XPath "//Blobs/Blob" -Xml $xml).Node) {
                $PSObject = [PSCustomObject] @{
                    Name         = ($node | Select-Object -ExpandProperty Name)
                    Url          = ($node | Select-Object -ExpandProperty Url)
                    Size         = ($node | Select-Object -ExpandProperty Size)
                    LastModified = ($node | Select-Object -ExpandProperty LastModified)
                }
                $fileList.Add($PSObject) > $Null
            }
            if ($Null -ne $fileList) {
                Write-Output -InputObject $fileList
            }
        }
    }
    end {}
}

function Install-LobApp ($Path, $AppsUrl) {
    # Get the list of items from blob storage
    try {
        $Items = Get-AzureBlobItem -Uri "$($AppsUrl)?comp=list" | Where-Object { $_.Name -match "zip?" }
    }
    catch {
        Write-Host "Failed to retrieve items from: [$AppsUrl]."
        Write-Warning -Message " ERR: Failed with $($_.Exception.Message)."
    }

    if ($Items.Count -gt 0) {
        foreach ($item in $Items) {
            $AppName = $item.Name -replace ".zip"
            $AppPath = Join-Path -Path $Path -ChildPath $AppName
            if (!(Test-Path $AppPath)) { New-Item -Path $AppPath -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" > $Null }

            try {
                [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                $ProgressPreference = "SilentlyContinue"
                $OutFile = Join-Path -Path $Path -ChildPath (Split-Path -Path $item.Url -Leaf)
                $params = @{
                    Uri             = $item.Url
                    OutFile         = $OutFile
                    UseBasicParsing = $true
                    ErrorAction     = "SilentlyContinue"
                }
                Write-Host "Downloading item: [$($item.Url)]."
                Invoke-WebRequest @params
            }
            catch {
                Write-Warning -Message " ERR: Failed to download: $($item.Url) with: with $($_.Exception.Message)"
            }

            try {
                Expand-Archive -Path $OutFile -DestinationPath $AppPath -Force
                Remove-Item -Path $OutFile -Force -ErrorAction "SilentlyContinue"
                Write-Host "Installing item: $($AppName)."
                Push-Location -Path $AppPath
                Get-ChildItem -Path $AppPath -Recurse | Unblock-File
                . .\Deploy-Application.ps1
                Pop-Location
            }
            catch {
                Write-Host $_.Exception.Message
            }
        }
    }
    else {
        Write-Host "No line of business applications."
    }
}
#endregion

#region Script logic
New-Item -Path $Path -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" > $Null

# Run tasks
if (Test-Path -Path env:AppsUrl) {
    Install-LobApp -Path $Path -AppsUrl $env:AppsUrl
}
Write-Host "Complete: LoBApps."
#endregion
