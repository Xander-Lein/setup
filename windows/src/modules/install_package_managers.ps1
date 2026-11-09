#Requires -Version 5.1
param([switch]$DryRun)

$ErrorActionPreference = 'Stop'

Write-Host '=== Package managers ===' -ForegroundColor Cyan

$winget = Get-Command winget.exe -ErrorAction SilentlyContinue
if ($winget) {
    Write-Host "winget: $($winget.Source)" -ForegroundColor Green
    exit 0
}

if ($DryRun) {
    Write-Host '[dry-run] Проверить/установить App Installer, предоставляющий winget.' -ForegroundColor Yellow
    exit 0
}

$appInstaller = Get-AppxPackage -Name Microsoft.DesktopAppInstaller -ErrorAction SilentlyContinue
if (-not $appInstaller) {
    throw 'winget не найден. Установите App Installer из Microsoft Store, затем повторите запуск.'
}

throw 'App Installer найден, но winget ещё не появился в PATH. Перезапустите PowerShell и повторите запуск.'
