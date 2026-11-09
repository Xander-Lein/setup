#Requires -Version 5.1
. (Join-Path $PSScriptRoot 'GitHubRelease.ps1')

function Get-AssociationOpenCommand {
    param([Parameter(Mandatory)][string]$ExePath)
    $quoted = '"' + $ExePath.Replace('"', '\"') + '"'
    return "$quoted `"%1`""
}

function Register-UserFileAssociation {
    param(
        [Parameter(Mandatory)][string]$ProgId,
        [Parameter(Mandatory)][string]$FriendlyName,
        [Parameter(Mandatory)][string]$ExePath,
        [Parameter(Mandatory)][string[]]$Extensions
    )

    if (-not (Test-Path -LiteralPath $ExePath)) {
        throw "Executable not found: $ExePath"
    }

    $openCmd = Get-AssociationOpenCommand -ExePath $ExePath
    $classesRoot = 'HKCU:\Software\Classes'

    New-Item -Path (Join-Path $classesRoot $ProgId) -Force | Out-Null
    Set-ItemProperty -Path (Join-Path $classesRoot $ProgId) -Name '(default)' -Value $FriendlyName

    $shellOpen = Join-Path $classesRoot "$ProgId\shell\open\command"
    New-Item -Path $shellOpen -Force | Out-Null
    Set-ItemProperty -Path $shellOpen -Name '(default)' -Value $openCmd

    foreach ($ext in $Extensions) {
        $normalized = $ext
        if (-not $normalized.StartsWith('.')) { $normalized = ".$normalized" }
        $extKey = Join-Path $classesRoot $normalized
        New-Item -Path $extKey -Force | Out-Null
        Set-ItemProperty -Path $extKey -Name '(default)' -Value $ProgId
    }

    $ftype = "ftype $ProgId=$openCmd"
    $assocPairs = ($Extensions | ForEach-Object {
            $e = $_
            if (-not $e.StartsWith('.')) { $e = ".$e" }
            "assoc $e=$ProgId"
        })
    foreach ($line in ($assocPairs + $ftype)) {
        & cmd.exe /c $line 2>&1 | Out-Null
    }
}

function Resolve-AssociationExePath {
    param(
        $AssociationConfig,
        $GitHubApps
    )

    if ($AssociationConfig.exe) {
        return Expand-ConfigPath -PathTemplate $AssociationConfig.exe
    }

    $ghId = $AssociationConfig.github_app
    if (-not $ghId -or -not $GitHubApps.ContainsKey($ghId)) {
        return $null
    }

    $gh = $GitHubApps[$ghId]
    $detect = $gh.detect_exe
    $display = $gh.display_name
    $state = Get-GitHubAppInstalledVersion -DisplayName $display -DetectExe $detect
    if ($state.ExePath) { return $state.ExePath }
    if ($detect) {
        $path = Expand-ConfigPath -PathTemplate $detect
        if (Test-Path -LiteralPath $path) { return $path }
    }
    return $null
}
