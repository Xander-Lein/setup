#Requires -Version 5.1
Describe 'Get-AssociationOpenCommand' {
    BeforeAll {
        $libDir = Join-Path (Join-Path $PSScriptRoot '..') 'lib'
        . (Join-Path $libDir 'FileAssociations.ps1')
    }

    It 'quotes executable and passes file argument' {
        $cmd = Get-AssociationOpenCommand -ExePath 'C:\Apps\Widno.exe'
        $cmd | Should Be '"C:\Apps\Widno.exe" "%1"'
    }
}
