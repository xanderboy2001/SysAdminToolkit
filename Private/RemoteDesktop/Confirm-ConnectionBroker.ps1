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
    Write-Host "Resolved '$ConnectionBroker' to '$BrokerFQDN'" -ForegroundColor Green

    Write-Host "Testing connection to '$BrokerFQDN'..." -ForegroundColor Cyan
    if (-not (Test-Connection -ComputerName $BrokerFQDN -Count 1 -Quiet)) {
        throw "Could not connect to '$BrokerFQDN'"
    }
    Write-Host "Connection to '$BrokerFQDN' verified." -ForegroundColor Green
    $BrokerFQDN
}
