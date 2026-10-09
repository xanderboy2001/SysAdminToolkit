function Switch-ActiveBroker {
    <#
    .SYNOPSIS

        Switches the active broker of RDS from the currently active server to the currently inactive server.
        Throws an error if the switch did not apply after 10 seconds.

    .PARAMETER ActiveBroker
        [string] The FQDN of the currently active broker. Mandatory

    .PARAMETER InactiveBroker
        [string] The FQDN of the currently inactive broker. Mandatory.

    .EXAMPLE

        PS> Switch-ActiveBroker broker1.domain.com broker2.domain.com

    .EXAMPLE

        PS> SwitchActiveBroker -ActiveBroker broker1.domain.com -InactiveBroker broker2.domain.com

    #>
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory,
            HelpMessage = "The FQDN of the currently active Connection Broker."
        )]
        [ValidateNotNullOrEmpty()]
        [string]$ActiveBroker,

        [Parameter(
            Mandatory,
            HelpMessage = "The FQDN of the broker to promote as the new active Connection Broker."
        )]
        [ValidateNotNullOrEmpty()]
        [string]$NewActiveBroker,

        [Parameter(
            Mandatory,
            HelpMessage = "All Connection Broker FQDNs in the HA group, used to verify the switch."
        )]
        [ValidateNotNullOrEmpty()]
        [string[]]$BrokerServers
    )

    try {
        Set-RDActiveManagementServer -ManagementServer $NewActiveBroker -ErrorAction Stop
        Write-Information "Successfully set $NewActiveBroker as the active broker."
    } catch {
        throw "Fatal error when switching active brokers: $($_.Exception.Message)"
    }

    # Wait, then check if $InactiveBroker was successfully made active.
    Start-Sleep -Seconds 10
    if ((Get-ActiveBroker -BrokerServers $BrokerServers) -ne $NewActiveBroker) {
        throw ("Failed to switch the Active Management Server to $NewActiveBroker." +
            "Current active is still $ActiveBroker.")
    }
}
