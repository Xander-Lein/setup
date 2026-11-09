#Requires -Version 5.1
param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [string]$TomlFile = 'desired-apps.toml',
    [switch]$DryRun,
    [switch]$VerboseMode
)

$ErrorActionPreference = 'Stop'
$libDir = Join-Path $PSScriptRoot 'lib'
. (Join-Path $libDir 'Read-DesiredApps.ps1')
. (Join-Path $libDir 'Invoke-WingetDesiredApps.ps1')
. (Join-Path $libDir 'GitHubRelease.ps1')

$tomlPath = Join-Path $RepoRoot $TomlFile
$parsed = Read-DesiredApps -TomlPath $tomlPath

Write-Host '=== Remove desired apps from this PC ===' -ForegroundColor Yellow
Write-Host 'Config only lists what to remove; repo files are unchanged.' -ForegroundColor DarkGray

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Warning 'winget not in PATH — skipping winget uninstall.'
} else {
    foreach ($appId in $parsed.AppIds) {
        Write-Host "winget uninstall: $appId ..." -ForegroundColor Yellow
        if ($DryRun) {
            Write-Host "[dry-run] winget uninstall --id $appId" -ForegroundColor Yellow
            continue
        }
        $lines = @( & winget uninstall --id $appId -e --disable-interactivity --accept-source-agreements --silent 2>&1 )
        foreach ($line in $lines) { Write-Host $line }
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "winget uninstall exit $($LASTEXITCODE) for $appId"
        }
    }
}

foreach ($appId in ($parsed.GitHubApps.Keys | Sort-Object)) {
    $gh = $parsed.GitHubApps[$appId]
    Write-Host "GitHub uninstall: $appId ..." -ForegroundColor Yellow
    if ($DryRun) { continue }
    $ok = Invoke-GitHubAppUninstall -DisplayName $gh.display_name -DetectExe $gh.detect_exe
    if (-not $ok) {
        Write-Warning "Could not uninstall github.$appId automatically."
    }
}

Write-Host 'Done.' -ForegroundColor Cyan
exit 0
