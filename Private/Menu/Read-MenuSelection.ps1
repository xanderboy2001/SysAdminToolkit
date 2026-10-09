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
    [OutputType([hashtable])]
    param(
        [String[]]$Options,
        [String[]]$QuitOptions,
        [String[]]$BackOptions
    )

    Show-MenuInstruction -QuitOptions $QuitOptions -BackOptions $BackOptions
    $choice = Read-Host

    # Quit
    if ($choice -in $QuitOptions) {
        return @{
            Quit   = $true
            Back   = $false
            Choice = $choice
            Index  = $null
        }
    }

    # Back
    if ($choice -in $BackOptions) {
        return @{
            Quit   = $false
            Back   = $true
            Choice = $choice
            Index  = $null
        }
    }

    # Numeric menu choice
    if ($choice -match '^\d+$') {
        $i = [int]$choice
        if ($i -ge 1 -and $i -le $Options.Count) {
            return @{
                Quit   = $false
                Back   = $false
                Choice = $choice
                Index  = $i - 1
            }
        }
    }

    # Invalid input
    Write-Host 'Invalid input' -ForegroundColor Red
    return @{
        Quit   = $false
        Back   = $false
        Choice = $choice
        Index  = $null
    }
}
