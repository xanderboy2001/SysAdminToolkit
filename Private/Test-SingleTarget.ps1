function Test-SingleTarget {
    <#
    .SYNOPSIS
    Pings a single target and returns one summary object.

    .NOTES
    Author: Alexander Christian
    This function is re-created inside ForEach-Object -Parallel runspaces by Test-ComputerReachability.
    It must only depend on Invoke-Ping and built-in cmdlets.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Target,

        [ValidateRange(1, 10)]
        [int]$Count
    )

    # @() guarantees an empty array even when Test-Connection returns to zero or one PingStatus object.
    $pingResults = @(Invoke-Ping -Target $Target -Count $Count)
    $replies = @($pingResults | Where-Object { $_.Status -eq 'Success' })

    $ipAddress = $pingResults |
        Where-Object { $null -ne $_.Address } |
        Select-Object -First 1 -ExpandProperty Address

    $responseTime = $null
    if ($replies.Count -gt 0) {
        $responseTime = [math]::Round(($replies | Measure-Object -Property Latency -Average).Average, 0)
    }

    [PSCustomObject]@{
        Name = $Target
        IPAddress = if ($ipAddress) {
            $ipAddress.ToString()
        } else {
            $null
        }
        Online = $replies.Count -gt 0
        ResponseTime = $responseTime
        Timestamp = Get-Date
    }
}
