function Show-Menu {
    <#
    .SYNOPSIS
    Displays a menu with header, options, and handles user selection.

    .DESCRIPTION
    Combines Show-MenuHeader, Show-MenuOptions, and Read-MenuSelection to display a menu.
    Returns a hashtable describing the user's choice, quit, or back action.

    .PARAMETER Title
    The title of the menu.

    .PARAMETER Options
    Array of strings representing menu options.

    .PARAMETER QuitOptions
    Optional array of strings representing quit commands. Default: @('Q','Quit','E','Exit','C','Cancel').

    .PARAMETER BackOptions
    Optional array of strings representing back commands. Default: @('B','Back').

    .EXAMPLE
    $result = Show-Menu -Title 'Main Menu' -Options @('Option1','Option2')
    # Displays the menu and returns the user's selection.

    .NOTES
    Author: Alexander Christian
    #>
    [OutputType([hashtable])]
    param(
        [String]$Title,
        [String[]]$Options,
        [String[]]$QuitOptions = @('Q', 'Quit', 'E', 'Exit', 'C', 'Cancel'),
        [String[]]$BackOptions = @('B', 'Back')
    )

    Show-MenuHeader -Title $Title
    Show-MenuOptions -Options $Options

    return Read-MenuSelection -Options $Options -QuitOptions $QuitOptions -BackOptions $BackOptions
}
