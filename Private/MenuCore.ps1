<#
.SYNOPSIS
Core menu utility functions for the SysAdmin Toolkit.

.DESCRIPTION
Contains utility functions to display menus and read user input, including:
- Show-MenuHeader
- Show-MenuOptions
- Show-MenuInstructions
- Read-MenuSelection
- Show-Menu
- Confirm-UserChoice

These functions handle menu formatting, option alignment, input prompts,
and return a hashtable describing the user’s selection.

.NOTES
Author: Alexander Christian
#>
function Show-MenuOptions {
    <#
    .SYNOPSIS
    Displays a numbered list of menu options in green.

    .DESCRIPTION
    Outputs each string in the provided $Options array as a numbered menu item,
    aligning numbers and option text for a clean display.

    .PARAMETER Options
    An array of strings representing the menu options to display.

    .EXAMPLE
    Show-MenuOptions -Options @('Option1','Option2','Option3')
    # Displays the options as a numbered list in green.

    .NOTES
    Author: Alexander Christian
    #>
    [CmdletBinding()]
    param(
        [String[]]$Options
    )

    # Determine max width of option numbers (for padding)
    $maxIndexLength = ($Options.Count).ToString().Length

    # Determine max length of option text (optional, for nice spacing)
    $maxOptionLength = ($Options | Measure-Object -Maximum Length).Maximum

    for ($i = 0; $i -lt $Options.Count; $i++) {
        $IndexStr = ($i + 1).ToString().PadLeft($maxIndexLength)
        $optionStr = $Options[$i].PadRight($maxOptionLength)
        Write-Host "$IndexStr. $OptionStr" -ForegroundColor Green
    }
}

function Show-MenuHeader {
    <#
    .SYNOPSIS
    Displays a centered menu header with '=' framing.

    .DESCRIPTION
    Outputs the given title centered within a row of '=' characters.
    The total width of the header can be adjusted using the MenuWidth parameter.

    .PARAMETER Title
    The text to display as the menu header.

    .PARAMETER MenuWidth
    Optional. Total width of the header line. Defaults to 72 characters.
    If the specified width is less than the title length + padding, it is automatically adjusted.

    .EXAMPLE
    Show-MenuHeader -Title 'Active Directory Menu'
    # Displays a centered header with '=' framing in cyan.

    .NOTES
    Author: Alexander Christian
    #>
    [CmdletBinding()]
    param(
        [String]$Title,
        [int]$MenuWidth = 72 # default width; can be adjusted
    )

    # Ensure total width is at least the length of the title + padding
    if ($MenuWidth -lt ($Title.Length + 4)) {
        $MenuWidth = $Title.Length + 4
    }

    # Center the title
    $padding = ($MenuWidth - $Title.Length - 2) / 2
    $titleLine = '=' * [math]::Floor($padding) + " $Title " + '=' * [math]::Ceiling($padding)

    # Output
    Write-Host $titleLine -ForegroundColor Cyan
}

function Show-MenuInstructions {
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
    Show-MenuInstructions -QuitOptions @('Q','Exit') -BackOptions @('B')
    # Displays input instructions for quit and back options.

    .NOTES
    Author: Alexander Christian
    #>
    [CmdletBinding()]
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

function Read-MenuSelection {
    <#
    .SYNOPSIS
    Reads and validates a user's menu selection.

    .DESCRIPTION
    Displays instructions, reads user input, and determines whether
    the user wants to quit, go back, or select a numbered menu option.
    Returns a hashtable containing Quit, Back, Choice, and Index.

    .PARAMETER Options
    Array of strings representing the valid menu options.

    .PARAMETER QuitOptions
    Array of strings representing input commands that trigger quitting.

    .PARAMETER BackOptions
    Array of strings representing input commands that return to the previous menu.

    .OUTPUTS
    An object containing boolean properties called 'Back' and 'Quit' indicating which option the user selected.

    .EXAMPLE
    $result = Read-MenuSelection -Options @('Option1','Option2') -QuitOptions @('Q') -BackOptions @('B')
    # Waits for user input and returns a hashtable with selection details.

    .NOTES
    Author: Alexander Christian
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [String[]]$Options,
        [String[]]$QuitOptions,
        [String[]]$BackOptions
    )

    Show-MenuInstructions -QuitOptions $QuitOptions -BackOptions $BackOptions
    $choice = Read-Host

    # Quit
    if ($choice -in $QuitOptions) {
        return @{
            Quit    = $true
            Back    = $false
            Choice  = $choice
            Index   = $null
        }
    }

    # Back
    if ($choice -in $BackOptions) {
        return @{
            Quit    = $false
            Back    = $true
            Choice  = $choice
            Index   = $null
        }
    }

    # Numeric menu choice
    if ($choice -match '^\d+$') {
        $i = [int]$choice
        if ($i -ge 1 -and $i -le $Options.Count) {
            return @{
                Quit    = $false
                Back    = $false
                Choice  = $choice
                Index   = $i - 1
            }
        }
    }

    # Invalid input
    Write-Host 'Invalid input' -ForegroundColor Red
    return @{
        Quit    = $false
        Back    = $false
        Choice  = $choice
        Index   = $null
    }
}

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
    [CmdletBinding()]
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

function Confirm-UserChoice {
    <#
    .SYNOPSIS
    Prompts the user to confirm a potentially destructive or significant action.

    .DESCRIPTION
    Displays a confirmation prompt describing the action about to be taken and requires the user to enter
    'y', 'yes', 'n', or 'no'. Invalid input causes the prompt to repeat. Returns $true if the user confirms,
    $false otherwise.

    .PARAMETER Action
    A string describing the action to confirm, embedded in the prompt message.

    .EXAMPLE
    if (Confirm-UserChoice -Action 'disable the account for jdoe') {
        Disable-ADAccount -Identity 'jdoe'
    }
    # Asks the user to confirm before disabling the account.

    .OUTPUTS
    System.Boolean. Returns $true if the user entered 'y' or 'yes'; $false for 'n' or 'no'.

    .NOTES
    Author: Alexander Christian
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [String]$Action
    )
    $Prompt = "Are you sure you want to ${Action}? Enter 'y' or 'yes' to continue"
    $resp = Read-Host -Prompt $Prompt
    while ($resp -notmatch '^(y|yes|n|no)$') {
        Write-Host "Invalid input. Please enter 'y', 'yes', 'n', or 'no'." -ForegroundColor Yellow
        $resp = Read-Host -Prompt $Prompt
    }
    return ($resp -match '^(y|yes)$')
}
