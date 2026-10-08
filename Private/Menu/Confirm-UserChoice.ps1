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
