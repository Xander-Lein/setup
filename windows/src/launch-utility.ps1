#Requires -Version 5.1
param(
    [Parameter(Mandatory)]
    [ValidateSet('terminal', 'everything', 'browser', 'task-manager')]
    [string]$Target
)

$ErrorActionPreference = 'Stop'

function Resolve-Executable {
    param(
        [string[]]$Names,
        [string[]]$Paths
    )

    foreach ($name in $Names) {
        $command = Get-Command $name -ErrorAction SilentlyContinue
        if ($command) { return $command.Source }
    }

    foreach ($path in $Paths) {
        if (Test-Path -LiteralPath $path) { return $path }
    }

    return $null
}

switch ($Target) {
    'terminal' {
        $path = Resolve-Executable -Names @('alacritty.exe', 'alacritty') -Paths @(
            (Join-Path $env:LOCALAPPDATA 'Programs\Alacritty\alacritty.exe'),
            (Join-Path $env:ProgramFiles 'Alacritty\alacritty.exe')
        )
    }
    'everything' {
        $path = Resolve-Executable -Names @('Everything.exe', 'everything') -Paths @(
            (Join-Path $env:ProgramFiles 'Everything\Everything.exe'),
            (Join-Path ${env:ProgramFiles(x86)} 'Everything\Everything.exe')
        )
        if ($path) {
            Start-Process -FilePath $path -ArgumentList '-newwindow'
            exit 0
        }
    }
    'browser' {
        $path = Resolve-Executable -Names @('zen.exe', 'zen') -Paths @(
            (Join-Path $env:LOCALAPPDATA 'Programs\Zen Browser\zen.exe'),
            (Join-Path $env:ProgramFiles 'Zen Browser\zen.exe')
        )
    }
    'task-manager' {
        $path = Resolve-Executable -Names @('Taskmgr.exe', 'taskmgr') -Paths @(
            (Join-Path $env:windir 'System32\taskmgr.exe')
        )
    }
}

if (-not $path) {
    throw "Не найден исполняемый файл для цели '$Target'. Установите соответствующее приложение."
}

Start-Process -FilePath $path
