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
