#Requires -Version 5.1
Describe 'Invoke-SessionSettingsRefresh' {
    BeforeAll {
        $libDir = Join-Path (Join-Path $PSScriptRoot '..') 'lib'
        . (Join-Path $libDir 'Invoke-SessionSettingsRefresh.ps1')
    }

    It 'supports dry-run without throwing' {
        { Invoke-SessionSettingsRefresh -DryRun } | Should Not Throw
        { Invoke-SessionSettingsRefresh -DryRun -RestartExplorer } | Should Not Throw
    }
}
