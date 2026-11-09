#Requires -Version 5.1
<#
.SYNOPSIS
  Подключает актуальные каталоги Cursor из ai_workflow к текущему проекту.

  Скрипт предназначен для копирования в корень любого проекта. Он:
  1) клонирует или обновляет ai_workflow из GitHub в общий локальный кэш;
  2) создаёт ссылки только на commands/skills/rules/agents/hooks;
  3) добавляет сгенерированные ссылки и скрипт в project\.gitignore.
#>
param(
    [string]$ProjectRoot = $PSScriptRoot,
    [string]$WorkflowRepository = 'https://github.com/Xander-Lein/ai_workflow.git',
    [string]$WorkflowCache = (Join-Path $env:LOCALAPPDATA 'Xander-Lein\ai_workflow'),
    [switch]$SkipUpdate
)

$ErrorActionPreference = 'Stop'

function Invoke-Git {
    param([string[]]$Arguments)

    & git @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Git завершился с кодом ${LASTEXITCODE}: git $($Arguments -join ' ')"
    }
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw 'Git не найден в PATH. Установите Git for Windows и повторите запуск.'
}

$ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
$WorkflowCache = [IO.Path]::GetFullPath($WorkflowCache)
$cacheGit = Join-Path $WorkflowCache '.git'
$targetCursor = Join-Path $WorkflowCache '.cursor'
$linkPath = Join-Path $ProjectRoot '.cursor'
$gitignorePath = Join-Path $ProjectRoot '.gitignore'
$scriptName = [IO.Path]::GetFileName($MyInvocation.MyCommand.Path)
$components = @('commands', 'skills', 'rules', 'agents', 'hooks')

$cacheParent = Split-Path -Parent $WorkflowCache
if (-not (Test-Path -LiteralPath $cacheParent)) {
    New-Item -ItemType Directory -Path $cacheParent -Force | Out-Null
}

if (-not (Test-Path -LiteralPath $cacheGit)) {
    if (Test-Path -LiteralPath $WorkflowCache) {
        throw "Папка кэша уже существует, но не является Git-репозиторием: $WorkflowCache"
    }
    Write-Host "Клонирование ai_workflow: $WorkflowRepository" -ForegroundColor Cyan
    Invoke-Git @('clone', $WorkflowRepository, $WorkflowCache)
} elseif (-not $SkipUpdate) {
    Write-Host 'Обновление ai_workflow из GitHub...' -ForegroundColor Cyan
    Invoke-Git @('-C', $WorkflowCache, 'pull', '--ff-only')
}

if (-not (Test-Path -LiteralPath $targetCursor)) {
    throw "В репозитории ai_workflow не найден каталог .cursor: $targetCursor"
}

if (Test-Path -LiteralPath $linkPath) {
    $cursorItem = Get-Item -LiteralPath $linkPath -Force
    if ($cursorItem.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        # Старый вариант скрипта создавал junction на весь .cursor.
        # Удаляется только ссылка, а не содержимое репозитория ai_workflow.
        & cmd.exe /c "rmdir `"$linkPath`"" | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "Не удалось заменить старый junction: $linkPath"
        }
    } elseif (-not $cursorItem.PSIsContainer) {
        throw "В проекте уже есть файл .cursor. Удалите или переименуйте его вручную."
    }
}

New-Item -ItemType Directory -Path $linkPath -Force | Out-Null
$linkedEntries = @()
foreach ($component in $components) {
    $source = Join-Path $targetCursor $component
    if (-not (Test-Path -LiteralPath $source)) { continue }

    $destination = Join-Path $linkPath $component
    if (Test-Path -LiteralPath $destination) {
        $item = Get-Item -LiteralPath $destination -Force
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            Write-Host "Ссылка уже существует: .cursor\$component" -ForegroundColor DarkGray
            $linkedEntries += ".cursor/$component/"
            continue
        }
        Write-Warning "Пропуск .cursor\${component}: в проекте уже есть обычный каталог. Центральный $component не подключён."
        continue
    }

    & cmd.exe /c "mklink /J `"$destination`" `"$source`"" | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Не удалось создать junction: $destination"
    }
    $linkedEntries += ".cursor/$component/"
    Write-Host "Создано: $destination -> $source" -ForegroundColor Green
}

$ignoreLines = @()
if (Test-Path -LiteralPath $gitignorePath) {
    $ignoreLines = @(Get-Content -LiteralPath $gitignorePath -Encoding UTF8)
}

foreach ($entry in @($scriptName) + $linkedEntries) {
    if ($ignoreLines -notcontains $entry) {
        $ignoreLines += $entry
    }
}

$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[IO.File]::WriteAllLines($gitignorePath, $ignoreLines, $utf8NoBom)
$manifestPath = Join-Path $ProjectRoot '.ai_workflow.toml'
if (-not (Test-Path -LiteralPath $manifestPath)) {
    $manifest = @"
[ai_workflow]
repository = "$WorkflowRepository"
ref = "main"

[links]
components = ["commands", "skills", "rules", "agents", "hooks"]
"@
    [IO.File]::WriteAllText($manifestPath, $manifest.Trim() + "`r`n", $utf8NoBom)
    Write-Host "Создан manifest: $manifestPath" -ForegroundColor DarkGray
}
Write-Host "Обновлён: $gitignorePath" -ForegroundColor DarkGray
Write-Host 'Готово. Перезапустите Cursor или переоткройте проект.' -ForegroundColor Green
