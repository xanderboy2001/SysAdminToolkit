function Confirm-ConnectionBroker {
    <#
    .SYNOPSIS
    Resolves a Connection Broker name and checks that it accepts PowerShell remoting.

    .DESCRIPTION
    Returns the broker's fully qualified name in upper case, as the RDS cmdlets report broker names. Throws a
    terminating error (from Resolve-ToolkitHost) if the name does not resolve or WinRM does not answer.

    .PARAMETER ConnectionBroker
    The host name or FQDN of a Connection Broker.

    .EXAMPLE
    Confirm-ConnectionBroker -ConnectionBroker 'broker01'
    # Returns 'BROKER01.CONTOSO.COM'.

    .OUTPUTS
    System.String

    .NOTES
    Author: Alexander Christian
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, HelpMessage = "The hostname of a RDS Connection Broker to validate.")]
        [ValidateNotNullOrEmpty()]
        [string]$ConnectionBroker
    )

    (Resolve-ToolkitHost -Name $ConnectionBroker -RequireWinRM).ToUpper()
}
