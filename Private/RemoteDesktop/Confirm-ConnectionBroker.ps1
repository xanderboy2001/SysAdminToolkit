function Confirm-ConnectionBroker {
    [OutputType([string])]
    param(
        [Parameter(
            Mandatory,
            HelpMessage = "The hostname of a RDS Connection Broker to validate."
        )]
        [ValidateNotNullOrEmpty()]
        [string]$ConnectionBroker
    )

    try {
        $BrokerFQDN = [System.Net.Dns]::GetHostByName($ConnectionBroker).HostName.ToUpper()
    } catch [System.Net.Sockets.SocketException] {
        throw "Could not resolve hostname '$ConnectionBroker': $($_.Exception.Message)"
    }
    Write-Verbose "Resolved '$ConnectionBroker' to '$BrokerFQDN'"

    Write-Verbose "Testing connection to '$BrokerFQDN'..."
    if (-not (Test-Connection -ComputerName $BrokerFQDN -Count 1 -Quiet)) {
        throw "Could not connect to '$BrokerFQDN'"
    }
    Write-Verbose "Connection to '$BrokerFQDN' verified."
    $BrokerFQDN
}
