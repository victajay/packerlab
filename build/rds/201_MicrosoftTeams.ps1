#description: Installs the latest Microsoft Teams per-machine for use on Windows 10/11 multi-session or Windows Server
#execution mode: Combined
#tags: Evergreen, Microsoft, Teams
#Requires -Modules Evergreen
[System.String] $Path = "$env:SystemDrive\Apps\Microsoft\Teams"
[System.String] $TeamsExe = "${env:ProgramFiles(x86)}\Microsoft\Teams\current\Teams.exe"

#region Script logic
New-Item -Path $Path -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" | Out-Null
New-Item -Path "$env:ProgramData\Evergreen\Logs" -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" | Out-Null

try {
    # Download Teams
    Import-Module -Name "Evergreen" -Force
    $App = Invoke-EvergreenApp -Name "MicrosoftTeams" | Where-Object { $_.Architecture -eq "x64" -and $_.Ring -eq "General" -and $_.Type -eq "msi" } | Select-Object -First 1
    $OutFile = Save-EvergreenApp -InputObject $App -CustomPath $Path -WarningAction "SilentlyContinue"
}
catch {
    throw $_
}

try {
    # Uninstall the existing Teams
    if (Test-Path -Path $TeamsExe) {
        $File = Get-ChildItem -Path $TeamsExe
        if ([System.Version]$File.VersionInfo.ProductVersion -le [System.Version]$App.Version) {
            $LogFile = "$env:ProgramData\Evergreen\Logs\UninstallMicrosoftTeams$($File.VersionInfo.ProductVersion).log" -replace " ", ""
            $params = @{
                FilePath     = "$env:SystemRoot\System32\msiexec.exe"
                ArgumentList = "/x `"$($OutFile.FullName)`" /quiet /log $LogFile"
                NoNewWindow  = $true
                Wait         = $true
                PassThru     = $false
            }
            $result = Start-Process @params

            $Folders = "${env:ProgramFiles(x86)}\Microsoft\Teams", `
                "${env:ProgramFiles(x86)}\Microsoft\TeamsMeetingAddin", `
                "${env:ProgramFiles(x86)}\Microsoft\TeamsPresenceAddin"
            Remove-Item -Path $Folders -Recurse -Force -ErrorAction "Ignore"
        }
    }
}
catch {
    throw "Exit code: $($result.ExitCode); Error: $($_.Exception.Message)"
}

if (Test-Path -Path $TeamsExe) {
    # Teams is installed
}
else {
    try {
        # Install Teams
        New-Item -Path "HKLM:\SOFTWARE\Microsoft\Teams" -Force -ErrorAction "SilentlyContinue" | Out-Null
        New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Teams" -Name "IsWVDEnvironment" -PropertyType "DWORD" -Value 1 -Force -ErrorAction "SilentlyContinue" | Out-Null
        $LogFile = $LogFile = "$env:ProgramData\Evergreen\Logs\MicrosoftTeams$($App.Version).log" -replace " ", ""
        $params = @{
            FilePath     = "$env:SystemRoot\System32\msiexec.exe"
            ArgumentList = "/package $($OutFile.FullName) OPTIONS=`"noAutoStart=true`" ALLUSER=1 ALLUSERS=1 /quiet /log $LogFile"
            NoNewWindow  = $true
            Wait         = $true
            PassThru     = $false
        }
        $result = Start-Process @params
    }
    catch {
        throw "Exit code: $($result.ExitCode); Error: $($_.Exception.Message)"
    }
}

try {
    # Teams JSON files; Read the file and convert from JSON
    $ConfigFiles = @((Join-Path -Path "${env:ProgramFiles(x86)}\Teams Installer" -ChildPath "setup.json"), (Join-Path -Path "${env:ProgramFiles(x86)}\Microsoft\Teams" -ChildPath "setup.json"))
    foreach ($Path in $ConfigFiles) {
        if (Test-Path -Path $Path) {
            $Json = Get-Content -Path $Path | ConvertFrom-Json
            $Json.noAutoStart = $true
            $Json | ConvertTo-Json | Set-Content -Path $Path -Force
        }
    }
}
catch {
    throw $_.Exception.Message
}

# Delete the registry auto-start
reg delete "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run" /v "Teams" /f | Out-Null
#endregion
