#Requires -Version 5.1
param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [string]$TomlFile = 'desired-apps.toml',
    [ValidateSet('InstallOnly', 'UpgradeOnly')]
    [string]$Mode = 'UpgradeOnly',
    [switch]$DryRun,
    [switch]$VerboseMode
)

$ErrorActionPreference = 'Stop'
$libDir = Join-Path $PSScriptRoot 'lib'
. (Join-Path $libDir 'Read-DesiredApps.ps1')
. (Join-Path $libDir 'Invoke-WingetDesiredApps.ps1')

if (-not (Test-Path -LiteralPath $RepoRoot)) {
    Write-Error "Каталог репозитория не найден: $RepoRoot"
}

$tomlPath = Join-Path $RepoRoot $TomlFile
if (-not (Test-Path -LiteralPath $tomlPath)) {
    Write-Error "Не найден $TomlFile в $RepoRoot"
}

$parsed = Read-DesiredApps -TomlPath $tomlPath
if ($parsed.AppIds.Count -eq 0) {
    Write-Host 'Нет winget-приложений в конфиге.' -ForegroundColor DarkGray
    exit 0
}

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    if ($DryRun) {
        Write-Warning 'winget не найден; dry-run продолжит без проверки установленности.'
    } else {
        Write-Error "winget не найден в PATH. Установите App Installer из Microsoft Store."
    }
}

$wingetArgs = @()
if ($parsed.Winget.accept_source_agreements) {
    $wingetArgs += '--accept-source-agreements'
}

function Invoke-WingetCli {
    param(
        [Parameter(Mandatory)][ValidateSet('install', 'upgrade')][string]$Verb,
        [Parameter(Mandatory)][string]$AppId
    )
    $common = @(
        $Verb, '--id', $AppId, '-e',
        '--accept-package-agreements',
        '--disable-interactivity',
        '--silent'
    ) + $wingetArgs

    $lines = [System.Collections.Generic.List[string]]::new()
    # Не @(& winget ...) — иначе весь вывод буферизуется до конца (кажется «зависло»).
    & winget.exe @common 2>&1 | ForEach-Object {
        $text = $_.ToString()
        $lines.Add($text) | Out-Null
        Write-Host $text
    }
    return @{ ExitCode = $LASTEXITCODE; Lines = [string[]]$lines }
}

function Test-WingetAppInstalled {
    param([string]$Id)
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'
    try {
        $out = & winget list --id $Id -e 2>&1
        if ($LASTEXITCODE -ne 0) { return $false }
        return ($out | Select-String -Pattern $Id -Quiet)
    } finally {
        $ErrorActionPreference = $prev
    }
}

function Invoke-WingetDesiredApp {
    param([Parameter(Mandatory)][string]$AppId)

    $installed = Test-WingetAppInstalled -Id $AppId
    $action = Get-WingetDesiredAppAction -AppId $AppId -Mode $Mode -IsInstalled $installed

    switch ($action) {
        'Skip' {
            Write-Host "Пропуск (установлено): $AppId" -ForegroundColor DarkGray
            return
        }
        'Install' {
            Write-Host "Установка: $AppId ..." -ForegroundColor Green
            if ($DryRun) {
                Write-Host "[dry-run] winget install --id $AppId" -ForegroundColor Yellow
                return
            }
            Write-Host '  (winget: загрузка и установка могут занять несколько минут; смотрите прогресс ниже)' -ForegroundColor DarkGray
            $result = Invoke-WingetCli -Verb install -AppId $AppId
            if ($result.ExitCode -ne 0) {
                Write-Warning "winget install завершился с кодом $($result.ExitCode) для $AppId"
            }
            return
        }
        'Upgrade' {
            Write-Host "Обновление (если доступно): $AppId ..." -ForegroundColor Yellow
            if ($DryRun) {
                Write-Host "[dry-run] winget upgrade --id $AppId" -ForegroundColor Yellow
                return
            }
            Stop-WingetUpgradeBlockers -AppId $AppId
            $result = Invoke-WingetCli -Verb upgrade -AppId $AppId
            if (Test-WingetUpgradeNotNeeded -ExitCode $result.ExitCode -OutputLines $result.Lines) {
                Write-Host "Актуально: $AppId" -ForegroundColor DarkGray
                return
            }

            $squirrelLock = ($result.Lines -join "`n") -match 'Squirrel|Отказано в доступе|still running|app still running'
            if ($squirrelLock -and $AppId -eq 'Discord.Discord') {
                Write-Host 'Повтор Discord после закрытия процессов...' -ForegroundColor Yellow
                Stop-WingetUpgradeBlockers -AppId $AppId
                Start-Sleep -Seconds 2
                $result = Invoke-WingetCli -Verb upgrade -AppId $AppId
                if (Test-WingetUpgradeNotNeeded -ExitCode $result.ExitCode -OutputLines $result.Lines) {
                    Write-Host "Актуально: $AppId" -ForegroundColor DarkGray
                    return
                }
            }

            Write-Warning @"
winget upgrade завершился с кодом $($result.ExitCode) для $AppId.
Если это Discord: полностью выйдите из Discord (трей → Выход) и запустите update_desired_apps.bat снова.
"@
        }
    }
}

Write-Host "winget ($Mode): $($parsed.AppIds.Count) приложений" -ForegroundColor Cyan
foreach ($group in $parsed.Groups.Keys | Sort-Object) {
    $ids = $parsed.Groups[$group]
    if ($ids.Count -gt 0) {
        Write-Host "  [$group]: $($ids -join ', ')"
    }
}

if ($DryRun) {
    $verb = if ($Mode -eq 'InstallOnly') { 'install' } else { 'upgrade' }
    foreach ($appId in $parsed.AppIds) {
        Write-Host "[dry-run] winget $verb --id $appId" -ForegroundColor Yellow
    }
    exit 0
}

foreach ($appId in $parsed.AppIds) {
    Invoke-WingetDesiredApp -AppId $appId
}

Write-Host "Готово." -ForegroundColor Cyan
exit 0
