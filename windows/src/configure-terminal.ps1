#Requires -Version 5.1
param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [string]$Msys2Root,
    [string]$Msys2Profile,
    [switch]$SkipPacmanUpgrade,
    [switch]$ClearPacmanLock,
    [int]$PacmanRetries = 3
)

$ErrorActionPreference = 'Stop'
$libDir = Join-Path $PSScriptRoot 'lib'
. (Join-Path $libDir 'Copy-AppSettings.ps1')
. (Join-Path $libDir 'Read-TerminalSetup.ps1')

$terminalCfg = Get-TerminalSetupConfig -RepoRoot $RepoRoot
if ([string]::IsNullOrWhiteSpace($Msys2Root)) { $Msys2Root = $terminalCfg.Msys2Root }
if ([string]::IsNullOrWhiteSpace($Msys2Profile)) { $Msys2Profile = $terminalCfg.Profile }

Write-Host "configure-terminal: MSYS2=$Msys2Root профиль=$Msys2Profile" -ForegroundColor DarkGray

$script:MsysLastExitCode = 0

$msys2Shell = Join-Path $Msys2Root 'msys2_shell.cmd'
if (-not (Test-Path -LiteralPath $msys2Shell)) {
    Write-Error "MSYS2 не найден: $msys2Shell. Сначала download_desired_apps.bat (секция terminal)."
}

function ConvertTo-MsysUnixPath {
    param([Parameter(Mandatory)][string]$WinPath)
    $p = ($WinPath -replace '\\', '/').TrimEnd('/')
    if ($p -match '^([A-Za-z]):(.*)$') {
        return ('/' + $Matches[1].ToLower() + $Matches[2])
    }
    return $p
}

function Get-Msys2Msystem {
    switch ($Msys2Profile.ToUpperInvariant()) {
        'UCRT64'  { 'UCRT64' }
        'MINGW64' { 'MINGW64' }
        'CLANG64' { 'CLANG64' }
        'MSYS'    { 'MSYS' }
        default   { 'MINGW64' }
    }
}

function Invoke-Msys2 {
    param(
        [Parameter(Mandatory)][string]$Command,
        [switch]$AllowNonZeroExit
    )

    $bash = Join-Path $Msys2Root 'usr\bin\bash.exe'
    if (-not (Test-Path -LiteralPath $bash)) {
        Write-Error "bash не найден: $bash"
    }

    Write-Host "MSYS2: $Command" -ForegroundColor DarkCyan

    $savedMsystem = $env:MSYSTEM
    $savedHere = $env:CHERE_INVOKING
    $env:MSYSTEM = Get-Msys2Msystem
    $env:CHERE_INVOKING = '1'
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        # stderr pacman (warning: … up to date) не должен ронять скрипт при $ErrorActionPreference Stop
        $lines = @(& $bash -lc $Command 2>&1)
        $script:MsysLastExitCode = $LASTEXITCODE
        foreach ($line in $lines) {
            if ($line -is [System.Management.Automation.ErrorRecord]) {
                Write-Host $line.ToString()
            } else {
                Write-Host $line
            }
        }
    } finally {
        $ErrorActionPreference = $prevEap
        if ($null -eq $savedMsystem) { Remove-Item Env:MSYSTEM -ErrorAction SilentlyContinue }
        else { $env:MSYSTEM = $savedMsystem }
        if ($null -eq $savedHere) { Remove-Item Env:CHERE_INVOKING -ErrorAction SilentlyContinue }
        else { $env:CHERE_INVOKING = $savedHere }
    }

    if ($script:MsysLastExitCode -ne 0 -and -not $AllowNonZeroExit) {
        throw "MSYS2 команда завершилась с кодом $($script:MsysLastExitCode)"
    }
}

function Clear-PacmanLock {
    Invoke-Msys2 -Command 'rm -f /var/lib/pacman/db.lck' -AllowNonZeroExit
}

function Stop-Msys2BlockingProcesses {
    $root = $Msys2Root.TrimEnd('\')
    $stopped = @()
    foreach ($name in @('mintty', 'bash', 'zsh', 'msys2')) {
        Get-Process -Name $name -ErrorAction SilentlyContinue | ForEach-Object {
            if (-not $_.Path) { return }
            if ($_.Path -notlike "$root\*") { return }
            $stopped += "$name#$($_.Id)"
            Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
        }
    }
    if ($stopped.Count -gt 0) {
        Write-Host "Закрыты процессы MSYS2 для pacman: $($stopped -join ', ')" -ForegroundColor Yellow
        Start-Sleep -Seconds 2
    }
}

function Test-PacmanPendingUpdates {
    $cmd = @'
export LANG=C LC_ALL=C
pacman -Qu >/dev/null 2>&1
'@
    Invoke-Msys2 -Command $cmd -AllowNonZeroExit
    return ($script:MsysLastExitCode -eq 0)
}

function Invoke-PacmanFullSystemUpgrade {
    param([int]$MaxRounds = 6)

    Write-Host 'Обновление MSYS2 (pacman -Syu) до актуального состояния...' -ForegroundColor Yellow
    Stop-Msys2BlockingProcesses
    Clear-PacmanLock

    for ($round = 1; $round -le $MaxRounds; $round++) {
        if ($round -gt 1) {
            Write-Host "Повтор pacman -Syu ($round/$MaxRounds) — после обновления bash/msys2-runtime нужен новый проход..." -ForegroundColor Yellow
            Stop-Msys2BlockingProcesses
            Clear-PacmanLock
            Start-Sleep -Seconds 1
        }

        $syuOk = Invoke-Pacman -PacmanArgs '-Syu' -AllowFailure
        $pending = Test-PacmanPendingUpdates

        if ($syuOk -and -not $pending) {
            Write-Host 'Система пакетов MSYS2 актуальна.' -ForegroundColor Green
            return
        }

        if (-not $syuOk) {
            Write-Host "pacman -Syu: код $($script:MsysLastExitCode) (сеть/TLS или lock); следующая попытка..." -ForegroundColor Yellow
        } elseif ($pending) {
            Write-Host 'Есть необновлённые пакеты — ещё один проход...' -ForegroundColor Yellow
        }
    }

    if (Test-PacmanPendingUpdates) {
        throw @"
pacman -Syu не довёл MSYS2 до актуального состояния за $MaxRounds проходов.
Проверьте TLS/зеркала, удалите lock: $Msys2Root\var\lib\pacman\db.lck
или выполните в MSYS2: pacman -Syu --noconfirm
"@
    }
}

function Get-PacmanShellCommand {
    param([string]$PacmanArgs)
    # LANG=C — стабильный вывод; yes — на случай запроса [Y/n] при сбоях сети
    return @"
export LANG=C LC_ALL=C LC_MESSAGES=C
export PACMAN_OPTS='--noconfirm --disable-download-timeout'
yes | pacman $PacmanArgs --noconfirm --disable-download-timeout
"@
}

function Invoke-Pacman {
    param(
        [Parameter(Mandatory)][string]$PacmanArgs,
        [switch]$AllowFailure,
        [int]$Retries = 0
    )

    $maxAttempts = if ($Retries -gt 0) { $Retries } else { $PacmanRetries }
    $cmd = Get-PacmanShellCommand -PacmanArgs $PacmanArgs
    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        Invoke-Msys2 -Command $cmd -AllowNonZeroExit
        if ($script:MsysLastExitCode -eq 0) {
            return $true
        }
        if ($attempt -lt $maxAttempts) {
            Write-Host "Повтор pacman ($attempt/$maxAttempts) через 8 с..." -ForegroundColor Yellow
            Start-Sleep -Seconds 8
        }
    }
    if (-not $AllowFailure) {
        throw "pacman не выполнился: $PacmanArgs (код $($script:MsysLastExitCode))"
    }
    return $false
}

if ($ClearPacmanLock) {
    Clear-PacmanLock
}

if (-not $SkipPacmanUpgrade) {
    Invoke-PacmanFullSystemUpgrade
}

$pkgListPath = Join-Path $RepoRoot 'src\apps_settings\msys2\pacman-packages.txt'
$packageEntries = Read-PacmanPackageList -ListPath $pkgListPath

$installFailed = @()
foreach ($entry in $packageEntries) {
    $candidates = Get-PacmanPackageCandidates -ShortName $entry.Name -Msys2Profile $Msys2Profile
    if ($candidates.Count -eq 0) { continue }

    $installed = $false
    $pkgRetries = if ($entry.Optional) { 1 } else { 0 }
    foreach ($pkg in $candidates) {
        if (Invoke-Pacman -PacmanArgs "-S --needed $pkg" -AllowFailure -Retries $pkgRetries) {
            $installed = $true
            break
        }
    }

    if ($installed) { continue }

    $shortName = $entry.Name
    if ($entry.Optional) {
        Write-Warning "Опциональный пакет не установлен: $($candidates -join ' | ') (код $($script:MsysLastExitCode)). Проверьте: pacman -Ss $shortName"
        continue
    }

    $installFailed += ($candidates[-1])
    Write-Warning "Не установлен пакет: $($candidates -join ' | ') (код $($script:MsysLastExitCode)). Проверьте: pacman -Ss $shortName"
}

if ($installFailed.Count -gt 0) {
    throw @"
Не установлены пакеты pacman: $($installFailed -join ', ')
Часто TLS/зеркала mirror.msys2.org — повторите apply_settings_to_desired_apps.bat
При lock: configure-terminal.ps1 -ClearPacmanLock
"@
}

$msysHomeUnix = "/home/$env:USERNAME"
$omzMarker = Join-Path (Join-Path $Msys2Root "home\$env:USERNAME") '.oh-my-zsh'

if (-not (Test-Path -LiteralPath $omzMarker)) {
    Write-Host 'Установка Oh My Zsh...' -ForegroundColor Green
    $omzInstall = @'
export RUNZSH=no CHSH=no KEEP_ZSHRC=yes
curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh | sh
'@
    Invoke-Msys2 -Command $omzInstall
} else {
    Write-Host 'Oh My Zsh уже установлен.' -ForegroundColor DarkGray
}

$zshCustom = "$msysHomeUnix/.oh-my-zsh/custom"
$omzExtrasShWin = Join-Path $RepoRoot 'src\apps_settings\zsh\install-omz-extras.sh'
if (-not (Test-Path -LiteralPath $omzExtrasShWin)) {
    throw "Не найден скрипт: $omzExtrasShWin"
}
$omzExtrasShUnix = ConvertTo-MsysUnixPath -WinPath $omzExtrasShWin

function Test-OmzExtrasInstalled {
    $custom = Join-Path (Join-Path $Msys2Root "home\$env:USERNAME") '.oh-my-zsh\custom'
    foreach ($rel in @(
            'themes\powerlevel10k',
            'plugins\zsh-autosuggestions',
            'plugins\zsh-syntax-highlighting',
            'plugins\zsh-history-substring-search'
        )) {
        if (-not (Test-Path -LiteralPath (Join-Path $custom $rel))) {
            return $false
        }
    }
    return $true
}

Write-Host 'Темы и плагины zsh...' -ForegroundColor Green
Invoke-Msys2 -Command "export ZSH_CUSTOM='$zshCustom' && bash '$omzExtrasShUnix'"
if (-not (Test-OmzExtrasInstalled)) {
    throw 'Не установлены powerlevel10k или плагины zsh (git clone). Проверьте сеть и mingw-w64-*-git.'
}

function Ensure-MsysBashProfileZshHandoff {
    param(
        [string]$Msys2Root = 'C:\msys64',
        [string]$WinUser = $env:USERNAME
    )

    $profilePath = Join-Path (Join-Path $Msys2Root "home\$WinUser") '.bash_profile'
    $begin = '# >>> windows-setup zsh-handoff >>>'
    $end = '# <<< windows-setup zsh-handoff <<<'
    $block = @"
$begin
case `$- in
  *i*) [ -z "`${ZSH_VERSION:-}" ] && exec zsh -il ;;
esac
$end
"@

    $existing = if (Test-Path -LiteralPath $profilePath) {
        [System.IO.File]::ReadAllText($profilePath)
    } else {
        ''
    }

    if ($existing.Contains($begin)) {
        $pattern = [regex]::Escape($begin) + '[\s\S]*?' + [regex]::Escape($end)
        $updated = [regex]::Replace($existing, $pattern, $block.TrimEnd())
    } else {
        $updated = if ($existing.Length -gt 0 -and -not $existing.EndsWith("`n")) {
            $existing + "`n`n" + $block
        } elseif ($existing.Length -gt 0) {
            $existing + "`n" + $block
        } else {
            $block
        }
    }

    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($profilePath, $updated, $utf8NoBom)
}

Deploy-TerminalAppSettings -RepoRoot $RepoRoot -Msys2Root $Msys2Root -WinUser $env:USERNAME -Msys2Profile $Msys2Profile
Ensure-MsysBashProfileZshHandoff -Msys2Root $Msys2Root -WinUser $env:USERNAME

$msysystem = Get-Msys2Msystem
$zshTest = @"
export MSYSTEM=$msysystem CHERE_INVOKING=1 LANG=C LC_ALL=C
/usr/bin/zsh -il -c 'echo zsh=`${ZSH_VERSION:-none}; pwd'
"@
Write-Host 'Проверка zsh для Alacritty...' -ForegroundColor DarkGray
Invoke-Msys2 -Command $zshTest

Write-Host 'Настройка терминала завершена. Запустите Alacritty.' -ForegroundColor Cyan
