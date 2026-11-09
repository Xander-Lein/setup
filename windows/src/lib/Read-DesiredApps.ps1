#Requires -Version 5.1
<#
.SYNOPSIS
  Читает desired-apps.toml (winget groups, [github.*], [associations.*], [winget]).
#>
function Read-DesiredApps {
    param(
        [Parameter(Mandatory)]
        [string]$TomlPath
    )

    if (-not (Test-Path -LiteralPath $TomlPath)) {
        throw "Файл не найден: $TomlPath"
    }

    $lines = Get-Content -LiteralPath $TomlPath -Encoding UTF8
    $groups = @{}
    $winget = @{
        accept_source_agreements = $true
    }
    $githubApps = @{}
    $associations = @{}
    $currentGroup = $null
    $currentSectionKind = $null   # winget | wingetGroup | github | association
    $currentSectionId = $null
    $inStringArray = $false
    $arrayField = $null

    foreach ($rawLine in $lines) {
        $line = $rawLine.Trim()
        if ($line.Length -eq 0) { continue }

        $hashIdx = Find-CommentIndexOutsideQuotes -Line $line
        if ($hashIdx -ge 0) {
            $line = $line.Substring(0, $hashIdx).TrimEnd()
            if ($line.Length -eq 0) { continue }
        }

        if ($line -match '^\[([^\]]+)\]\s*$') {
            $section = $Matches[1].Trim()
            $inStringArray = $false
            $arrayField = $null
            $currentSectionId = $null
            $currentSectionKind = $null
            $currentGroup = $null

            if ($section -eq 'winget') {
                $currentGroup = 'winget'
                $currentSectionKind = 'winget'
            } elseif ($section -match '^github\.(.+)$') {
                $currentSectionId = $Matches[1].Trim()
                $currentSectionKind = 'github'
                if (-not $githubApps.ContainsKey($currentSectionId)) {
                    $githubApps[$currentSectionId] = @{}
                }
            } elseif ($section -match '^associations\.(.+)$') {
                $currentSectionId = $Matches[1].Trim()
                $currentSectionKind = 'association'
                if (-not $associations.ContainsKey($currentSectionId)) {
                    $associations[$currentSectionId] = @{
                        extensions = [System.Collections.Generic.List[string]]::new()
                    }
                }
            } else {
                $currentGroup = $section
                $currentSectionKind = 'wingetGroup'
                if (-not $groups.ContainsKey($currentGroup)) {
                    $groups[$currentGroup] = [System.Collections.Generic.List[string]]::new()
                }
            }
            continue
        }

        if ($currentSectionKind -eq 'winget') {
            if ($line -match '^accept_source_agreements\s*=\s*(true|false)\s*$') {
                $winget.accept_source_agreements = ($Matches[1] -eq 'true')
            }
            continue
        }

        if ($currentSectionKind -eq 'wingetGroup') {
            if ($null -eq $currentGroup) { continue }
            if ($line -match '^apps\s*=\s*\[\s*$') {
                $inStringArray = $true
                $arrayField = 'apps'
                continue
            }
            if ($inStringArray -and $arrayField -eq 'apps') {
                if ($line -eq ']') {
                    $inStringArray = $false
                    $arrayField = $null
                    continue
                }
                $id = Extract-QuotedAppId -Line $line
                if ($id) {
                    $groups[$currentGroup].Add($id)
                }
            }
            continue
        }

        if ($currentSectionKind -eq 'github' -and $currentSectionId) {
            $kv = Parse-TomlKeyValue -Line $line
            if ($kv) {
                $githubApps[$currentSectionId][$kv.Key] = $kv.Value
            }
            continue
        }

        if ($currentSectionKind -eq 'association' -and $currentSectionId) {
            if ($line -match '^extensions\s*=\s*\[\s*$') {
                $inStringArray = $true
                $arrayField = 'extensions'
                continue
            }
            if ($inStringArray -and $arrayField -eq 'extensions') {
                if ($line -eq ']') {
                    $inStringArray = $false
                    $arrayField = $null
                    continue
                }
                $id = Extract-QuotedAppId -Line $line
                if ($id) {
                    $associations[$currentSectionId].extensions.Add($id)
                }
                continue
            }
            $kv = Parse-TomlKeyValue -Line $line
            if ($kv) {
                $associations[$currentSectionId][$kv.Key] = $kv.Value
            }
        }
    }

    $allApps = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($name in $groups.Keys) {
        foreach ($id in $groups[$name]) {
            $allApps.Add($id) | Out-Null
        }
    }

    return [PSCustomObject]@{
        Groups = $groups
        AppIds = [string[]]($allApps | Sort-Object)
        Winget = $winget
        GitHubApps = $githubApps
        Associations = $associations
    }
}

function Parse-TomlKeyValue {
    param([string]$Line)
    if ($Line -match '^([A-Za-z0-9_]+)\s*=\s*"([^"]*)"\s*$') {
        return @{ Key = $Matches[1]; Value = $Matches[2] }
    }
    if ($Line -match "^([A-Za-z0-9_]+)\s*=\s*'([^']*)'\s*$") {
        return @{ Key = $Matches[1]; Value = $Matches[2] }
    }
    if ($Line -match '^([A-Za-z0-9_]+)\s*=\s*(true|false)\s*$') {
        return @{ Key = $Matches[1]; Value = ($Matches[2] -eq 'true') }
    }
    return $null
}

function Find-CommentIndexOutsideQuotes {
    param([string]$Line)
    $inSingle = $false
    $inDouble = $false
    for ($i = 0; $i -lt $Line.Length; $i++) {
        $c = $Line[$i]
        if ($c -eq '"' -and -not $inSingle) { $inDouble = -not $inDouble; continue }
        if ($c -eq "'" -and -not $inDouble) { $inSingle = -not $inSingle; continue }
        if ($c -eq '#' -and -not $inDouble -and -not $inSingle) { return $i }
    }
    return -1
}

function Extract-QuotedAppId {
    param([string]$Line)
    $trimmed = $Line.Trim().TrimEnd(',')
    if ($trimmed -match '^"([^"]+)"\s*$') {
        return $Matches[1].Trim()
    }
    return $null
}
