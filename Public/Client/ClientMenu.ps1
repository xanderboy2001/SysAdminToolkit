function Show-ClientMenu {
    <#
    .SYNOPSIS
    Displays the Client menu in the SysAdmin Toolkit.

    .DESCRIPTION
    Shows client-related options such as unlcoking a file held open by a process.
    Handles user input and navigates to the appropriate function or returns to the main menu if requested.

    .EXAMPLE
    Show-ClientMenu
    # Displays the Client menu and waits for the user to select an option.

    .NOTES
    Author: Alexander Christian
    #>
    [CmdletBinding()]
    param()
    $menuOptions = @(
        'Unlock a file being held by a process'
    )
    $result = Show-Menu -Title 'Client Menu' -Options $menuOptions

    if ($result.Quit) {
        return 
    }
    if ($result.Back) {
        Start-ToolkitMenu 
    }

    switch ($result.Index) {
        0 {
            Stop-FileLock 
        }
    }
}
