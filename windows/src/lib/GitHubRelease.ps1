#Requires -Version 5.1

function ConvertTo-GlobRegex {
    param([Parameter(Mandatory)][string]$Pattern)
    $escaped = [regex]::Escape($Pattern).Replace('\*', '.*').Replace('\?', '.')
    return "^$escaped$"
}

function Test-GlobMatch {
    param(
        [Parameter(Mandatory)][string]$Pattern,
        [Parameter(Mandatory)][string]$Name
    )
    $regex = ConvertTo-GlobRegex -Pattern $Pattern
    return [bool]($Name -match $regex)
}

function Normalize-AppVersionString {
    param([string]$Version)
    if ([string]::IsNullOrWhiteSpace($Version)) { return '' }
    $v = $Version.Trim()
    if ($v.StartsWith('v', [StringComparison]::OrdinalIgnoreCase)) {
        $v = $v.Substring(1)
    }
    return $v
}

function Compare-AppVersion {
    param(
        [string]$Installed,
        [string]$Remote
    )
    $a = Normalize-AppVersionString -Version $Installed
    $b = Normalize-AppVersionString -Version $Remote
    if ([string]::IsNullOrWhiteSpace($a)) { return 'Older' }
    if ([string]::IsNullOrWhiteSpace($b)) { return 'SameOrNewer' }

    try {
        $va = [version]$a
        $vb = [version]$b
        if ($va -lt $vb) { return 'Older' }
        return 'SameOrNewer'
    } catch {
        return 'Older'
    }
}

function Expand-ConfigPath {
    param([Parameter(Mandatory)][string]$PathTemplate)
    $expanded = $PathTemplate
    $expanded = $expanded -replace '%LOCALAPPDATA%', $env:LOCALAPPDATA
    $expanded = $expanded -replace '%APPDATA%', $env:APPDATA
    $expanded = $expanded -replace '%ProgramFiles%', ${env:ProgramFiles}
    return $expanded
}

function Get-GitHubReleaseApiHeaders {
    return @{
        Accept = 'application/vnd.github+json'
        'X-GitHub-Api-Version' = '2022-11-28'
    }
}

function Get-LatestStableGitHubRelease {
    param(
        [Parameter(Mandatory)][string]$Repo
    )

    $headers = Get-GitHubReleaseApiHeaders
    $latestUri = "https://api.github.com/repos/$Repo/releases/latest"
    try {
        $latest = Invoke-RestMethod -Uri $latestUri -Headers $headers -Method Get
        if (-not $latest.draft -and -not $latest.prerelease) {
            return $latest
        }
    } catch {
        # 404 if no releases yet — fall through to list scan
    }

    $uri = "https://api.github.com/repos/$Repo/releases?per_page=20"
    $releases = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
    foreach ($rel in $releases) {
        if ($rel.draft) { continue }
        if ($rel.prerelease) { continue }
        return $rel
    }
    return $null
}

function Select-ReleaseAsset {
    param(
        [Parameter(Mandatory)]$Release,
        [Parameter(Mandatory)][string]$AssetGlob
    )
    foreach ($asset in $Release.assets) {
        if (Test-GlobMatch -Pattern $AssetGlob -Name $asset.name) {
            return $asset
        }
    }
    return $null
}

function Get-GitHubAppInstalledVersion {
    param(
        [string]$DisplayName,
        [string]$DetectExe
    )

    if ($DetectExe) {
        $path = Expand-ConfigPath -PathTemplate $DetectExe
        if (Test-Path -LiteralPath $path) {
            $ver = (Get-Item -LiteralPath $path).VersionInfo.ProductVersion
            if ($ver) { return @{ Installed = $true; Version = $ver; ExePath = $path } }
            return @{ Installed = $true; Version = ''; ExePath = $path }
        }
    }

    if ($DisplayName) {
        $roots = @(
            'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
            'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
            'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
        )
        foreach ($root in $roots) {
            $items = Get-ItemProperty $root -ErrorAction SilentlyContinue
            foreach ($item in $items) {
                if ($item.DisplayName -eq $DisplayName) {
                    return @{ Installed = $true; Version = [string]$item.DisplayVersion; ExePath = $null }
                }
            }
        }
    }

    return @{ Installed = $false; Version = ''; ExePath = $null }
}

function Get-UninstallEntryForDisplayName {
    param([Parameter(Mandatory)][string]$DisplayName)

    $roots = @(
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    foreach ($root in $roots) {
        $items = Get-ItemProperty $root -ErrorAction SilentlyContinue
        foreach ($item in $items) {
            if ($item.DisplayName -eq $DisplayName -and $item.UninstallString) {
                return $item.UninstallString
            }
        }
    }
    return $null
}

function Invoke-GitHubAppUninstall {
    param(
        [string]$DisplayName,
        [string]$DetectExe
    )

    $uninstall = Get-UninstallEntryForDisplayName -DisplayName $DisplayName
    if ($uninstall) {
        Write-Host "Uninstall: $uninstall" -ForegroundColor DarkGray
        $proc = Start-Process -FilePath 'cmd.exe' -ArgumentList @('/c', $uninstall) -Wait -PassThru
        if ($proc.ExitCode -eq 0) { return $true }
    }

    if ($DetectExe) {
        $path = Expand-ConfigPath -PathTemplate $DetectExe
        $dir = Split-Path -Parent $path
        foreach ($name in @('Uninstall.exe', 'uninstall.exe', 'Uninstall Widno.exe')) {
            $candidate = Join-Path $dir $name
            if (Test-Path -LiteralPath $candidate) {
                $proc = Start-Process -FilePath $candidate -ArgumentList @('/VERYSILENT') -Wait -PassThru
                return ($proc.ExitCode -eq 0)
            }
        }
    }
    return $false
}
