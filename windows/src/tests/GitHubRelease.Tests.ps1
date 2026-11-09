#Requires -Version 5.1
Describe 'GitHub release helpers' {
    BeforeAll {
        $libDir = Join-Path (Join-Path $PSScriptRoot '..') 'lib'
        . (Join-Path $libDir 'GitHubRelease.ps1')
    }

    It 'matches current widno installer name on latest release' {
        Test-GlobMatch -Pattern 'Widno-*-Windows-x64-Setup.exe' -Name 'Widno-1.0.4-Windows-x64-Setup.exe' | Should Be $true
    }

    It 'rejects unrelated asset names' {
        Test-GlobMatch -Pattern 'Widno-*-Windows-x64-Setup.exe' -Name 'other.exe' | Should Be $false
    }

    It 'detects newer remote version' {
        (Compare-AppVersion -Installed '1.0.0' -Remote '1.1.0') | Should Be 'Older'
        (Compare-AppVersion -Installed '1.1.0' -Remote '1.0.0') | Should Be 'SameOrNewer'
        (Compare-AppVersion -Installed '1.0.0' -Remote '1.0.0') | Should Be 'SameOrNewer'
    }

    It 'strips v prefix from tags' {
        (Compare-AppVersion -Installed '1.0.0' -Remote 'v2.0.0') | Should Be 'Older'
    }
}
