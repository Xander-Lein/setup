#Requires -Version 5.1
param([switch]$DryRun)

$ErrorActionPreference = 'Stop'
$moduleRoot = Split-Path -Parent $PSScriptRoot
$configSource = Join-Path $moduleRoot 'apps_settings\neovim\init.lua'
$configDir = Join-Path $env:LOCALAPPDATA 'nvim'
$configTarget = Join-Path $configDir 'init.lua'

$nvim = Get-Command nvim.exe -ErrorAction SilentlyContinue
if (-not $nvim -and (Test-Path -LiteralPath (Join-Path $env:ProgramFiles 'Neovim\bin\nvim.exe'))) {
    $nvim = Get-Item (Join-Path $env:ProgramFiles 'Neovim\bin\nvim.exe')
}
if (-not $nvim) {
    Write-Warning 'Neovim не найден. Установите Neovim через download_desired_apps.bat.'
    return
}

if (Test-Path -LiteralPath $configTarget) {
    Write-Host "Neovim: конфигурация уже существует, пропуск: $configTarget" -ForegroundColor DarkGray
    return
}

if ($DryRun) {
    Write-Host "[dry-run] Создать базовую конфигурацию Neovim: $configTarget" -ForegroundColor Yellow
    return
}

New-Item -ItemType Directory -Path $configDir -Force | Out-Null
Copy-Item -LiteralPath $configSource -Destination $configTarget -Force
Write-Host "Neovim: создана базовая конфигурация $configTarget" -ForegroundColor Green
