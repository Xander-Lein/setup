#Requires -Version 5.1
param(
    [switch]$RestartExplorer,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$refreshLib = Join-Path $PSScriptRoot 'Invoke-SessionSettingsRefresh.ps1'
if (-not (Test-Path -LiteralPath $refreshLib)) {
    $refreshLib = Join-Path (Split-Path -Parent $PSScriptRoot) 'lib\Invoke-SessionSettingsRefresh.ps1'
}
. $refreshLib

if (-not $DryRun) {
    Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Clipboard' -Name 'EnableClipboardHistory' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
}
Invoke-SessionSettingsRefresh -RestartExplorer:$RestartExplorer -DryRun:$DryRun
