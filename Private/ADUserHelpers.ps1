function Convert-UsernameFormat {
    <#
    .SYNOPSIS
    Normalizes a username string to lowercase and strips any email domain suffix.

    .DESCRIPTION
    Converts the input username to lowercase. If the username contains the '@' symbol, everything from the '@'
    onward is removed, leaving only the local-part of the address. This allowes email addresses to be passed in
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
    param([String]$Username)

    $Username = $Username.ToLower()

    # If username is email address (contains '@' symbol), remove everything after the '@'
    if ($Username -like '*@*') {
        $Username = $Username -replace '@.*$', ''
    }

    return $Username
}

function Read-Username {
    <#
    .SYNOPSIS
    Prompts the user to enter a username and validates its format.

    .DESCRIPTION
    Repeatedly prompts for a username until the input matches one of the accepted formats:
    - 'firstname.lastname' (e.g. john.doe)
    - 'firstname lastname' (e.g. john doe)
    - 'firstnamelastinitial' (e.g. johnd)

    Input is normalized through Conver-UsernameFormat before validation.

    .EXAMPLE
    $username = Read-Username
    # Prompts for a username and returns it once a valid format is entered.

    .OUTPUTS
    System.String. The validated and normalized username string.

    .NOTES
    Author: Alexander Christian
    #>
    while ($true) {
        $usernameInput = Read-Host -Prompt 'Enter the username of the user'
        $username = Convert-UsernameFormat -Username $usernameInput

        if (
            $username -match '^[a-z]+\.[a-z]+$' -or `
                $username -match '^[a-z]+ [a-z]+$' -or `
                $username -match '^[a-z]+$'
        ) {
            return $username
        }

        Write-Host "Invalid input must be in either format: '<first name>.<last name>', " + `
            "'<first name> <last name>', or <first name><last initial>" `
            -ForegroundColor Red
    }
}

function Read-Password {
    <#
    .SYNOPSIS
    Securely reads and confirms a password from the user.

    .DESCRIPTION
    Prompts the user to enter a password twice as a SecureString and compares the two entries
    character-by-character using BSTR marshaling to avoid storing the password in plaintext at any point in
    memory. Continues prompting until both entries match. Returns the confirmed password as a SecureString.

    .EXAMPLE
    $securePassword = Read-Password
    # Prompts for a password twice and returns it as a SecureString once entries match.

    .OUTPUTS
    System.Security.SecureString. The confirmed password.

    .NOTES
    Author: Alexander Christian
    #>

    # Loop until passwords match
    while ($true) {

        # Read password twice as secure string
        $password1 = Read-Host 'Enter Password' -AsSecureString
        $password2 = Read-Host 'Confirm Password' -AsSecureString


        # Check that lengths are the same before bothering to check contents
        if ($password1.Length -eq $password2.Length) {

            # Convert secure string to byte array (so password is never in plaintext, even in memory)
            $bstr1 = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password1)
            $bstr2 = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password2)

            # Iterate over characters in byte array, check if they match
            $match = $true
            for ($i = 0; $i -lt $password1.Length; $i++) {
                $char1 = [System.Runtime.InteropServices.Marshal]::ReadInt16($bstr1, $i * 2)
                $char2 = [System.Runtime.InteropServices.Marshal]::ReadInt16($bstr2, $i * 2)

                # End checks and break out of for loop (back to while) if difference is detected
                if ($char1 -ne $char2) {
                    $match = $false
                    break
                }
            }

            # Clear byte arrays from memory
            [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr1)
            [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr2)

            if ($match) {
                Write-Host 'Passwords match' -ForegroundColor Green
                return $password1
            }
        }

        Write-Host 'Passwords do not match. Please try again.' -ForegroundColor Red
    }
}

function Get-ValidADUser {
    <#
    .SYNOPSIS
    Prompts for a username and returns a validated Active Directory user object.

    .DESCRIPTION
    Repeatedly prompts for a username via Read-Username and attempts to locate the corresponding user in
    Active Directory. Accepts two lookup strategies depeding on the format of the username:

    - 'firstname.lastname' or single-word usernames are looked up directly by identity using Get-ADUser -Identity.
    - 'firstname lastname' (space-separated) performs a display name filter search.
      If multiple accounts match, the user is prompted to refine their input.

    Continues prompting until exactly one matching account is found.

    .EXAMPLE
    $user = Get-ValidADUser
    # Prompts for a username and returns the matching ADUser object.

    .OUTPUTS
    Microsoft.ActiveDirectory.Management.ADUser. The resolved Active Directory user object.

    .NOTES
    Author: Alexander Christian
    #>
    while ($true) {
        $username = Read-Username

        if ($username -match '^[a-z]+\.[a-z]+$' -or $username -match '^[a-z]+$') {
            try {
                $userAccount = Get-ADUser -Identity $username -ErrorAction Stop
                return $userAccount
            }
            catch {
                Write-Host "No Active Directory user found with username '$username'." -ForegroundColor Red
                Write-Host 'Please try again.' -ForegroundColor Yellow
            }
        }

        if ($username -match '^[a-z]+ [a-z]+$') {

            $userAccount = Get-ADUser -Filter "Name -eq '$username'" -ErrorAction SilentlyContinue

            if ($null -eq $userAccount) {
                Write-Host "No Active Directory user found with name '$username'." -ForegroundColor Red
                Write-Host 'Please try again.' -ForegroundColor Yellow
                continue
            }

            if ($userAccount.Count -gt 1) {
                Write-Host "Multiple users found matching '$username':" -ForegroundColor Yellow
                $userAccount | Select-Object -ExpandProperty DisplayName | Sort-Object | ForEach-Object {
                    Write-Host " - $_" -ForegroundColor Cyan
                }
                Write-Host 'Please refine your input.' -ForegroundColor Yellow
                continue
            }

            return $userAccount
        }
    }
}
