#Requires -Version 5.1
function Get-Msys2MsystemFromProfile {
    param([string]$Msys2Profile = 'MINGW64')
    switch ($Msys2Profile.ToUpperInvariant()) {
        'UCRT64'  { 'UCRT64' }
        'MINGW64' { 'MINGW64' }
        'CLANG64' { 'CLANG64' }
        'MSYS'    { 'MSYS' }
        default   { 'MINGW64' }
    }
}

function Get-Msys2ShellFlag {
    param([string]$Msys2Profile = 'MINGW64')
    switch ($Msys2Profile.ToUpperInvariant()) {
        'UCRT64'  { '-ucrt64' }
        'MINGW64' { '-mingw64' }
        'CLANG64' { '-clang64' }
        'MSYS'    { '-msys' }
        default   { '-mingw64' }
    }
}

function Expand-AppSettingsPlaceholders {
    param(
        [string]$Content,
        [string]$Msys2Root,
        [string]$WinUser,
        [string]$Msys2Profile = 'MINGW64'
    )
    $root = $Msys2Root.TrimEnd('\')
    $rootPosix = $root.Replace('\', '/')
    $bash = ($root + '\usr\bin\bash.exe').Replace('\', '/')
    $zsh = ($root + '\usr\bin\zsh.exe').Replace('\', '/')
    $shellCmd = ($root + '\msys2_shell.cmd').Replace('\', '/')
    $msysHome = (Join-Path (Join-Path $root 'home') $WinUser).Replace('\', '/')
    $msysystem = Get-Msys2MsystemFromProfile -Msys2Profile $Msys2Profile
    $shellFlag = Get-Msys2ShellFlag -Msys2Profile $Msys2Profile
    # Длинные плейсхолдеры — раньше коротких ({{MSYS2_SHELL}} входит в {{MSYS2_SHELL_FLAG}}).
    $expanded = $Content
    $expanded = $expanded.Replace('{{MSYS2_SHELL_FLAG}}', $shellFlag)
    $expanded = $expanded.Replace('{{MSYS2_ROOT}}', $rootPosix)
    $expanded = $expanded.Replace('{{MSYS2_BASH}}', $bash)
    $expanded = $expanded.Replace('{{MSYS2_ZSH}}', $zsh)
    $expanded = $expanded.Replace('{{MSYS2_SHELL}}', $shellCmd)
    $expanded = $expanded.Replace('{{MSYS2_HOME}}', $msysHome)
    $expanded = $expanded.Replace('{{MSYS2_MSYSTEM}}', $msysystem)
    return $expanded.Replace('{{WIN_USER}}', $WinUser)
}

function Copy-AppSettingsFile {
    param(
        [Parameter(Mandatory)][string]$SourcePath,
        [Parameter(Mandatory)][string]$DestPath,
        [string]$Msys2Root = 'C:\msys64',
        [string]$WinUser = $env:USERNAME,
        [string]$Msys2Profile = 'MINGW64'
    )

    if (-not (Test-Path -LiteralPath $SourcePath)) {
        throw "Источник не найден: $SourcePath"
    }

    $destDir = Split-Path -Parent $DestPath
    if ($destDir -and -not (Test-Path -LiteralPath $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }

    $raw = Get-Content -LiteralPath $SourcePath -Raw -Encoding UTF8
    if ($raw.Length -gt 0 -and [int][char]$raw[0] -eq 0xFEFF) {
        $raw = $raw.Substring(1)
    }
    $expanded = Expand-AppSettingsPlaceholders -Content $raw -Msys2Root $Msys2Root -WinUser $WinUser -Msys2Profile $Msys2Profile
    foreach ($ph in @(
            '{{MSYS2_ROOT}}', '{{MSYS2_HOME}}', '{{MSYS2_SHELL}}', '{{MSYS2_SHELL_FLAG}}',
            '{{MSYS2_BASH}}', '{{MSYS2_ZSH}}', '{{MSYS2_MSYSTEM}}', '{{WIN_USER}}'
        )) {
        if ($expanded.Contains($ph)) {
            throw "Плейсхолдер $ph не подставлен при копировании в $DestPath"
        }
    }
    $destName = [System.IO.Path]::GetFileName($DestPath)
    $zshDotfile = $destName.StartsWith('.') -or $destName -like '*.zsh'
    if ($zshDotfile) {
        $expanded = $expanded -replace "`r`n?", "`n"
    }
    $encoding = if ($zshDotfile) {
        New-Object System.Text.UTF8Encoding $false
    } else {
        New-Object System.Text.UTF8Encoding $true
    }
    [System.IO.File]::WriteAllText($DestPath, $expanded, $encoding)
}

function Get-Msys2HomePath {
    param(
        [string]$Msys2Root = 'C:\msys64',
        [string]$WinUser = $env:USERNAME
    )
    return Join-Path (Join-Path $Msys2Root 'home') $WinUser
}

function Get-Msys2HomePosixPath {
    param(
        [string]$Msys2Root = 'C:\msys64',
        [string]$WinUser = $env:USERNAME
    )
    return (Get-Msys2HomePath -Msys2Root $Msys2Root -WinUser $WinUser).Replace('\', '/')
}

function Remove-MesloNerdFontFromWindows {
    $entries = @(
        @{ File = 'MesloLGSNerdFontMono-Regular.ttf'; Reg = 'MesloLGS Nerd Font Mono (TrueType)' }
        @{ File = 'MesloLGSNerdFontMono-Bold.ttf'; Reg = 'MesloLGS Nerd Font Mono Bold (TrueType)' }
        @{ File = 'MesloLGSNerdFontMono-Italic.ttf'; Reg = 'MesloLGS Nerd Font Mono Italic (TrueType)' }
        @{ File = 'MesloLGSNerdFontMono-BoldItalic.ttf'; Reg = 'MesloLGS Nerd Font Mono Bold Italic (TrueType)' }
        @{ File = 'MesloLGSNerdFontMono-Regular.ttf'; Reg = 'MesloLGS Nerd Font (TrueType)' }
    )
    $winFonts = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
    $regPath = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
    $removed = 0
    foreach ($e in $entries) {
        Remove-ItemProperty -Path $regPath -Name $e.Reg -ErrorAction SilentlyContinue
        $path = Join-Path $winFonts $e.File
        if (Test-Path -LiteralPath $path) {
            Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
            $removed++
        }
    }
    $null = & rundll32.exe user32.dll,UpdatePerUserSystemParameters 1, True
    if ($removed -gt 0) {
        Write-Host "Meslo Nerd Font: удалено из Windows ($removed файлов)."
    }
}

function Invoke-AlacrittyConfigMigrate {
    param([Parameter(Mandatory)][string]$DestPath)

    $alacritty = Get-Command alacritty -ErrorAction SilentlyContinue
    if (-not $alacritty) {
        return
    }
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & $alacritty.Source migrate --config-file $DestPath 2>&1 | ForEach-Object { Write-Host $_ }
    } finally {
        $ErrorActionPreference = $prevEap
    }
}

function Update-AlacrittyDeployedToml {
    param(
        [Parameter(Mandatory)][string]$DestPath,
        [string]$Msys2Root = 'C:\msys64',
        [string]$WinUser = $env:USERNAME
    )

    $homePosix = Get-Msys2HomePosixPath -Msys2Root $Msys2Root -WinUser $WinUser
    $homeLine = "working_directory = `"$homePosix`""
    $text = [System.IO.File]::ReadAllText($DestPath)
    $text = $text.Replace('__MSYS2_HOME__', $homePosix).Replace('{{MSYS2_HOME}}', $homePosix)
    if ($text -match 'working_directory\s*=') {
        $text = [regex]::Replace($text, 'working_directory\s*=\s*"[^"]*"', $homeLine)
    } else {
        $text = [regex]::Replace($text, '(\[general\][^\r\n]*)', "`$1`r`n$homeLine", 1)
    }
    $utf8Bom = New-Object System.Text.UTF8Encoding $true
    [System.IO.File]::WriteAllText($DestPath, $text, $utf8Bom)
}

function Deploy-TerminalAppSettings {
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [string]$Msys2Root = 'C:\msys64',
        [string]$WinUser = $env:USERNAME,
        [string]$Msys2Profile = 'MINGW64'
    )

    $settingsRoot = Join-Path $RepoRoot 'src\apps_settings'

    Remove-MesloNerdFontFromWindows

    $alacrittySrc = Join-Path $settingsRoot 'alacritty\alacritty.toml'
    $alacrittyDest = Join-Path $env:APPDATA 'alacritty\alacritty.toml'
    Copy-AppSettingsFile -SourcePath $alacrittySrc -DestPath $alacrittyDest -Msys2Root $Msys2Root -WinUser $WinUser -Msys2Profile $Msys2Profile
    Update-AlacrittyDeployedToml -DestPath $alacrittyDest -Msys2Root $Msys2Root -WinUser $WinUser
    Invoke-AlacrittyConfigMigrate -DestPath $alacrittyDest
    Write-Host "Alacritty: $alacrittyDest"

    $shellWin = Join-Path $Msys2Root 'msys2_shell.cmd'
    if (-not (Test-Path -LiteralPath $shellWin)) {
        throw "Для Alacritty нужен msys2_shell.cmd: $shellWin"
    }

    $msysHome = Get-Msys2HomePath -Msys2Root $Msys2Root -WinUser $WinUser
    if (-not (Test-Path -LiteralPath $msysHome)) {
        New-Item -ItemType Directory -Path $msysHome -Force | Out-Null
    }

    $zshDir = Join-Path $settingsRoot 'zsh'
    foreach ($legacyName in @('.fzf-tab-keys.zsh', '.zle-region-rprompt.zsh', 'test-copy.zsh', '.clipboard.zsh', '.zle-region-fix.zsh', '.zle-shift-select.zsh', '.zsh-shift-select.plugin.zsh', '.zle-plain-prompt.zsh')) {
        $legacyPath = Join-Path $msysHome $legacyName
        if (Test-Path -LiteralPath $legacyPath) {
            Remove-Item -LiteralPath $legacyPath -Force
            Write-Host "zsh: removed legacy $legacyName"
        }
    }
    $testDir = Join-Path $msysHome 'test1'
    if (Test-Path -LiteralPath $testDir) {
        Remove-Item -LiteralPath $testDir -Recurse -Force
        Write-Host 'zsh: removed legacy test1/'
    }

    foreach ($name in @('.zshrc', '.zsh-hotkeys.zsh', '.p10k.zsh')) {
        $src = Join-Path $zshDir $name
        if (-not (Test-Path -LiteralPath $src)) { continue }
        $dest = Join-Path $msysHome $name
        Copy-AppSettingsFile -SourcePath $src -DestPath $dest -Msys2Root $Msys2Root -WinUser $WinUser -Msys2Profile $Msys2Profile
        Write-Host "zsh: $dest"
    }
}

function Read-PacmanPackageList {
    param([Parameter(Mandatory)][string]$ListPath)

    $packages = [System.Collections.Generic.List[pscustomobject]]::new()
    foreach ($rawLine in Get-Content -LiteralPath $ListPath -Encoding UTF8) {
        $line = $rawLine.Trim()
        if ($line.Length -eq 0 -or $line.StartsWith('#')) { continue }
        $optional = $line.StartsWith('?')
        $name = if ($optional) { $line.Substring(1).Trim() } else { $line }
        if ($name.Length -eq 0) { continue }
        $packages.Add([pscustomobject]@{ Name = $name; Optional = $optional })
    }
    return $packages
}

function Get-MingwPacmanPrefix {
    param([string]$Msys2Profile = 'MINGW64')
    switch ($Msys2Profile.ToUpperInvariant()) {
        'UCRT64' { return 'mingw-w64-ucrt-x86_64' }
        'CLANG64' { return 'mingw-w64-clang-x86_64' }
        'CLANGARM64' { return 'mingw-w64-clang-aarch64' }
        default { return 'mingw-w64-x86_64' }
    }
}

function Get-PacmanPackageCandidates {
    param(
        [Parameter(Mandatory)][string]$ShortName,
        [string]$Msys2Profile = 'MINGW64'
    )

    $prefix = Get-MingwPacmanPrefix -Msys2Profile $Msys2Profile
    $msysShort = @{
        zsh = $true
        openssh = $true
        curl = $true
        unzip = $true
    }

    if ($ShortName -match '^mingw-w64-') {
        return @($ShortName)
    }
    if ($msysShort.ContainsKey($ShortName)) {
        return @($ShortName)
    }
    switch ($ShortName) {
        'ttf-meslo-nerd' {
            return @(
                "$prefix-ttf-meslo-nerd",
                "$prefix-ttf-meslo-nerd-fonts",
                "$prefix-ttf-meslo-lg-nerd-fonts",
                "$prefix-ttf-meslo-lgs-nerd-fonts"
            )
        }
        'thefuck' { return @() }
        default { return @("$prefix-$ShortName") }
    }
}
