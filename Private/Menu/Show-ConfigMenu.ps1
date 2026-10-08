function Show-ConfigMenu {
    <#
    .SYNOPSIS
    Displays the Configuration menu in the SysAdmin Toolkit.

    .DESCRIPTION
    Shows a menu with options to view, edit, or reset the toolkit configuration. Handles user input and navigates
    to the appropriate function or returns to the main menu if a back command is entered.

    .EXAMPLE
    Show-ConfigMenu
    # Displays the Configuration menu and waits for the user to select an option.

    .NOTES
    Author: Alexander Christian
    #>
    [CmdletBinding()]
    param()
    $menuOptions = @(
        'View Config'
        'Edit Config'
        'Reset Config to Defaults'
    )

    $result = Show-Menu -Title 'Configuration' -Options $menuOptions

    if ($result.Quit) {
        return
    }
    if ($result.Back) {
        Start-ToolkitMenu
    }

    switch ($result.Index) {
        0 {
            Invoke-ViewConfig
        }
        1 {
            Invoke-EditConfig
        }
        2 {
            Invoke-ResetConfig
        }
    }
}
