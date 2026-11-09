#Requires -Version 5.1
#Requires -RunAsAdministrator
param(
    [string]$VmName = 'LibrarySetupSmoke',
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command New-VM -ErrorAction SilentlyContinue)) {
    throw 'Hyper-V module not available. Enable Hyper-V and run this script as Administrator.'
}

$vhd = Join-Path $env:LOCALAPPDATA "Library\setup\vm\$VmName.vhdx"
$vmDir = Split-Path -Parent $vhd
New-Item -ItemType Directory -Path $vmDir -Force | Out-Null

$existing = Get-VM -Name $VmName -ErrorAction SilentlyContinue
if ($existing) {
    Write-Host "VM already exists: $VmName" -ForegroundColor Yellow
} else {
    if (-not (Test-Path -LiteralPath $vhd)) {
        New-VHD -Path $vhd -SizeBytes 40GB -Dynamic | Out-Null
    }
    $switch = (Get-VMSwitch | Where-Object { $_.SwitchType -eq 'Internal' -or $_.Name -eq 'Default Switch' } | Select-Object -First 1).Name
    if (-not $switch) {
        throw 'No Hyper-V virtual switch found.'
    }
    New-VM -Name $VmName -MemoryStartupBytes 4GB -Generation 2 -VHDPath $vhd -SwitchName $switch | Out-Null
    Set-VMProcessor -VMName $VmName -Count 2
    Enable-VMIntegrationService -VMName $VmName -Name 'Guest Service Interface'
  Write-Host "Created VM: $VmName ($vhd)" -ForegroundColor Green
}

$shareRoot = Join-Path $RepoRoot 'src\smoke\vm-share'
New-Item -ItemType Directory -Path $shareRoot -Force | Out-Null
Copy-Item -Path $RepoRoot -Destination (Join-Path $shareRoot 'setup') -Recurse -Force
Write-Host "Shared copy for guest: $shareRoot\setup" -ForegroundColor Cyan
Write-Host 'Next: attach Windows 11 ISO, install OS, run setup\windows\setup_system.bat --dry-run from vm-share.' -ForegroundColor DarkGray
