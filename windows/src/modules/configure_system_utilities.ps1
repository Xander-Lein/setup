#Requires -Version 5.1
param(
    [switch]$DryRun,
    [switch]$NoReboot
)

$ErrorActionPreference = 'Stop'
$moduleRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $moduleRoot 'lib\SetupRuntime.ps1')
. (Join-Path $moduleRoot 'lib\Invoke-SessionSettingsRefresh.ps1')

function Set-RegistryValueIfNeeded {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)]$Value,
        [Microsoft.Win32.RegistryValueKind]$Type = [Microsoft.Win32.RegistryValueKind]::String
    )

    if ($DryRun) {
        Write-SetupAction "Установить реестровый параметр $Path\$Name = $Value" -WouldChange
        return
    }

    New-Item -Path $Path -Force | Out-Null
    $current = (Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue).$Name
    if ($null -eq $current) {
        New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $Type.ToString() -Force | Out-Null
    } elseif ($current -ne $Value) {
        Set-ItemProperty -Path $Path -Name $Name -Value $Value
    }
}

function Configure-WindowsLanguages {
    Write-SetupAction 'Проверка языков Windows: польский (pl-PL) и русский (ru-RU).'
    if ($DryRun) {
        Write-SetupAction 'Настроить переключение раскладок через Alt+Shift' -WouldChange
        return
    }

    $getLanguages = Get-Command Get-WinUserLanguageList -ErrorAction SilentlyContinue
    $setLanguages = Get-Command Set-WinUserLanguageList -ErrorAction SilentlyContinue
    if (-not $getLanguages -or -not $setLanguages) {
        Write-Warning 'Командлеты языков Windows недоступны. Настройка пропущена.'
        return
    }

    # Русский первым: Windows использует первый язык как основной для
    # пользовательского интерфейса и первичной раскладки.
    $languages = New-WinUserLanguageList 'ru-RU'
    $languages.Add('pl-PL')
    Set-WinUserLanguageList $languages -Force
    Set-WinDefaultInputMethodOverride -InputTip '0419:00000419' -ErrorAction SilentlyContinue

    $setUiLanguage = Get-Command Set-WinUILanguageOverride -ErrorAction SilentlyContinue
    if ($setUiLanguage) {
        try {
            Set-WinUILanguageOverride -Language 'ru-RU'
        } catch {
            Write-Warning "Не удалось установить русский язык интерфейса: $($_.Exception.Message)"
        }
    }

    $toggleKey = 'HKCU:\Keyboard Layout\Toggle'
    Set-RegistryValueIfNeeded -Path $toggleKey -Name 'Hotkey' -Value '1'
    Set-RegistryValueIfNeeded -Path $toggleKey -Name 'Language Hotkey' -Value '1'
    Set-RegistryValueIfNeeded -Path $toggleKey -Name 'Toggle' -Value '1'
    if (-not $DryRun) {
        & reg.exe ADD 'HKCU\Keyboard Layout\Toggle' /v Hotkey /t REG_SZ /d 1 /f | Out-Null
        & reg.exe ADD 'HKCU\Keyboard Layout\Toggle' /v 'Language Hotkey' /t REG_SZ /d 1 /f | Out-Null
        & reg.exe ADD 'HKCU\Keyboard Layout\Toggle' /v Toggle /t REG_SZ /d 1 /f | Out-Null
    }

    if ($NoReboot) {
        Write-Warning 'Полную перезагрузку ПК setup не делает: после настроек перезапускается оболочка Windows.'
    }
}

function Configure-ClipboardHistory {
    Write-SetupAction 'Включение истории буфера обмена Windows (Win+V).'
    Set-RegistryValueIfNeeded `
        -Path 'HKCU:\Software\Microsoft\Clipboard' `
        -Name 'EnableClipboardHistory' `
        -Value 1 `
        -Type DWord
    if (-not $DryRun) {
        Install-SessionRefreshAtLogon
    }
}

function Get-AutoHotkeyPath {
    $command = Get-Command AutoHotkey64.exe -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }
    $command = Get-Command AutoHotkey.exe -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }

    foreach ($root in @($env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:LOCALAPPDATA)) {
        if (-not $root) { continue }
        foreach ($relative in @(
                'AutoHotkey\AutoHotkey.exe',
                'Programs\AutoHotkey\v2\AutoHotkey64.exe',
                'Programs\AutoHotkey\v2\AutoHotkey32.exe'
            )) {
            $candidate = Join-Path $root $relative
            if (Test-Path -LiteralPath $candidate) { return $candidate }
        }
    }
    return $null
}

function Install-StartupHotkeys {
    $destination = Join-Path $env:LOCALAPPDATA 'Library\setup\bin'
    $ahkPath = Join-Path $destination 'setup-hotkeys.ahk'
    $launcherPath = Join-Path $destination 'launch-utility.ps1'
    $startup = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup'
    $shortcutPath = Join-Path $startup 'Library setup hotkeys.lnk'

    $ahk = @'
#Requires AutoHotkey v2.0
#SingleInstance Force
#UseHook

launch(target) {
    command := 'powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "' A_ScriptDir '\launch-utility.ps1" -Target ' target
    Run(command, , 'Hide')
}

#t::launch('terminal')
#f::launch('everything')
#b::launch('browser')
#m::launch('task-manager')
'@

    if ($DryRun) {
        Write-SetupAction 'Создать AutoHotkey-обработчики Win+T, Win+F, Win+B и Win+M и добавить их в автозапуск.' -WouldChange
        return
    }

    $autoHotkey = Get-AutoHotkeyPath
    if (-not $autoHotkey) {
        Write-Warning 'AutoHotkey не найден. Установите AutoHotkey.AutoHotkey и повторите apply_settings_to_desired_apps.bat.'
        return
    }

    New-Item -ItemType Directory -Path $destination -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $moduleRoot 'launch-utility.ps1') -Destination $launcherPath -Force
    [IO.File]::WriteAllText($ahkPath, $ahk.Trim() + "`r`n", (New-Object System.Text.UTF8Encoding $false))

    New-Item -ItemType Directory -Path $startup -Force | Out-Null
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $autoHotkey
    $shortcut.Arguments = "`"$ahkPath`""
    $shortcut.WorkingDirectory = $destination
    $shortcut.Save()

    Start-Process -FilePath $autoHotkey -ArgumentList "`"$ahkPath`""
    Write-Host 'Горячие клавиши Windows настроены: Win+T, Win+F, Win+B, Win+M.' -ForegroundColor Green
}

Configure-WindowsLanguages
Configure-ClipboardHistory
Install-StartupHotkeys

if ($DryRun) {
    Invoke-SessionSettingsRefresh -RestartExplorer -DryRun
    Install-SessionRefreshAtLogon -DryRun
} else {
    Invoke-SessionSettingsRefresh -RestartExplorer
    Write-Host 'Перезагрузка ПК не требуется. Если Win+V или язык не обновились, запустите refresh_session.bat.' -ForegroundColor Cyan
}
