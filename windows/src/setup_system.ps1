#Requires -Version 5.1
param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [switch]$DryRun,
    [switch]$VerboseMode,
    [switch]$NoReboot,
    [switch]$SkipPacmanUpgrade
)

$ErrorActionPreference = 'Stop'
$runtime = $null
. (Join-Path $PSScriptRoot 'lib\SetupRuntime.ps1')

function Invoke-SetupStep {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$ScriptPath,
        [hashtable]$Arguments = @{}
    )

    Write-Host "`n=== $Name ===" -ForegroundColor Cyan
    & $ScriptPath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Name завершился с кодом $LASTEXITCODE"
    }
}

try {
    $runtime = New-SetupRuntime -LogName 'setup-system' -VerboseMode:$VerboseMode
    Write-Host "Лог: $($runtime.LogPath)" -ForegroundColor DarkGray
    Write-Host "Корень setup: $RepoRoot" -ForegroundColor DarkGray

    $packageManagers = Join-Path $PSScriptRoot 'modules\install_package_managers.ps1'
    & $packageManagers -DryRun:$DryRun
    if ($LASTEXITCODE -ne 0) { throw "Проверка пакетных менеджеров завершилась с кодом $LASTEXITCODE" }

    $download = Join-Path $PSScriptRoot 'download_desired_apps.ps1'
    Invoke-SetupStep -Name 'Приложения' -ScriptPath $download -Arguments @{
        RepoRoot = $RepoRoot
        DryRun = $DryRun
        VerboseMode = $VerboseMode
    }

    $apply = Join-Path $PSScriptRoot 'apply_settings_to_desired_apps.ps1'
    Invoke-SetupStep -Name 'Настройки терминала и системы' -ScriptPath $apply -Arguments @{
        RepoRoot = $RepoRoot
        SkipPacmanUpgrade = $SkipPacmanUpgrade
        DryRun = $DryRun
        VerboseMode = $VerboseMode
        NoReboot = $NoReboot
    }

    Write-Host "`nПолная настройка Windows завершена." -ForegroundColor Green
    if ($NoReboot) {
        Write-Host 'Автоматическая перезагрузка запрещена параметром -NoReboot.' -ForegroundColor DarkGray
    }
    exit 0
} catch {
    Write-Error $_
    exit 1
} finally {
    if ($runtime) { Stop-SetupRuntime }
}
