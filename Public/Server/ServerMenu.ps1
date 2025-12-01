<#
.SYNOPSIS
Server menu functions for the SysAdmin Toolkit.

.DESCRIPTION
Contains the Show-ServerMenu function, which displays server-related options
such as Active Directory, Microsoft Graph, and Troubleshooting.
Handles user input and navigates to submenus or returns to the main menu.

.NOTES
Author: Alexander Christian
#>
function Show-ServerMenu {
    <#
    .SYNOPSIS
    Displays the Server menu in the SysAdmin Toolkit.

    .DESCRIPTION
    Shows the server-specific menu with options for Active Directory, Microsoft Graph, and Troubleshooting.
    Handles user input and navigates to the appropriate submenu or returns to the main menu if requested.

    .EXAMPLE
    Show-ServerMenu
    # Displays the Server menu and waits for the user to select an option.

    .NOTES
    Author: Alexander Christian
    #>

    $menuOptions = @(
        'Active Directory'
        'Microsoft Graph'
        'Troubleshooting'
    )
    $result = Show-Menu -Title 'Server Menu' -Options $menuOptions

    if ($result.Quit) { return }
    if ($result.Back) { Start-ToolkitMenu }

    switch ($result.Index) {
        0 { Show-ADMenu }
        1 { Write-Host 'Microsoft Graph menu not yet implemented' -ForegroundColor Cyan }
        2 { Write-Host 'Troubleshooting menu not yet implemented' -ForegroundColor Cyan }
    }
}