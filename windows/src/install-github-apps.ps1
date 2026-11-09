#Requires -Version 5.1
param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [string]$TomlFile = 'desired-apps.toml',
    [ValidateSet('InstallOnly', 'UpgradeOnly')]
    [string]$Mode = 'InstallOnly',
    [switch]$DryRun,
    [switch]$VerboseMode
)

$ErrorActionPreference = 'Stop'
$libDir = Join-Path $PSScriptRoot 'lib'
. (Join-Path $libDir 'Read-DesiredApps.ps1')
. (Join-Path $libDir 'GitHubRelease.ps1')

$tomlPath = Join-Path $RepoRoot $TomlFile
if (-not (Test-Path -LiteralPath $tomlPath)) {
    Write-Error "Not found: $tomlPath"
}

$parsed = Read-DesiredApps -TomlPath $tomlPath
if ($parsed.GitHubApps.Count -eq 0) {
    Write-Host 'No GitHub apps in config.' -ForegroundColor DarkGray
    exit 0
}

function Invoke-GitHubApp {
    param(
        [Parameter(Mandatory)][string]$AppId,
        [Parameter(Mandatory)]$Config,
        [Parameter(Mandatory)][ValidateSet('InstallOnly', 'UpgradeOnly')][string]$Mode
    )

    $repo = $Config.repo
    $assetGlob = $Config.asset_glob
    if (-not $repo -or -not $assetGlob) {
        Write-Warning "GitHub app '$AppId' missing repo or asset_glob"
        return
    }

    $displayName = $Config.display_name
    $detectExe = $Config.detect_exe
    $installArgs = [string]$Config.install_args
    $state = Get-GitHubAppInstalledVersion -DisplayName $displayName -DetectExe $detectExe

    if ($Mode -eq 'InstallOnly' -and $state.Installed) {
        Write-Host "Skip (installed): github.$AppId" -ForegroundColor DarkGray
        return
    }

    $release = Get-LatestStableGitHubRelease -Repo $repo
    if (-not $release) {
        Write-Warning "No stable release for $repo"
        return
    }

    $remoteVersion = Normalize-AppVersionString -Version $release.tag_name
    if ($Mode -eq 'UpgradeOnly' -and $state.Installed) {
        $cmp = Compare-AppVersion -Installed $state.Version -Remote $remoteVersion
        if ($cmp -eq 'SameOrNewer') {
            Write-Host "Up to date: github.$AppId ($($state.Version))" -ForegroundColor DarkGray
            return
        }
    }

    $asset = Select-ReleaseAsset -Release $release -AssetGlob $assetGlob
    if (-not $asset) {
        Write-Warning "No asset matching '$assetGlob' in $($release.tag_name) for $repo"
        return
    }

    if ($DryRun) {
        Write-Host "[dry-run] GitHub $Mode`: $repo/$($release.tag_name) -> $($asset.name)" -ForegroundColor Yellow
        return
    }

    $cacheDir = Join-Path $env:TEMP 'setup-github-apps'
    New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
    $installerPath = Join-Path $cacheDir $asset.name

    Write-Host "Release: $($release.tag_name) — https://github.com/$repo/releases" -ForegroundColor Cyan
    Write-Host "Download: $($asset.name) ..." -ForegroundColor Cyan
    Write-Host "  $($asset.browser_download_url)" -ForegroundColor DarkGray
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $installerPath -UseBasicParsing

    $argList = @()
    if ($installArgs) {
        $argList = $installArgs.Split(' ', [StringSplitOptions]::RemoveEmptyEntries)
    }

    Write-Host "Install: github.$AppId ..." -ForegroundColor Green
    if ($argList.Count -gt 0) {
        $proc = Start-Process -FilePath $installerPath -ArgumentList $argList -Wait -PassThru
    } else {
        $proc = Start-Process -FilePath $installerPath -Wait -PassThru
    }

    if ($proc.ExitCode -ne 0) {
        Write-Warning "Installer exit code $($proc.ExitCode) for github.$AppId"
    }
}

foreach ($appId in ($parsed.GitHubApps.Keys | Sort-Object)) {
    Invoke-GitHubApp -AppId $appId -Config $parsed.GitHubApps[$appId] -Mode $Mode
}

Write-Host 'GitHub apps done.' -ForegroundColor Cyan
exit 0
