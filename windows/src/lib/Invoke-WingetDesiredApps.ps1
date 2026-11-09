#Requires -Version 5.1

function Test-WingetUpgradeNotNeeded {
    param(
        [int]$ExitCode,
        [string[]]$OutputLines
    )
    if ($ExitCode -eq 0) { return $true }
    $text = ($OutputLines -join "`n")
    if ($text -match 'No available upgrade|No newer package|already has the latest|Nothing to upgrade|нет доступных обновлений|уже установлена последняя|Доступные обновления не найдены|Более новые версии пакетов недоступны|Невозможно определить номер версии') {
        return $true
    }
    if ($ExitCode -in @(-1978335189, -1978335188, 2316632107, 2316632108)) {
        return $true
    }
    return $false
}

function Get-WingetDesiredAppAction {
    param(
        [Parameter(Mandatory)][string]$AppId,
        [Parameter(Mandatory)][ValidateSet('InstallOnly', 'UpgradeOnly')][string]$Mode,
        [bool]$IsInstalled
    )

    if ($Mode -eq 'InstallOnly') {
        if ($IsInstalled) { return 'Skip' }
        return 'Install'
    }

    if (-not $IsInstalled) { return 'Install' }
    return 'Upgrade'
}

function Stop-WingetUpgradeBlockers {
    param([Parameter(Mandatory)][string]$AppId)

    switch ($AppId) {
        'Discord.Discord' {
            $stopped = @()
            Get-Process -ErrorAction SilentlyContinue | ForEach-Object {
                $p = $_
                if ($p.Name -match '^Discord' -or ($p.Path -and $p.Path -like '*\AppData\Local\Discord\*')) {
                    $stopped += "$($p.Name)#$($p.Id)"
                    Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
                }
            }
            if ($stopped.Count -gt 0) {
                Write-Host "Stopped Discord for upgrade: $($stopped -join ', ')" -ForegroundColor Yellow
                Start-Sleep -Seconds 3
            }
        }
    }
}
