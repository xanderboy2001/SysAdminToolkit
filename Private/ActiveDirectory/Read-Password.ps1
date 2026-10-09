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
    [CmdletBinding()]
    [OutputType([System.Security.SecureString])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '',
        Justification = 'Interactive prompt; output is for the operator, not the pipeline.')]
    param()
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
