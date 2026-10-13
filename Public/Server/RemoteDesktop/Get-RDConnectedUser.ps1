function Get-RDConnectedUser {
    <#
    .SYNOPSIS
    Shows the users connected to one Remote Desktop session host, chosen from menus.

    .DESCRIPTION
    Resolves the Connection Broker, finds the active broker in the high-availability group, and asks you to choose
    a session collection and then a session host. Lists the full name and username of every user connected to
    that host. Users that cannot be found in Active Directory are shown as '(not found in AD)'.

    This command is interactive: it writes to the console and returns no objects. Returning session objects is
    planned (GitHub issue #1).

    .PARAMETER ConnectionBroker
    Optional. The hostname or FQDN of any Connection Broker in the deployment. If omitted, you are prompted. The
    toolkit menu passes the RDBrokerServer configuration value.

    .EXAMPLE
    Get-RDConnectedUser -ConnectionBroker 'broker01'
    # Choose a collection and a host, then see who is connected to it.

    .EXAMPLE
    Get-RDConnectedUser
    # Prompts for the Connection Broker first.

    .OUTPUTS
    None. Results are written to the console.

    .NOTES
    Author: Alexander Christian
    Requires the RemoteDesktop and ActiveDirectory modules. The old name Get-RDConnectedUsers still works as an
    alias.
    #>
    [CmdletBinding()]
    [Alias('Get-RDConnectedUsers')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '',
        Justification = 'Interactive wizard; to be split into core command + UI. See issue #1 (F-21).')]
    param(
        [string]$ConnectionBroker
    )

    if (-not $ConnectionBroker) {
        $prompt = "Enter the name of one of the Remote Desktop Connection Broker Servers (e.g. 'broker1')"
        $ConnectionBroker = Read-Host -Prompt $prompt
    }

    $BrokerFQDN = Confirm-ConnectionBroker -ConnectionBroker $ConnectionBroker

    $ActiveServer = Get-ActiveBroker -BrokerServers $BrokerFQDN

    $Collections = Get-RDCollectionName -ConnectionBroker $ActiveServer
    do {
        $result = Show-Menu -Title "Remote Desktop Server Collections" -Options $Collections
    } until ($result.Quit -or $result.Back -or $null -ne $result.Index)

    if ($result.Quit) {
        return
    }
    if ($result.Back) {
        return
    }

    $SelectedCollection = $Collections[$result.Index]
    Write-Host "You have selected '$SelectedCollection'" -ForegroundColor Green

    $Hosts = Get-RDHostName -ConnectionBroker $ActiveServer -CollectionName $SelectedCollection

    do {
        $result = Show-Menu -Title "Remote Desktop Hosts in '$SelectedCollection'" -Options $Hosts
    } until ($result.Quit -or $result.Back -or $null -ne $result.Index)

    if ($result.Quit) {
        return
    }
    if ($result.Back) {
        return
    }
    $SelectedHost = $Hosts[$result.Index]
    Write-Host "You have selected '$SelectedHost'" -ForegroundColor Green
    $Users = Get-RDUserSession -ConnectionBroker $ActiveServer -CollectionName $SelectedCollection |
        Where-Object { $_.HostServer -eq $SelectedHost -or $_.HostServer -like "${SelectedHost}.*" } |
        Select-Object -ExpandProperty UserName

    Write-Host "There are currently $($Users.Count) connected to ${SelectedHost}:" -ForegroundColor Magenta
    foreach ($user in $Users) {
        try {
            $FullName = Get-FullNameFromUsername -Username $user
        } catch {
            $FullName = '(not found in AD)'
        }
        Write-Host "$FullName ($user)"
    }
}
