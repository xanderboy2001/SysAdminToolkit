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

    Write-Verbose "Querying RDS High Availability Status..."
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
        Write-Verbose "The active RDS Broker is '$ActiveServer'"
        $ActiveServer
    } else {
        throw "Failed to determine active broker."
    }
}
