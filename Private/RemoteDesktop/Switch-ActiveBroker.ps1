function Switch-ActiveBroker {
    <#
    .SYNOPSIS
    Makes another Connection Broker the active management server and waits until the change is confirmed.

    .DESCRIPTION
    Calls Set-RDActiveManagementServer, then polls Get-ActiveBroker every PollSeconds until it reports
    NewActiveBroker. Throws if change is not confirmed within TimeoutSeconds. The last broker reported as
    active is included in the error.

    .PARAMETER ActiveBroker
    The FQDN of the currently active broker (used in messages).

    .PARAMETER NewActiveBroker
    The FQDN of the broker to make active.

    .PARAMETER BrokerServers
    All broker FQDNs in the HA group, used to query the active broker.

    .PARAMETER TimeoutSeconds
    Maximum time to wait for the change to be confirmed.

    .PARAMETER PollSeconds
    Delay between checks.

    .EXAMPLE
    Switch-ActiveBroker -ActiveBroker broker1.contoso.com -NewActiveBroker broker2.contoso.com `
        -BrokerServers broker1.contoso.com, broker2.contoso.com

    .NOTES
    Author: Alexander Christian
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, HelpMessage = "The FQDN of the currently active Connection Broker.")]
        [ValidateNotNullOrEmpty()]
        [string]$ActiveBroker,

        [Parameter(Mandatory, HelpMessage = "The FQDN of the broker to promote as the new active broker.")]
        [ValidateNotNullOrEmpty()]
        [string]$NewActiveBroker,

        [Parameter(Mandatory, HelpMessage = "All Connection Broker FQDNs in the HA group.")]
        [ValidateNotNullOrEmpty()]
        [string[]]$BrokerServers,

        [ValidateRange(1, 3600)]
        [int]$TimeoutSeconds = 120,

        [ValidateRange(1, 60)]
        [int]$PollSeconds = 10
    )

    try {
        Set-RDActiveManagementServer -ManagementServer $NewActiveBroker -ErrorAction Stop
    } catch {
        throw [System.InvalidOperationException]::new(
            "Set-RDActiveManagementServer failed for ${NewActiveBroker}: $($_.Exception.Message)", $_.Exception
        )
    }
    Write-Information "Requested $NewActiveBroker as the active broker; waiting for confirmation..."

    $reported = "unknown"
    $maxPolls = [math]::Ceiling($TimeoutSeconds / $PollSeconds)
    for ($poll = 1; $poll -le $maxPolls; $poll++) {
        Start-Sleep -Seconds $PollSeconds
        try {
            $reported = Get-ActiveBroker -BrokerServers $BrokerServers -WarningAction SilentlyContinue
        } catch {
            # Brokers can be briefly unavailable during the switch; keep polling.
            $reported = "unknown ($($_.Exception.Message))"
            continue
        }
        # -eq is case-insensitive, so 'BROKER2.CONTOSO.COM' matches 'broker2.contoso.com'.
        if ($reported -eq $NewActiveBroker) {
            Write-Information "Confirmed: $NewActiveBroker is the active broker."
            return
        }
    }

    throw ("The active broker did not change to $NewActiveBroker within ${TimeoutSeconds}s " +
        "(previously $ActiveBroker; last reported: $reported).")
}
