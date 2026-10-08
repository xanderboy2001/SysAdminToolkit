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


function Get-ActiveBroker {
    [OutputType([string])]
    param(
        [Parameter(
            Mandatory,
            HelpMessage = "One or more Connection Broker FQDNs to query in order."
        )]
        [ValidateNotNullOrEmpty()]
        [string[]]$BrokerServers
    )

    Write-Host "Querying RDS High Availability Status..." -ForegroundColor Cyan
    foreach ($server in $BrokerServers) {
        try {
            $ActiveServer = (
                Get-RDConnectionBrokerHighAvailability -ConnectionBroker $server -ErrorAction Stop
            ).ActiveManagementServer
            break
        } catch {
            $msg = "Could not get active broker from ${server}: $($_.Exception.Message)"
            Write-Warning $msg
            continue
        }
    }

    if ($ActiveServer) {
        Write-Host "The active RDS Broker is '$ActiveServer'" -ForegroundColor Green
        $ActiveServer
    } else {
        throw "Failed to determine active broker."
    }
}


function Get-RDCollections {
    [OutputType([string[]])]
    param(
        [Parameter(
            Mandatory,
            HelpMessage = "The active RDS Connection Broker FQDN."
        )]
        [ValidateNotNullOrEmpty()]
        [string]$ConnectionBroker
    )

    Get-RDSessionCollection -ConnectionBroker $ConnectionBroker |
        Where-Object { $_.ResourceType -eq 'Remote Desktop' } |
        Select-Object -ExpandProperty CollectionName
}


function Get-RDHosts {
    [OutputType([string[]])]
    param(
        [Parameter(
            Mandatory,
            HelpMessage = "The name of the Remote Desktop Session Collection to query."
        )]
        [ValidateNotNullOrEmpty()]
        [string]$CollectionName,

        [Parameter(
            Mandatory,
            HelpMessage = "The FQDN of the active Remote Desktop Connection Broker."
        )]
        [ValidateNotNullOrEmpty()]
        [string]$ConnectionBroker
    )

    Get-RDSessionHost -ConnectionBroker $ConnectionBroker -CollectionName $CollectionName |
        Select-Object -ExpandProperty SessionHost |
        ForEach-Object { ($_ -split '\.', 2)[0].ToLower() } |
        Sort-Object
}
