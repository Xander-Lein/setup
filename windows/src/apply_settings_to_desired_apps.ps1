#Requires -Version 5.1
param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [string]$SettingsToml = 'desired-apps-settings.toml',
    [switch]$SkipPacmanUpgrade,
    [switch]$DryRun,
    [switch]$VerboseMode,
    [switch]$NoReboot
)

$ErrorActionPreference = 'Stop'
$libDir = Join-Path $PSScriptRoot 'lib'
. (Join-Path $libDir 'Read-TerminalSetup.ps1')

$cfg = Get-TerminalSetupConfig -RepoRoot $RepoRoot
$msys2Shell = Join-Path $cfg.Msys2Root 'msys2_shell.cmd'

Write-Host '=== Apply settings to desired apps ===' -ForegroundColor Cyan

if ($DryRun) {
    Write-Host '[dry-run] Настроить терминал и ассоциации файлов.' -ForegroundColor Yellow
    & (Join-Path $PSScriptRoot 'modules\configure_system_utilities.ps1') -DryRun -NoReboot:$NoReboot
    & (Join-Path $PSScriptRoot 'modules\configure_neovim.ps1') -DryRun
    exit 0
}

if (-not (Test-Path -LiteralPath $msys2Shell)) {
    Write-Warning "MSYS2 not found: $msys2Shell. Run download_desired_apps.bat first (terminal group)."
}

$terminalPs1 = Join-Path $PSScriptRoot 'configure-terminal.ps1'
& $terminalPs1 -RepoRoot $RepoRoot -Msys2Root $cfg.Msys2Root -Msys2Profile $cfg.Profile -SkipPacmanUpgrade:$SkipPacmanUpgrade
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$systemPs1 = Join-Path $PSScriptRoot 'modules\configure_system_utilities.ps1'
& $systemPs1 -DryRun:$DryRun -NoReboot:$NoReboot
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$neovimPs1 = Join-Path $PSScriptRoot 'modules\configure_neovim.ps1'
& $neovimPs1 -DryRun:$DryRun
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$assocPs1 = Join-Path $PSScriptRoot 'configure-file-associations.ps1'
& $assocPs1 -RepoRoot $RepoRoot -SettingsToml $SettingsToml
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host 'Done. Start Alacritty from Start menu.' -ForegroundColor Green
exit 0
