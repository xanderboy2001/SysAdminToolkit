function Convert-UsernameFormat {
    <#
    .SYNOPSIS
    Normalizes a username string to lowercase and strips any email domain suffix.

    .DESCRIPTION
    Converts the input username to lowercase. If the username contains the '@' symbol, everything from the '@'
    onward is removed, leaving only the local-part of the address. This allows email addresses to be passed in
    and treated as plain usernames.

    .PARAMETER Username
    The raw username or email address string to normalize.

    .EXAMPLE
    Convert-UsernameFormat -Username 'John.Doe@contoso.com'
    # Returns 'john.doe'

    .EXAMPLE
    Convert-UsernameFormat -Username 'JDOE'
    # Returns 'jdoe'

    .OUTPUTS
    System.String. The normalized username.

    .NOTES
    Author: Alexander Christian
    #>
    [OutputType([string])]
    param([String]$Username)

    $Username = $Username.ToLower()

    # If username is email address (contains '@' symbol), remove everything after the '@'
    if ($Username -like '*@*') {
        $Username = $Username -replace '@.*$', ''
    }

    return $Username
}
