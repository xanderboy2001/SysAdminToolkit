function Start-ToolkitMenu {
    <#
    .SYNOPSIS
    Displays the main menu for the SysAdmin Toolkit.

    .DESCRIPTION
    Shows the main menu with options for Server, Client, and Config menus.
    Handles user input and navigates to the appropriate submenu or exits the toolkit if a quit command is entered.

    .EXAMPLE
    Start-ToolkitMenu
    # Displays the main menu and waits for the user to select an option.

    .NOTES
    Author: Alexander Christian
    #>
    $menuOptions = @('Server', 'Client', 'Config')

    do {
        $result = Show-Menu -Title 'SysAdmin Toolkit' -Options $menuOptions -BackOptions @()
        if ($result.Quit) {
            Write-Host 'Exiting SysAdmin Toolkit...' -ForegroundColor Yellow
            return
        }

        switch ($result.Index) {
            0 {
                Show-ServerMenu; return 
            }
            1 {
                Show-ClientMenu; return 
            }
            2 {
                Show-ConfigMenu; return 
            }
        }
    } while ($true)
}
