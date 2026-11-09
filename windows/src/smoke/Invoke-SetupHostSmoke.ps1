#Requires -Version 5.1
param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
)

$ErrorActionPreference = 'Stop'
$src = Join-Path $RepoRoot 'src'
$failed = $false

Write-Host '=== Setup host smoke ===' -ForegroundColor Cyan
$test = Join-Path $src 'run-tests.ps1'
& powershell -NoProfile -ExecutionPolicy Bypass -File $test
if ($LASTEXITCODE -ne 0) { $failed = $true }

$bats = @('download_desired_apps.bat', 'update_desired_apps.bat', 'apply_settings_to_desired_apps.bat', 'setup_system.bat', 'refresh_session.bat')
$env:ORCHESTRATOR_NO_PAUSE = '1'
foreach ($bat in $bats) {
    Write-Host "dry-run: $bat" -ForegroundColor DarkGray
    $p = Start-Process -FilePath 'cmd.exe' -ArgumentList @('/c', "cd /d `"$RepoRoot`" && `"$RepoRoot\$bat`" --dry-run") -Wait -PassThru -NoNewWindow
    if ($p.ExitCode -ne 0) {
        Write-Warning "FAIL $bat exit $($p.ExitCode)"
        $failed = $true
    }
}

if ($failed) { exit 1 }
Write-Host 'Host smoke passed.' -ForegroundColor Green
