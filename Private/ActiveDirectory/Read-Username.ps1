function Read-Username {
    <#
    .SYNOPSIS
    Prompts the user to enter a username and validates its format.

    .DESCRIPTION
    Repeatedly prompts for a username until the input matches one of the accepted formats:
    - 'firstname.lastname' (e.g. john.doe)
    - 'firstname lastname' (e.g. john doe)
    - 'firstnamelastinitial' (e.g. johnd)

    Input is normalized through Convert-UsernameFormat before validation.

    .EXAMPLE
    $username = Read-Username
    # Prompts for a username and returns it once a valid format is entered.

    .OUTPUTS
    System.String. The validated and normalized username string.

    .NOTES
    Author: Alexander Christian
    #>
    [OutputType([string])]
    param()
    while ($true) {
        $usernameInput = Read-Host -Prompt 'Enter the username of the user'
        $username = Convert-UsernameFormat -Username $usernameInput

        if (
            $username -match '^[a-z]+\.[a-z]+$' -or
            $username -match '^[a-z]+ [a-z]+$' -or
            $username -match '^[a-z]+$'
        ) {
            return $username
        }

        Write-Host ("Invalid input must be in either format: '<first name>.<last name>', " +
            "'<first name> <last name>', or <first name><last initial>") -ForegroundColor Red
    }
}
