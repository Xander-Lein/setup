#Requires -Version 5.1
param([string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path)

$ErrorActionPreference = 'Stop'
$commandsDir = Join-Path $ProjectRoot '.cursor\commands'
$skillsDir = Join-Path $ProjectRoot '.cursor\skills'
if (-not (Test-Path -LiteralPath $commandsDir)) {
    throw "No .cursor\commands in $ProjectRoot. Run link_ai_workflow_cursor.ps1 first."
}

$failed = $false
Get-ChildItem -LiteralPath $commandsDir -Filter '*.md' -File | ForEach-Object {
    $name = [IO.Path]::GetFileNameWithoutExtension($_.Name)
    $skill = Join-Path (Join-Path $skillsDir $name) 'SKILL.md'
    if (-not (Test-Path -LiteralPath $skill)) {
        Write-Warning "Missing skill for command: $name"
        $failed = $true
    }
}
if ($failed) { exit 1 }
Write-Host "ai_workflow link OK: $(@(Get-ChildItem $commandsDir -Filter *.md).Count) commands." -ForegroundColor Green
