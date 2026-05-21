<#
.SYNOPSIS
    Runs PSScriptAnalyzer on one or more PowerShell files.

.DESCRIPTION
    Intended to be called by lint-staged via `pwsh -File scripts/Invoke-PSLint.ps1`.
    lint-staged appends staged filenames as positional arguments, which PowerShell
    makes available as $args when invoked with -File.

.PARAMETER Files
    One or more .ps1 or .psm1 file paths to analyze. Passed positionally by lint-staged.

.NOTES
    Author: Alexander Christian
    Exits with a non-zero code if any violations are found, causing lint-staged to abort.
#>

$settingsPath = Join-Path $HOME 'AppData\Local\nvim\PSSA_Settings.psd1'

foreach ($file in $args) {
    $results = Invoke-ScriptAnalyzer -Path $file -Settings $settingsPath
    if ($results) {
        $results | ForEach-Object {
            Write-Error "$($_.ScriptName): $($_.Line):$($_.Column): [$($_.RuleName)] $($_.Message)"
        }
        exit 1
    }
}
