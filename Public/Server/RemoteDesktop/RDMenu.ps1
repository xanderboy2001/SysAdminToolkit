function Show-RDMenu {
    <#
    .SYNOPSIS
    Displays the Remote Desktop menu in the SysAdmin Toolkit.

    .DESCRIPTION
    Shows Remote Desktop management options, including rebooting Connection Brokers and toggling new connection
    acceptance on individual session hosts. The Connection Broker server is read from the toolkit configuration.
    Handles user input and navigates back to the Server menu if requested.

    .EXAMPLE
    Show-RDMenu
    # Displays the Remote Desktop menu and waits for the user to select an option.
    
    .NOTES
    Author: Alexander Christian
    #>
    [CmdletBinding()]
    param()
    $menuOptions = @(
        'Reboot Connection Brokers',
        'Toggle New Connections on Server'
    )

    $result = Show-Menu -Title 'Remote Desktop Menu' -Options $menuOptions

    if ($result.Quit) {
        return 
    }
    if ($result.Back) {
        Show-ServerMenu 
    }

    $brokerServer = (Get-ToolkitConfig).RDBrokerServer

    switch ($result.Index) {
        0 {
            Restart-RDS-Broker -BrokerServer $brokerServer 
        }
        1 {
            Set-RDSessionHostMode -ConnectionBroker $brokerServer 
        }
    }
}
