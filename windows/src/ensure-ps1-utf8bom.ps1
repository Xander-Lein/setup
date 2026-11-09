#Requires -Version 5.1
$ScriptsRoot = $PSScriptRoot

$enc = New-Object System.Text.UTF8Encoding $true
Get-ChildItem -LiteralPath $ScriptsRoot -Recurse -Filter '*.ps1' | ForEach-Object {
    $t = [System.IO.File]::ReadAllText($_.FullName)
    if ($t.Length -gt 0 -and [int][char]$t[0] -eq 0xFEFF) {
        $t = $t.Substring(1)
    }
    [System.IO.File]::WriteAllText($_.FullName, $t, $enc)
}
