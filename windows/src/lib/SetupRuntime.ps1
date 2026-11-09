#Requires -Version 5.1

function New-SetupRuntime {
    param(
        [string]$LogName = 'setup',
        [switch]$VerboseMode
    )

    $logRoot = Join-Path $env:LOCALAPPDATA 'Library\setup\logs'
    if (-not (Test-Path -LiteralPath $logRoot)) {
        New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
    }

    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $logPath = Join-Path $logRoot "$LogName-$stamp.log"
    Start-Transcript -Path $logPath -Force | Out-Null

    return [pscustomobject]@{
        LogPath = $logPath
        VerboseMode = [bool]$VerboseMode
    }
}

function Stop-SetupRuntime {
    try { Stop-Transcript | Out-Null } catch {}
}

function Write-SetupAction {
    param(
        [Parameter(Mandatory)][string]$Message,
        [switch]$WouldChange
    )

    if ($WouldChange) {
        Write-Host "[dry-run] $Message" -ForegroundColor Yellow
    } else {
        Write-Host $Message -ForegroundColor DarkGray
    }
}

function Test-SetupDryRun {
    param([switch]$DryRun)
    return [bool]$DryRun
}
