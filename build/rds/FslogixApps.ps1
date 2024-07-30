#description: Installs the latest Microsoft FSLogix Apps agent
#execution mode: Combined
#tags: Evergreen, Microsoft, FSLogix
#Requires -Modules Evergreen
[System.String] $Path = "$env:SystemDrive\Apps\Microsoft\FSLogix"

#region Script logic
New-Item -Path $Path -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" | Out-Null
New-Item -Path "$env:ProgramData\Evergreen\Logs" -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" | Out-Null

try {
    # Download and unpack
    Import-Module -Name "Evergreen" -Force
    $App = Invoke-EvergreenApp -Name "MicrosoftFSLogixApps" | Where-Object { $_.Channel -eq "Production" } | Select-Object -First 1

    # Debugging information
    Write-Output "App details: $App"
    Write-Output "Path: $Path"

    $OutFile = Save-EvergreenApp -InputObject $App -CustomPath $Path -WarningAction "SilentlyContinue"

    # Debugging output
    Write-Output "OutFile: $OutFile"

    Expand-Archive -Path $OutFile.FullName -DestinationPath $Path -Force
}
catch {
    Write-Error "Error during download and unpack: $_"
    throw $_
}

try {
    # Install
    foreach ($file in "FSLogixAppsSetup.exe", "FSLogixAppsRuleEditorSetup.exe") {
        $Installers = Get-ChildItem -Path $Path -Recurse -Include $file | Where-Object { $_.Directory -match "x64" }
        foreach ($Installer in $Installers) {
            try {
                $LogFile = "$env:ProgramData\Evergreen\Logs\$($Installer.Name)$($App.Version).log" -replace " ", ""
                $params = @{
                    FilePath     = $Installer.FullName
                    ArgumentList = "/install /quiet /norestart /log $LogFile"
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
    }
}
catch {
    Write-Error "Error during installation: $_"
    throw $_.Exception.Message
}

Start-Sleep -Seconds 5
$Shortcuts = @("$Env:ProgramData\Microsoft\Windows\Start Menu\FSLogix\FSLogix Apps Online Help.lnk")
Remove-Item -Path $Shortcuts -Force -ErrorAction "Ignore"
#endregion
