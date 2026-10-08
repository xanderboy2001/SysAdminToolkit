function Invoke-Ping {
    <#
    .SYNOPSIS
    Thin wrapper around Test-Connection used as a mocking boundary for reachability tests.

    .NOTES
    Author: Alexander Christian
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Target,

        [ValidateRange(1, 10)]
        [int]$Count = 1
    )

    Test-Connection -TargetName $Target -Count $Count -ErrorAction SilentlyContinue
}
