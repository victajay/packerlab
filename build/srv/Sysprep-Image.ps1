<#
    .SYNOPSIS
        Sysprep image.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "", Justification="Outputs progress to the pipeline log")]
[CmdletBinding()]
param (
    [Parameter(Mandatory = $False)]
    [System.String] $Path = "$env:SystemDrive\Apps"
)

#region Functions
function Get-InstalledApplication () {
    $RegPath = @("HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*")
    if (-not ([System.IntPtr]::Size -eq 4)) {
        $RegPath += @("HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*")
    }
    try {
        $propertyNames = "DisplayName", "DisplayVersion", "Publisher", "UninstallString", "SystemComponent"
        $Apps = Get-ItemProperty -Path $RegPath -Name $propertyNames -ErrorAction "SilentlyContinue" | `
            . { process { if ($_.DisplayName) { $_ } } } | `
            Where-Object { $_.SystemComponent -ne 1 } | `
            Select-Object -Property "DisplayName", "DisplayVersion", "Publisher", "UninstallString", "PSPath" | `
            Sort-Object -Property "DisplayName"
    }
    catch {
        $_.Exception.Message
    }
    Return $Apps
}
#endregion



# Re-enable Defender
Write-Host "Enable Windows Defender real time scan"
Set-MpPreference -DisableRealtimeMonitoring $false
Write-Host "Enable Windows Store updates"
reg delete HKLM\Software\Policies\Microsoft\Windows\CloudContent /v DisableWindowsConsumerFeatures /f
reg delete HKLM\Software\Policies\Microsoft\WindowsStore /v AutoDownload /f

# Remove C:\Apps folder
try {
    if (Test-Path -Path $Path) { Remove-Item -Path $Path -Recurse -Force }
}
catch {
    Write-Warning "Failed to remove $Path with: $($_.Exception.Message)."
}

# Determine whether the Citrix Virtual Desktop Agent is installed
$CitrixVDA = Get-InstalledApplication | Where-Object { $_.DisplayName -like "*Machine Identity Service Agent*" }
if ($Null -ne $CitrixVDA) {
    Write-Host "Citrix Virtual Desktop agent detected, skipping Sysprep."
}
else {

    # Sysprep
    #region Prepare
    Write-Host "Run Sysprep"
    if (Get-Service -Name "RdAgent" -ErrorAction "SilentlyContinue") { Set-Service -Name "RdAgent" -StartupType "Disabled" }
    if (Get-Service -Name "WindowsAzureTelemetryService" -ErrorAction "SilentlyContinue") { Set-Service -Name "WindowsAzureTelemetryService" -StartupType "Disabled" }
    if (Get-Service -Name "WindowsAzureGuestAgent" -ErrorAction "SilentlyContinue") { Set-Service -Name "WindowsAzureGuestAgent" -StartupType "Disabled" }
    Remove-ItemProperty -Path 'HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Setup\\SysPrepExternal\\Generalize' -Name '*'
    #endregion

    #region Sysprep
    $RegPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\State"
    & $env:SystemRoot\System32\Sysprep\Sysprep.exe /oobe /generalize /quiet /quit
    While ($True) {
        $imageState = Get-ItemProperty $RegPath | Select-Object ImageState
        if ($imageState.ImageState -ne 'IMAGE_STATE_GENERALIZE_RESEAL_TO_OOBE') {
            Write-Output $imageState.ImageState
            Start-Sleep -s 10
        }
        else {
            break
        }
    }
    $imageState = Get-ItemProperty $RegPath | Select-Object -Property "ImageState"
    Write-Output $imageState.ImageState
    #endregion
    Write-Host "Complete: Sysprep."
}
