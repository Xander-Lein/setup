#Requires -Version 5.1
Describe 'Get-WingetDesiredAppAction' {
    BeforeAll {
        $libDir = Join-Path (Join-Path $PSScriptRoot '..') 'lib'
        . (Join-Path $libDir 'Invoke-WingetDesiredApps.ps1')
    }

    It 'InstallOnly skips installed apps' {
        (Get-WingetDesiredAppAction -AppId 'x' -Mode InstallOnly -IsInstalled $true) | Should Be 'Skip'
        (Get-WingetDesiredAppAction -AppId 'x' -Mode InstallOnly -IsInstalled $false) | Should Be 'Install'
    }

    It 'UpgradeOnly upgrades installed apps' {
        (Get-WingetDesiredAppAction -AppId 'x' -Mode UpgradeOnly -IsInstalled $true) | Should Be 'Upgrade'
        (Get-WingetDesiredAppAction -AppId 'x' -Mode UpgradeOnly -IsInstalled $false) | Should Be 'Install'
    }
}
