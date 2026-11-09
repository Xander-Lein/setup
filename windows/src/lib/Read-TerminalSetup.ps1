#Requires -Version 5.1
function Get-TerminalSetupConfig {
    param(
        [Parameter(Mandatory)][string]$RepoRoot
    )

    $defaults = [ordered]@{
        Profile   = 'MINGW64'
        Msys2Root = 'C:\msys64'
    }

    $configPath = Join-Path $RepoRoot 'src\apps_settings\terminal.toml'
    if (-not (Test-Path -LiteralPath $configPath)) {
        return [pscustomobject]$defaults
    }

    $profile = $defaults.Profile
    $msys2Root = $defaults.Msys2Root

    foreach ($line in Get-Content -LiteralPath $configPath -Encoding UTF8) {
        $t = $line.Trim()
        if ($t.Length -eq 0 -or $t.StartsWith('#') -or $t.StartsWith('[')) { continue }
        if ($t -match '^(?<k>[a-zA-Z0-9_]+)\s*=\s*"(?<v>.*)"\s*$') {
            switch ($Matches.k) {
                'profile' { $profile = $Matches.v }
                'msys2_root' { $msys2Root = $Matches.v -replace '\\\\', '\' }
            }
        }
    }

    return [pscustomobject]@{
        Profile   = $profile
        Msys2Root = $msys2Root
    }
}
