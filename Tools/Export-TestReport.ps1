#Requires -Version 7.4
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.5.0' }, PSScriptAnalyzer
<#
.SYNOPSIS
Runs Pester and PSScriptAnalyzer and writes a compact Markdown report that is easy to share.

.DESCRIPTION
Writes two files to the repository root:
- TestReport.md : Pester totals, every failure (with message and source location), analyzer counts per rule,
                  full detail for non-formatting analyzer findings, and per-file counts for formatting findings.
- ScriptAnalyzer.csv : every analyzer finding, for when the full detail is needed.
Paths are written relative to the repository root so local user names and folders are not included.

.PARAMETER IncludeIntegration
Also runs tests tagged 'Integration' (they ping 127.0.0.1).

.EXAMPLE
pwsh -NoProfile -File ./Tools/Export-Test-Report.ps1
#>
[CmdletBinding()]
param(
    [switch]$IncludeIntegration
)

$repoRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..')).Path
$reportPath = Join-Path -Path $repoRoot -ChildPath 'TestReport.md'
$csvPath = Join-Path -Path $repoRoot -ChildPath "ScriptAnalyzer.csv"

# Style-only rules: summarized per file instead of listed line by line, because they can produce hundreds of hits.
$formattingRules = @(
    'PSPlaceOpenBrace', 'PSPlaceCloseBrace', 'PSUseConsistentIndentation', 'PSUseConsistentWhitespace',
    'PSAlignAssignmentStatement', 'PSUseCorrectCasing', 'PSAvoidLongLines', 'PSAvoidTrailingWhitespace'
)


function ConvertTo-RelativePath {
    param([string]$Path)
    if ($Path) {
        [System.IO.Path]::GetRelativePath($repoRoot, $Path)
    }
}


function Format-Cell {
    param (
        [string]$Text,
        [int]$MaxLength = 400
    )
    $clean = ($Text -replace '\r?\n', ' ' -replace '\|', '\|').Trim()
    if ($clean.Length -gt $MaxLength) {
        $clean = $clean.Substring(0, $MaxLength) + '...'
    }
    $clean
}


function Get-ModuleStackLine {
    # Returns up to three stack frames from the module itself (Not Pester), as relative paths.
    param($ErrorRecord)
    "$($ErrorRecord.ScriptStackTrace)" -split '\r?\n' |
        Where-Object { $_ -like "*$repoRoot*" -and $_ -notlike "*Tests*" } |
        Select-Object -First 3 |
        ForEach-Object { $_.Replace($repoRoot, '.').Trim() }
}

# --- Pester -----------------------------------------------------------------------------------------------------
$config = New-PesterConfiguration
$config.Run.Path = Join-Path -Path $repoRoot -ChildPath 'Tests'
$config.Run.PassThru = $true
$config.Output.Verbosity = "Normal"
if (-not $IncludeIntegration) {
    $config.Filter.ExcludeTag = 'Integration'
}
$pester = Invoke-Pester -Configuration $config

# --- PSScriptAnalyzer -------------------------------------------------------------------------------------------
$analyzerParams = @{
    Path = $repoRoot
    Recurse = $true
    Settings = Join-Path -Path $repoRoot -ChildPath 'PSScriptAnalyzerSettings.psd1'
}
$findings = @(Invoke-ScriptAnalyzer @analyzerParams)
$findings |
    Select-Object RuleName, Severity, @{
        Name = 'File'
        Expression = {
            ConvertTo-RelativePath $_.ScriptPath
        }
    }, Line, Message |
    Export-Csv -Path $csvPath -NoTypeInformation -Encoding utf8

# --- Report -----------------------------------------------------------------------------------------------------
$report = [System.Collections.Generic.List[string]]::new()
$report.Add("# SysAdminToolkit test report")
$report.Add('')
$report.Add("Generated: $(Get-Date -Format 's') | PowerShell $($PSVersionTable.PSVersion) | " +
    "Pester $((Get-Module Pester).Version) | " +
    "PSScriptAnalyzer $((Get-Module PSScriptAnalyzer).Version)")
$report.Add('')
$report.Add('## Pester')
$report.Add('')
$report.Add("Result: **$($pester.Result)** | Total $($pester.TotalCount) | Passed $($pester.PassedCount) | " +
    "Failed $($pester.FailedCount) | Skipped $($pester.SkippedCount) | NotRun $($pester.NotRunCount)")

# Container and block failures (for example: module import errors in BeforeAll) hide many individual tests.
foreach ($container in $pester.FailedContainers) {
    $report.Add('')
    $report.Add("### Block failed: $($block.Path -join ' > ')")
    foreach ($err in $block.ErrorRecord) {
        $report.Add("- $(Format-Cell $err.Exception.Message 2000)")
        Get-ModuleStackLine $err | ForEach-Object { $report.Add("  - ``$_``") }
    }
}

if ($pester.Failed.Count -gt 0) {
    $report.Add('')
    $report.Add('### Failed tests')
    foreach ($test in $pester.Failed) {
        $name = if ($test.ExpandedPath) {
            $test.ExpandedPath
        } else {
            $test.Path -join ' > '
        }
        $location = "$(ConvertTo-RelativePath $test.ScriptBlock.File):$($test.ScriptBlock.StartPosition.StartLine)"
        $report.Add('')
        $report.Add("**$name** (``$location``)")
        foreach ($err in $test.ErrorRecord) {
            $report.Add("- $(Format-Cell $err.Exception.Message 2000)")
            Get-ModuleStackLine $err | ForEach-Object {
                $report.Add("  - ``$_``")
            }
        }
    }
}

$report.Add('')
$report.Add('## PSScriptAnalyzer')
$report.Add('')
$report.Add("Total findings: $($findings.Count) (full list in ScriptAnalyzer.csv)")
$report.Add('')
$report.Add('| Rule | Severity | Count |')
$report.Add('|---|---|---|')
$findings | Group-Object RuleName, Severity | Sort-Object Count -Descending | ForEach-Object {
    $report.Add("| $($_.Values[0]) | $($_.Values[1]) | $($_.Count) |")
}

$important = @($findings | Where-Object RuleName -NotIn $formattingRules)
if ($important.Count -gt 0) {
    $report.Add('')
    $report.Add('### Non-formatting findings')
    $report.Add('')
    $report.add('| File | Line | Rule | Message |')
    $report.Add('|---|---|---|---|')
    $important | Sort-Object ScriptPath, Line | ForEach-Object {
        $report.Add("| $(ConvertTo-RelativePath $_.ScriptPath) | $($_.Line) | $($_.RuleName) | " +
            "$(Format-Cell $_.Message) |")
    }
}

$formatting = @($findings | Where-Object RuleName -In $formattingRules)
if ($formatting.Count -gt 0) {
    $report.Add('')
    $report.Add('### Formatting findings per File')
    $report.Add('')
    $report.add('| File | Count |')
    $report.Add('|---|---|')
    $formatting | Group-Object ScriptPath | Sort-Object Count -Descending | ForEach-Object {
        $report.Add("| $(ConvertTo-RelativePath $_.Name) | $($_.Count) |")
    }
}

Set-Content -LiteralPath $reportPath -Value $report -Encoding utf8
Write-Output "Report written to $reportPath"
Write-Output "Analyzer detail written to $csvPath"
