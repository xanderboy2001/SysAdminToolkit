function Wait-RDMService {
    <#
    .SYNOPSIS
    Waits until the RDS Connection Broker services are running on a computer.

    .DESCRIPTION
    Polls the Remote Desktop Management (rdms), Remote Desktop Connection Broker (tssdis), and RemoteApp and
    Desktop Connection Management (tscpubrpc) services on the target computer until all three are running.

    The status check runs on the target computer and returns each status as a string ('Running', 'Stopped',
    'NotFound', ...), so the comparison does not depend on how enum values survive remoting. A service that does
    not exist counts as not running.

    Waits PollSeconds before every check, including the first, because services are often still starting right
    after a reboot. Throws when the services are not running after MaxRetries checks.

    .PARAMETER ComputerName
    The broker to check.

    .PARAMETER MaxRetries
    Number of checks before giving up. The total wait is about MaxRetries x PollSeconds.

    .PARAMETER PollSeconds
    Delay before each check.

    .EXAMPLE
    Wait-RDMService -ComputerName broker.domain.com -MaxRetries 15
    # Checks every 30 seconds, up to 15 times (about 7.5 minutes).

    .NOTES
    Author: Alexander Christian
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, HelpMessage = "The FQDN or hostname of the broker server to poll.")]
        [ValidateNotNullOrEmpty()]
        [string]$ComputerName,

        [Parameter(Mandatory, HelpMessage = "Number of checks before throwing a timeout error.")]
        [ValidateRange(1, 1000)]
        [int]$MaxRetries,

        [ValidateRange(1, 600)]
        [int]$PollSeconds = 30
    )

    $serviceNames = @('rdms', 'tssdis', 'tscpubrpc')

    # Runs on the broker. Returns one object per requested service, with the status as a string.
    $serviceCheck = {
        param([string[]]$Names)
        foreach ($name in $Names) {
            $service = Get-Service -Name $name -ErrorAction SilentlyContinue
            [pscustomobject]@{
                Name   = $name
                Status = if ($service) { $service.Status.ToString() } else { 'NotFound' }
            }
        }
    }

    $invokeParams = @{
        ComputerName = $ComputerName
        ScriptBlock  = $serviceCheck
        # The lading comma passes the array as one argument instead of one argument per name.
        ArgumentList = (, $serviceNames)
        ErrorAction  = 'Stop'
    }

    $lastProblem = 'no status was returned'
    for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
        Start-Sleep -Seconds $PollSeconds
        try {
            $status = @(Invoke-Command @invokeParams)
        } catch {
            $lastProblem = "status query failed: $($_.Exception.Message)"
            Write-Warning "Unable to query services on $ComputerName (check $attempt of $MaxRetries): $lastProblem"
            continue
        }

        foreach ($service in $status) {
            Write-Verbose "  ${ComputerName} $($service.Name): $($service.Status)"
        }

        $notRunning = @($status | Where-Object { $_.Status -ne 'Running' })
        if ($status.Count -eq $serviceNames.Count -and $notRunning.Count -eq 0) {
            return
        }

        $lastProblem = ($notRunning | ForEach-Object { "$($_.Name) is $($_.Status)" }) -join ', '
        if (-not $lastProblem) {
            $lastProblem = "expected $($serviceNames.Count) services, got $($status.Count)"
        }
        Write-Information "Waiting for RDS services on $ComputerName (check $attempt of $MaxRetries): $lastProblem"
    }

    throw ("RDS services did not all start on $ComputerName after $MaxRetries checks" +
        "($($MaxRetries * $PollSeconds)s). Last status: $lastProblem.")
}
