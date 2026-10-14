function Invoke-ReachabilityPrompt {
    <#
    .SYNOPSIS
    Prompts for reachability targets and runs Test-ComputerReachability.

    .DESCRIPTION
    Menu action for the Reachability menu. List mode accepts comma-separated names or IP addresses; NameRange and
    IPRange modes prompt for a start and end value. Results are shown as a table.

    .PARAMETER Mode
    List, NameRange, or IPRange.

    .NOTES
    Author: Alexander Christian
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '',
        Justification = 'Interactive prompt; output is for the operator, not the pipeline.')]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('List', 'NameRange', 'IPRange')]
        [string]$Mode
    )

    $testParams = @{}
    switch ($Mode) {
        'List' {
            $rawTargets = Read-Host 'Enter computer names or IPs (comma separated)'
            if ([string]::IsNullOrWhiteSpace($rawTargets)) {
                Write-Warning 'No input provided'
                return
            }
            $testParams['ComputerName'] = $rawTargets -split ','
        }
        'NameRange' {
            $start = Read-Host 'Enter starting name (e.g., PC-0100)'
            $end = Read-Host 'Enter ending name (e.g., PC-0150)'
            if (-not $start -or -not $end) {
                Write-Warning 'Both values are required.'
                return
            }
            $testParams['StartName'] = $start
            $testParams['EndName'] = $end
        }
        'IPRange' {
            $start = Read-Host 'Enter starting IP address'
            $end = Read-Host 'Enter ending IP address'
            if (-not $start -or -not $end) {
                Write-Warning 'Both values are required.'
                return
            }
            $testParams['StartIPAddress'] = $start
            $testParams['EndIPAddress'] = $end
        }
    }

    Write-Host "`nRunning test..." -ForegroundColor Cyan
    Test-ComputerReachability @testParams | Format-Table | Out-Host
    $null = Read-Host 'Press Enter to continue'
}
