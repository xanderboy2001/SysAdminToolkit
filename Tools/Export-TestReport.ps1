#Requires -Version 7.4
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.5.0' }, PSScriptAnalyzer
<#
.SYNOPSIS
Runs PSScriptAnalyzer and Pester and writes a compact Markdown report that is easy to share.

.DESCRIPTION
Writes two files to the repository root:
- TestReport.md : analyzer errors, Pester totals and failures, analyzer counts per rule, full detail for
                  non-formatting findings, and per-file counts for formatting findings.
- ScriptAnalyzer.csv : every analyzer finding.
The analyzer runs first and one file at a time, so test-session state cannot affect it and a crash in one file
is reported instead of silently truncating the results. Paths are written relative to the repository root.
Exits with code 1 if any test fails or the analyzer errors on any file.

.PARAMETER IncludeIntegration
Also runs tests tagged 'Integration' (they ping 127.0.0.1).

.EXAMPLE
pwsh -NoProfile -File ./Tools/Export-TestReport.ps1
#>
[CmdletBinding()]
param(
    [switch]$IncludeIntegration
)

$repoRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..')).Path
$reportPath = Join-Path -Path $repoRoot -ChildPath 'TestReport.md'
$csvPath = Join-Path -Path $repoRoot -ChildPath 'ScriptAnalyzer.csv'
$settingsPath = Join-Path -Path $repoRoot -ChildPath 'PSScriptAnalyzerSettings.psd1'

# Style-only rules: summarized per file instead of listed line by line.
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
    param(
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
    # Returns up to three stack frames from module code (not tests or tools), as relative paths.
    param($ErrorRecord)
    "$($ErrorRecord.ScriptStackTrace)" -split '\r?\n' |
        Where-Object { $_ -like "*$repoRoot*" -and $_ -notmatch 'Tests|Tools[\\/]' } |
        Select-Object -First 3 |
        ForEach-Object { $_.Replace($repoRoot, '.').Trim() }
}

function Add-ErrorDetail {
    # Adds the message and module stack frames of each ErrorRecord to the report.
    param($ErrorRecords)
    foreach ($err in $ErrorRecords) {
        $report.Add("- $(Format-Cell $err.Exception.Message 2000)")
        Get-ModuleStackLine $err | ForEach-Object { $report.Add("  - ``$_``") }
    }
}

# --- PSScriptAnalyzer (first, one file at a time) ---------------------------------------------------------------
$findings = [System.Collections.Generic.List[object]]::new()
$analyzerErrors = [System.Collections.Generic.List[pscustomobject]]::new()

$sourceFiles = Get-ChildItem -Path $repoRoot -Include '*.ps1', '*.psm1', '*.psd1' -Recurse -File
foreach ($file in $sourceFiles) {
    $fileErrors = $null
    try {
        $result = Invoke-ScriptAnalyzer -Path $file.FullName -Settings $settingsPath `
            -ErrorAction SilentlyContinue -ErrorVariable fileErrors
        foreach ($finding in $result) {
            $findings.Add($finding)
        }
    } catch {
        $fileErrors = @($_)
    }
    foreach ($err in $fileErrors) {
        $analyzerErrors.Add([pscustomobject]@{
                File    = ConvertTo-RelativePath $file.FullName
                Message = $err.Exception.Message
            })
    }
}

if ($analyzerErrors.Count -gt 0) {
    Write-Warning ("PSScriptAnalyzer failed on $($analyzerErrors.Count) file(s); " +
        "see 'Analyzer errors' in the report.")
}

$findings |
    Select-Object RuleName, Severity, @{
        Name       = 'File'
        Expression = { ConvertTo-RelativePath $_.ScriptPath }
    }, Line, Message |
    Export-Csv -Path $csvPath -NoTypeInformation -Encoding utf8

# --- Pester ------------------------------------------------------------------------------------------------------
$config = New-PesterConfiguration
$config.Run.Path = Join-Path -Path $repoRoot -ChildPath 'Tests'
$config.Run.PassThru = $true
$config.Output.Verbosity = 'Normal'
if (-not $IncludeIntegration) {
    $config.Filter.ExcludeTag = 'Integration'
}
$pester = Invoke-Pester -Configuration $config

# --- Report ------------------------------------------------------------------------------------------------------
$report = [System.Collections.Generic.List[string]]::new()
$report.Add('# SysAdminToolkit test report')
$report.Add('')
$report.Add("Generated: $(Get-Date -Format 's') | PowerShell $($PSVersionTable.PSVersion) | " +
    "Pester $((Get-Module Pester).Version) | " +
    "PSScriptAnalyzer $((Get-Module PSScriptAnalyzer).Version)")

if ($analyzerErrors.Count -gt 0) {
    $report.Add('')
    $report.Add('## Analyzer errors (findings below are incomplete)')
    $report.Add('')
    $report.Add('| File | Error |')
    $report.Add('|---|---|')
    foreach ($item in $analyzerErrors) {
        $report.Add("| $($item.File) | $(Format-Cell $item.Message) |")
    }
}

$report.Add('')
$report.Add('## Pester')
$report.Add('')
$report.Add("Result: **$($pester.Result)** | Total $($pester.TotalCount) | Passed $($pester.PassedCount) | " +
    "Failed $($pester.FailedCount) | Skipped $($pester.SkippedCount) | NotRun $($pester.NotRunCount)")

# Container and block failures (for example, module import errors in BeforeAll) hide many individual tests.
foreach ($container in $pester.FailedContainers) {
    $report.Add('')
    $report.Add("### Container failed: $(ConvertTo-RelativePath "$($container.Item)")")
    Add-ErrorDetail $container.ErrorRecord
}

foreach ($block in $pester.FailedBlocks) {
    $report.Add('')
    $report.Add("### Block failed: $($block.Path -join ' > ')")
    Add-ErrorDetail $block.ErrorRecord
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
        Add-ErrorDetail $test.ErrorRecord
    }
}

$report.Add('')
$report.Add('## PSScriptAnalyzer')
$report.Add('')
$report.Add("Files analyzed: $($sourceFiles.Count) | Total findings: $($findings.Count) " +
    '(full list in ScriptAnalyzer.csv)')
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
    $report.Add('| File | Line | Rule | Message |')
    $report.Add('|---|---|---|---|')
    $important | Sort-Object ScriptPath, Line | ForEach-Object {
        $report.Add("| $(ConvertTo-RelativePath $_.ScriptPath) | $($_.Line) | $($_.RuleName) | " +
            "$(Format-Cell $_.Message) |")
    }
}

$formatting = @($findings | Where-Object RuleName -In $formattingRules)
if ($formatting.Count -gt 0) {
    $report.Add('')
    $report.Add('### Formatting findings per file')
    $report.Add('')
    $report.Add('| File | Count |')
    $report.Add('|---|---|')
    $formatting | Group-Object ScriptPath | Sort-Object Count -Descending | ForEach-Object {
        $report.Add("| $(ConvertTo-RelativePath $_.Name) | $($_.Count) |")
    }
}

Set-Content -LiteralPath $reportPath -Value $report -Encoding utf8
Write-Output "Report written to $reportPath"
Write-Output "Analyzer detail written to $csvPath"

if ($pester.FailedCount -gt 0 -or $pester.FailedContainers.Count -gt 0 -or
    $pester.FailedBlocks.Count -gt 0 -or $analyzerErrors.Count -gt 0) {
    exit 1
}
