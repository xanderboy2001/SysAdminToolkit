function Restart-RDSBroker {
    <#
    .SYNOPSIS
    Performs a staggered maintenance reboot of all RDS Connection Brokers in a High Availability group.

    .DESCRIPTION
    Resolves the Connection Broker server, retrieves all broker nodes in the HA group, and performs
    a controlled reboot sequence:

        1. Identifies the currently active and inactive brokers.
        2. Reboots each inactive broker and waits for RDS services to come back online.
        3. Promotes an inactive broker to active via Switch-ActiveBroker.
        4. Reboots the originally active broker.

    Timeout and retry values are read from the toolkit configuration if not supplied as parameters.
    The Connection Broker is also read from configuration if not provided; if neither is set, the command fails.
    It never prompts for input, so it can be scheduled. Progress is written to the information stream, which is
    shown by default; use -InformationAction SilentlyContinue to hide it.

    When the procedure finishes, one result object is returned. With -WhatIf, nothing is rebooted and nothing
    is returned.

    For the interactive version, use Start-ToolkitMenu: Server > Remote Desktop > Reboot Connection Brokers.

    Nothing is rebooted unless at least two brokers are found and the active broker is one of them. If any step
    fails, the procedure stops and throws a terminating error that names the failed step, lists what was already
    done, and reports the current active broker.

    .PARAMETER BrokerServer
    Optional. The hostname or FQDN of any broker in the HA group. Defaults to the RDBrokerServer configuration
    value.

    .PARAMETER TimeoutSecs
    Optional. Seconds to wait for a broker to respond after reboot. Defaults to the RDTimeoutSecs
    configuration value if 0 or not supplied.

    .PARAMETER MaxRetries
    Optional. Maximum number of service polling attempts per broker. Defaults to the RDMaxRetries
    configuration value if 0 or not supplied.

    .PARAMETER Force
    Suppresses the confirmation prompt unless -Confirm is also specified.

    .EXAMPLE
    Restart-RDSBroker -BrokerServer 'broker01' -WhatIf
    # Resolves the HA group through broker01 and shows the reboot plan without rebooting anything.

    .EXAMPLE
    Restart-RDSBroker
    # Reads the broker server from toolkit config, asks for confirmation, then performs the full reboot cycle.

    .EXAMPLE
    $result = Restart-RDSBroker -Force -InformationAction SilentlyContinue
    "$($result.PreviousActiveBroker) -> $($result.ActiveBroker) in $($result.Duration)"
    # Unattended run (for example from a scheduled task) that reports the outcome.

    .OUTPUTS
    PSCustomObject with BrokerServers, PreviousActiveBroker, ActiveBroker, RebootedBrokers, and Duration.

    .NOTES
    Author: Alexander Christian
    Requires the RemoteDesktop PowerShell module and WinRM access to all broker servers.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([pscustomobject])]
    param(
        [string]$BrokerServer,
        [int]$TimeoutSecs,
        [int]$MaxRetries,
        [switch]$Force
    )

    begin {
        if (-not $PSBoundParameters.ContainsKey('InformationAction')) {
            $InformationPreference = 'Continue'
        }

        if ($Force -and -not $PSBoundParameters.ContainsKey('Confirm')) {
            $ConfirmPreference = 'None'
        }
        $config = Get-ToolkitConfig
        if ($TimeoutSecs -eq 0) {
            $TimeoutSecs = $config.RDTimeoutSecs
        }
        if ($MaxRetries -eq 0) {
            $MaxRetries = $config.RDMaxRetries
        }
        if (-not $BrokerServer) {
            $BrokerServer = $config.RDBrokerServer
        }
        if (-not $BrokerServer) {
            $errorParams = @{
                Message  = 'No Connection Broker given. Use -BrokerServer, or set RDBrokerServer in the toolkit ' +
                'configuration.'
                ErrorId  = 'ConnectionBrokerMissing'
                Category = 'InvalidArgument'
            }
            $PSCmdlet.ThrowTerminatingError((Get-ToolkitErrorRecord @errorParams))
        }
        Write-Information "Checking $BrokerServer (DNS and WinRM)..."
        $BrokerServerFQDN = Confirm-ConnectionBroker -ConnectionBroker $BrokerServer
        Write-Information "Connection to $BrokerServerFQDN verified."
        try {
            Write-Information 'Getting list of broker servers...'
            $ServerParams = @{
                ConnectionBroker = $BrokerServerFQDN
                Role             = 'RDS-CONNECTION-BROKER'
                ErrorAction      = 'Stop'
            }
            $BrokerServers = (Get-RDServer @ServerParams).Server
            Write-Information "Broker servers: $($BrokerServers -join ', ')"
        } catch {
            $errorParams = @{
                Message        = "Failed to get the list of broker servers from ${BrokerServerFQDN}: " +
                $_.Exception.Message
                InnerException = $_.Exception
                ErrorId        = 'BrokerListFailed'
                Category       = 'ConnectionError'
                TargetObject   = $BrokerServerFQDN
            }
            $PSCmdlet.ThrowTerminatingError((Get-ToolkitErrorRecord @errorParams))
        }
    }

    process {
        # Tracks progress so a failure can say exactly what state the farm was left in.
        $completed = [System.Collections.Generic.List[string]]::new()
        $rebooted = [System.Collections.Generic.List[string]]::new()
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $step = 'determine the active broker'
        try {
            $ActiveBroker = (Get-ActiveBroker -BrokerServers $BrokerServers).ToUpper()
            $InactiveBrokers = @($BrokerServers | Where-Object { $_ -ne $ActiveBroker })

            Write-Information "Current active broker: $ActiveBroker"
            Write-Information "Inactive broker(s): $($InactiveBrokers -join ', ')"

            # Fail closed before any reboot if the HA topology is not what this procedure assumes.
            if ($ActiveBroker -notin $BrokerServers) {
                throw "Active broker '$ActiveBroker' is not in the broker list ($($BrokerServers -join ', ')). " +
                "Refusing to continue because the inactive/active split cannot be trusted."
            }
            if ($InactiveBrokers.Count -lt 1) {
                throw "Only one Connection Broker was found. A staggered reboot requires at least two brokers."
            }

            $NewActiveBroker = $InactiveBrokers[0]
            $plan = "Reboot $($InactiveBrokers -join ', '), make $NewActiveBroker active, " +
            "then reboot $ActiveBroker"
            if (-not $PSCmdlet.ShouldProcess($plan, 'Restart RDS Connection Brokers')) {
                return
            }

            foreach ($broker in $InactiveBrokers) {
                $step = "reboot inactive broker $broker"
                Write-Information "Rebooting inactive broker $broker..."
                Restart-ServerAndWait -ComputerName $broker -TimeoutSecs $TimeoutSecs -MaxRetries $MaxRetries
                $completed.Add("rebooted $broker")
                $rebooted.Add($broker)
                Write-Information "$broker is back and its RDS services are running."
            }

            $step = "make $NewActiveBroker the active broker"
            Write-Information "Switching the active broker from $ActiveBroker to $NewActiveBroker..."
            $switchParams = @{
                ActiveBroker    = $ActiveBroker
                NewActiveBroker = $NewActiveBroker
                BrokerServers   = $BrokerServers
            }
            Switch-ActiveBroker @switchParams
            $completed.Add("made $NewActiveBroker active")
            Write-Information "The active broker is now $NewActiveBroker."

            $step = "reboot original active broker $ActiveBroker"
            Write-Information "Rebooting the original active broker $ActiveBroker..."
            Restart-ServerAndWait -ComputerName $ActiveBroker -TimeoutSecs $TimeoutSecs -MaxRetries $MaxRetries
            $completed.Add("rebooted $ActiveBroker")
            $rebooted.Add($ActiveBroker)
            Write-Information "$ActiveBroker is back and its RDS services are running."

            [pscustomobject]@{
                BrokerServers        = @($BrokerServers)
                PreviousActiveBroker = $ActiveBroker
                ActiveBroker         = $NewActiveBroker
                RebootedBrokers      = $rebooted.ToArray()
                Duration             = $stopwatch.Elapsed
            }
        } catch {
            # Capture the failure first: the nested try/catch below would replace $_
            $failure = $_
            $done = if ($completed.Count -gt 0) { $completed -join '; ' } else { 'nothing' }
            $currentActive = try {
                Get-ActiveBroker -BrokerServers $BrokerServers -WarningAction SilentlyContinue
            } catch {
                'unknown (could not be queried)'
            }
            $message = "Broker maintenance stopped at step '$step': $($failure.Exception.Message) " +
            "Completed before the failure: $done. Current active broker: $currentActive. " +
            'Check the brokers before running this again.'
            $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                [System.InvalidOperationException]::new($message, $failure.Exception),
                'SysAdminToolkit.BrokerMaintenanceFailed',
                [System.Management.Automation.ErrorCategory]::OperationStopped,
                $step
            )
            $PSCmdlet.ThrowTerminatingError($errorRecord)
        }
    }
}
