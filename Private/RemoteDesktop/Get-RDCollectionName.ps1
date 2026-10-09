function Get-RDCollectionName {
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
