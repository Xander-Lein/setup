#Requires -Version 5.1
$testDir = Join-Path $PSScriptRoot 'tests'
$result = Invoke-Pester -Path $testDir -PassThru
if ($result.FailedCount -gt 0) {
    exit 1
}
exit 0
