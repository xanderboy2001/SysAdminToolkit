<#
.SYNOPSIS
Main menu functions for the SysAdmin Toolkit.

.DESCRIPTION
Contains the Start-ToolkitMenu function, which displays the main menu
and routes users to either the Server or Client menus.
Handles user input for quitting or navigating submenus.

.NOTES
Author: Alexander Christian
#>

function Start-ToolkitMenu {
    <#
    .SYNOPSIS
    Displays the main menu for the SysAdmin Toolkit.

    .DESCRIPTION
    Shows the main menu with options for Server and Client menus.
    Handles user input and navigates to the appropriate submenu
    or exits the toolkit if a quit command is entered.

    .EXAMPLE
    Start-ToolkitMenu
    # Displays the main menu and waits for the user to select Server or Client.

    .NOTES
    Author: Alexander Christian
    #>


    $menuOptions = @('Server', 'Client')

    do {
        $result = Show-Menu -Title 'SysAdmin Toolkit' -Options $menuOptions -BackOptions @()
        if ($result.Quit) {
            Write-Host 'Exiting SysAdmin Toolkit...' -ForegroundColor Yellow
            return
        }

        switch ($result.Index) {
            0 { Show-ServerMenu; return }
            1 { Show-ClientMenu; return }
        }
    } while ($true)
}