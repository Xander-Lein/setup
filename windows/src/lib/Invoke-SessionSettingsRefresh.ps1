#Requires -Version 5.1

function Restart-UserShellExperience {
    foreach ($name in @(
            'ShellExperienceHost',
            'StartMenuExperienceHost',
            'TextInputHost',
            'SearchHost'
        )) {
        Get-Process -Name $name -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep -Milliseconds 700
}

function Restart-WindowsInputHost {
    $ctfmon = Join-Path $env:WINDIR 'System32\ctfmon.exe'
    Get-Process -Name ctfmon -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    if (Test-Path -LiteralPath $ctfmon) {
        Start-Process -FilePath $ctfmon -WindowStyle Hidden
    }
}

function Restart-ExplorerShell {
    $explorer = Get-Process -Name explorer -ErrorAction SilentlyContinue
    if (-not $explorer) {
        $shell = Join-Path $env:WINDIR 'explorer.exe'
        if (Test-Path -LiteralPath $shell) {
            Start-Process -FilePath $shell
        }
        return
    }

    Write-Host 'Restarting Explorer (taskbar may flicker ~2s). Full PC reboot is not required.' -ForegroundColor DarkYellow
    $explorer | Stop-Process -Force
    Start-Sleep -Milliseconds 1200
}

function Invoke-SessionSettingsRefresh {
    param(
        [switch]$DryRun,
        [switch]$RestartExplorer
    )

    if ($DryRun) {
        $suffix = if ($RestartExplorer) { ' + explorer' } else { '' }
        Write-Host "[dry-run] Refresh shell processes$suffix." -ForegroundColor Yellow
        return
    }

    Restart-UserShellExperience
    Restart-WindowsInputHost
    $null = & rundll32.exe user32.dll,UpdatePerUserSystemParameters 1, True

    if ($RestartExplorer) {
        Restart-ExplorerShell
    }

    Write-Host 'Session settings applied without sign-out or reboot.' -ForegroundColor Green
}

function Install-SessionRefreshAtLogon {
    param([switch]$DryRun)

    $bin = Join-Path $env:LOCALAPPDATA 'Library\setup\bin'
    $scriptPath = Join-Path $bin 'refresh-session-settings.ps1'
    $libPath = Join-Path $bin 'Invoke-SessionSettingsRefresh.ps1'
    $startup = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup'
    $shortcutPath = Join-Path $startup 'Library setup session refresh.lnk'
    $srcRoot = Split-Path -Parent $PSScriptRoot
    $sourceScript = Join-Path $srcRoot 'modules\refresh-session-settings.ps1'

    if ($DryRun) {
        Write-Host '[dry-run] Add session refresh to Windows Startup.' -ForegroundColor Yellow
        return
    }

    New-Item -ItemType Directory -Path $bin -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Invoke-SessionSettingsRefresh.ps1') -Destination $libPath -Force
    Copy-Item -LiteralPath $sourceScript -Destination $scriptPath -Force

    New-Item -ItemType Directory -Path $startup -Force | Out-Null
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = (Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe')
    $argLine = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File " + [char]34 + $scriptPath + [char]34
    $shortcut.Arguments = $argLine
    $shortcut.WorkingDirectory = $bin
    $shortcut.Save()
}
