function Show-MenuInstruction {
    <#
    .SYNOPSIS
    Displays instructions for user input in menus.

    .DESCRIPTION
    Shows the prompt asking the user to select an option,
    and displays instructions for quitting or going back.
    Prompt text is white; quit/back instructions are yellow.

    .PARAMETER QuitOptions
    Array of strings representing input commands that trigger quitting the menu.

    .PARAMETER BackOptions
    Array of strings representing input commands that return to the previous menu.

    .EXAMPLE
    Show-MenuInstruction -QuitOptions @('Q','Exit') -BackOptions @('B')
    # Displays input instructions for quit and back options.

    .NOTES
    Author: Alexander Christian
    #>
    param(
        [String[]]$QuitOptions,
        [String[]]$BackOptions
    )

    Write-Host 'Please enter the corresponding number to select the item.' -ForegroundColor White

    if ($QuitOptions) {
        $QuitOptList = $QuitOptions -join ', '
        Write-Host "You may also enter $QuitOptList to quit the application." -ForegroundColor Yellow
    }

    if ($BackOptions) {
        $BackOptList = $BackOptions -join ', '
        Write-Host "You may also enter $BackOptList to return to the main menu." -ForegroundColor Yellow
    }
}
