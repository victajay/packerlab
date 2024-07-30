#description: Installs PowerShell modules required for building AVD images (Evergreen, VcRedist, PSWindowsUpdate, etc.)
#execution mode: Combined
#tags: Evergreen, VcRedist, Image

#region Script logic
# Trust the PSGallery for modules
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Install-PackageProvider -Name "NuGet" -MinimumVersion "2.8.5.208" -Force
Install-PackageProvider -Name "PowerShellGet" -MinimumVersion "2.2.5" -Force

# Ensure PSGallery is a trusted repository
$repository = Get-PSRepository -Name "PSGallery" -ErrorAction SilentlyContinue
if ($null -eq $repository) {
    Register-PSRepository -Name "PSGallery" -SourceLocation "https://www.powershellgallery.com/api/v2" -InstallationPolicy Trusted
} elseif ($repository.InstallationPolicy -ne "Trusted") {
    Set-PSRepository -Name "PSGallery" -InstallationPolicy "Trusted"
}

# Install the Evergreen module; https://github.com/aaronparker/Evergreen
# Install the VcRedist module; https://docs.stealthpuppy.com/vcredist/
foreach ($module in "Evergreen", "VcRedist", "PSWindowsUpdate") {
    $installedModule = Get-Module -Name $module -ListAvailable -ErrorAction "SilentlyContinue" | `
        Sort-Object -Property @{ Expression = { [System.Version]$_.Version }; Descending = $true } -ErrorAction "SilentlyContinue" | `
        Select-Object -First 1
    $publishedModule = Find-Module -Name $module -ErrorAction "SilentlyContinue"
    if (($null -eq $installedModule) -or ([System.Version]$publishedModule.Version -gt [System.Version]$installedModule.Version)) {
        $params = @{
            Name               = $module
            SkipPublisherCheck = $true
            Force              = $true
            ErrorAction        = "Stop"
        }
        Install-Module @params
    }
}
#endregion