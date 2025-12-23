function Convert-UsernameFormat {
    param([String]$Username)

    $Username = $Username.ToLower()

    # If username is email address (contains '@' symbol), remove everything after the '@'
    if ($Username -like '*@*') {
        $Username = $Username -replace '@.*$', ''
    }

    return $Username
}

function Read-Username {
    while ($true) {
        $usernameInput = Read-Host -Prompt 'Enter the username of the user'
        $username = Convert-UsernameFormat -Username $usernameInput

        if ($username -match '^[a-z]+\.[a-z]+$' -or $username -match '^[a-z]+ [a-z]+$' -or $username -match '^[a-z]+$') {
            return $username
        }

        Write-Host "Invalid input must be in either format: '<first name>.<last name>', '<first name> <last name>', or <first name><last initial>" -ForegroundColor Red
    }
}

function Read-Password {

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