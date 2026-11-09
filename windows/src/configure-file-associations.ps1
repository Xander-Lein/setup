#Requires -Version 5.1
param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [string]$AppsToml = 'desired-apps.toml',
    [string]$SettingsToml = 'desired-apps-settings.toml'
)

$ErrorActionPreference = 'Stop'
$libDir = Join-Path $PSScriptRoot 'lib'
. (Join-Path $libDir 'Read-DesiredApps.ps1')
. (Join-Path $libDir 'FileAssociations.ps1')

$appsPath = Join-Path $RepoRoot $AppsToml
$settingsPath = Join-Path $RepoRoot $SettingsToml
$appsParsed = Read-DesiredApps -TomlPath $appsPath
$settingsParsed = Read-DesiredApps -TomlPath $settingsPath

if ($settingsParsed.Associations.Count -eq 0) {
    Write-Host 'No file associations in settings config.' -ForegroundColor DarkGray
    exit 0
}

foreach ($assocId in ($settingsParsed.Associations.Keys | Sort-Object)) {
    $cfg = $settingsParsed.Associations[$assocId]
    $progId = $cfg.prog_id
    $friendly = $cfg.friendly_name
    $extensions = @($cfg.extensions)

    if (-not $progId -or -not $friendly -or $extensions.Count -eq 0) {
        Write-Warning "Association '$assocId' missing prog_id, friendly_name, or extensions"
        continue
    }

    $exePath = Resolve-AssociationExePath -AssociationConfig $cfg -GitHubApps $appsParsed.GitHubApps
    if (-not $exePath -or -not (Test-Path -LiteralPath $exePath)) {
        Write-Warning "Association '$assocId': executable not found (run download_desired_apps.bat first)"
        continue
    }

    Write-Host "Associations: $assocId -> $exePath" -ForegroundColor Cyan
    Register-UserFileAssociation -ProgId $progId -FriendlyName $friendly -ExePath $exePath -Extensions $extensions
}

Write-Host 'File associations done.' -ForegroundColor Cyan
exit 0
