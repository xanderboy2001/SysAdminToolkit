<#
.SYNOPSIS
Active Directory submenu functions for the SysAdmin Toolkit.

.DESCRIPTION
Contains the Show-ADMenu function, which displays Active Directory-related options
such as Reset Password, Unlock Account, Disable User, and Create User.
Handles user input and navigates back to the Server menu if requested.

.NOTES
Author: Alexander Christian
#>
function Show-ADMenu {
    <#
    .SYNOPSIS
    Displays the Active Directory submenu in the SysAdmin Toolkit.

    .DESCRIPTION
    Shows Active Directory-related options such as Reset Password, Unlock Account,
    Disable User, and Create User. Handles user input and executes the corresponding
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
        'Create User'
    )

    $result = Show-Menu -Title 'Active Directory Menu' -Options $menuOptions

    if ($result.Quit) { return }
    if ($result.Back) { Show-ServerMenu }

    switch ($result.Index) {
        0 { Write-Host 'Reset Password (placeholder)' -ForegroundColor Cyan }
        1 { Write-Host 'Unlock Account (placeholder)' -ForegroundColor Cyan }
        2 { Write-Host 'Disable User (placeholder)' -ForegroundColor Cyan }
        3 { Write-Host 'Create-User (placeholder)' -ForegroundColor Cyan }
    }
}