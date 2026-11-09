#Requires -Version 5.1
Describe 'Read-DesiredApps' {
    BeforeAll {
        $libDir = Join-Path (Join-Path $PSScriptRoot '..') 'lib'
        . (Join-Path $libDir 'Read-DesiredApps.ps1')
        $fixtures = Join-Path $PSScriptRoot 'fixtures'
    }

    It 'parses legacy winget-only config' {
        $path = Join-Path $fixtures 'winget-only.toml'
        $cfg = Read-DesiredApps -TomlPath $path

        $cfg.AppIds | Should Be @('7zip.7zip')
        $cfg.Winget.accept_source_agreements | Should Be $true
        $cfg.GitHubApps.Count | Should Be 0
        $cfg.Associations.Count | Should Be 0
    }

    It 'parses github apps in desired-apps' {
        $path = Join-Path $fixtures 'full-apps.toml'
        $cfg = Read-DesiredApps -TomlPath $path

        $cfg.GitHubApps.ContainsKey('widno') | Should Be $true
        $cfg.Associations.Count | Should Be 0
    }

    It 'parses associations in settings file' {
        $path = Join-Path $fixtures 'settings-only.toml'
        $cfg = Read-DesiredApps -TomlPath $path

        $cfg.Associations.ContainsKey('widno_photos') | Should Be $true
        @($cfg.Associations['widno_photos'].extensions) | Should Be @('.jpg', '.png')
    }
}
