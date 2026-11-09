#Requires -Version 5.1
param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [switch]$DryRun,
    [switch]$VerboseMode
)

$ErrorActionPreference = 'Stop'

$wingetPs1 = Join-Path $PSScriptRoot 'download-desired-apps-by-winget.ps1'
$githubPs1 = Join-Path $PSScriptRoot 'install-github-apps.ps1'

Write-Host '=== Download desired apps (install only) ===' -ForegroundColor Cyan
& $wingetPs1 -RepoRoot $RepoRoot -Mode InstallOnly -DryRun:$DryRun -VerboseMode:$VerboseMode
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& $githubPs1 -RepoRoot $RepoRoot -Mode InstallOnly -DryRun:$DryRun -VerboseMode:$VerboseMode
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host 'Done.' -ForegroundColor Green
exit 0
