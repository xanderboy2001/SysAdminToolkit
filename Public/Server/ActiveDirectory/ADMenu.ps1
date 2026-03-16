function Show-ADMenu {
    <#
    .SYNOPSIS
    Displays the Active Directory submenu in the SysAdmin Toolkit.

    .DESCRIPTION
    Shows Active Directory-related options such as Reset Password, Unlock Account,
    Disable User, and Start AD Sync. Handles user input and executes the corresponding
    action placeholder or returns to the Server menu if requested.

    .EXAMPLE
    Show-ADMenu
    # Displays the Active Directory menu and waits for user selection.

    .NOTES
    Author: Alexander Christian
    #>

    $menuOptions = @(
        'Reset Password'
        'Unlock Account'
        'Disable User'
        'Start AD Sync'
    )

    $result = Show-Menu -Title 'Active Directory Menu' -Options $menuOptions

    if ($result.Quit) {
        return 
    }
    if ($result.Back) {
        Show-ServerMenu 
    }

    switch ($result.Index) {
        0 {
            Invoke-ADPasswordReset 
        }
        1 {
            Invoke-ADAccountUnlock 
        }
        2 {
            Invoke-ADAccountDisable 
        }
        3 {
            Invoke-ADSync 
        }
    }
}
