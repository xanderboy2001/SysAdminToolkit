function Test-ComputerReachability {
    <#
    .SYNOPSIS
    Tests ICMP reachability of computers by name list, name range, or IPv4 range.

    .DESCRIPTION
    Pings each target in parallel (ForEach-Object -Parallel) and emits one object per target as results arrive.

    .PARAMETER ComputerName
    One or more computer names or IP addresses. Accepts pipeline input.

    .PARAMETER StartName
    First name in a numbered range, for example 'PC-1200'.

    .PARAMETER EndName
    Last name in a numbered range, for example 'PC-1250'. The prefix must match StartName.

    .PARAMETER StartIPAddress
    First IPv4 address in the range.

    .PARAMETER EndIPAddress
    Last IPv4 address in the range.

    .PARAMETER ThrottleLimit
    Maximum number of concurrent pings. Default 50.

    .PARAMETER Count
    Echo requests per target. Default 1.

    .PARAMETER Quiet
    Emit only Name and Online.

    .EXAMPLE
    Test-ComputerReachability -ComputerName 'PC1', 'PC2'

    .EXAMPLE
    'PC1', 'PC2', 'PC1' | Test-ComputerReachability -Quiet
    # Duplicate 'PC1' is tested once.

    .EXAMPLE
    Test-ComputerReachability -StartIPAddress 10.0.0.1 -EndIPAddress 10.0.0.254

    .INPUTS
    System.String

    .OUTPUTS
    System.Management.Automation.PSCustomObject

    .NOTES
    Author: Alexander Christian
    ICMP may be blocked by host firewalls; Online = $false means "no echo reply", not "powered off".
    #>

    [CmdletBinding(DefaultParameterSetName = "byName")]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, ParameterSetName = "byName", ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias("TargetNames", "ComputerNames")]
        [string[]]$ComputerName,

        [Parameter(Mandatory, ParameterSetName = "byNameRange")]
        [string]$StartName,

        [Parameter(Mandatory, ParameterSetName = "byNameRange")]
        [string]$EndName,

        [Parameter(Mandatory, ParameterSetName = "byIPRange")]
        [string]$StartIPAddress,

        [Parameter(Mandatory, ParameterSetName = "byIPRange")]
        [string]$EndIPAddress,

        [ValidateRange(1, 100)]
        [int]$ThrottleLimit = 50,

        [ValidateRange(1, 10)]
        [int]$Count = 1,

        [switch]$Quiet
    )

    begin {
        $collected = [System.Collections.Generic.List[string]]::new()
    }

    process {
        if ($PSCmdlet.ParameterSetName -eq "byName") {
            foreach ($name in $ComputerName) {
                $collected.Add($name)
            }
        }
    }

    end {
        $rawTargets = switch ($PSCmdlet.ParameterSetName) {
            'byNameRange' {
                Expand-NameRange -StartName $StartName -EndName $EndName
            }
            'byIPRange' {
                Expand-IPRange -StartIPAddress $StartIPAddress -EndIPAddress $EndIPAddress
            }
            default {
                $collected
            }
        }

        $targetList = @(ConvertTo-TargetList -InputObject $rawTargets)
        if ($targetList.Count -eq 0) {
            Write-Warning "No valid targets were supplied."
            return
        }

        # ForEach-Object -Parallel rejects script blocks passed via $using:, so pass function bodies as strings
        # and re-create the functions inside each runspace.
        $invokePingDefinition = ${function:Invoke-Ping}.ToString()
        $testSingleTargetDefinition = ${function:Test-SingleTarget}.ToString()

        $total = $targetList.Count
        $completed = 0
        $activity = "Testing reachability of $total target(s)"

        $targetList |
            ForEach-Object -ThrottleLimit $ThrottleLimit -Parallel {
                ${function:Invoke-Ping} = $using:invokePingDefinition
                ${function:Test-SingleTarget} = $using:testSingleTargetDefinition
                Test-SingleTarget -Target $_ -Count $using:Count
            } |
            ForEach-Object {
                $completed++
                $progressParams = @{
                    Activity = $activity
                    Status = "$completed / $total"
                    PercentComplete = [int](($completed / $total) * 100)
                }
                Write-Progress @progressParams

                if ($Quiet) {
                    [PSCustomObject]@{
                        Name = $_.Name
                        Online = $_.Online
                    }
                } else {
                    $_
                }
            }

        Write-Progress -Activity $activity -Completed
    }
}
