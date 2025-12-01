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
        $usernameInput = Read-Host -Prompt 'Enter the username of the user whose Active Directory account you wish to unlock'
        $username = Convert-UsernameFormat -Username $usernameInput

        if ($username -match '^[a-z]+\.[a-z]+$' -or $username -match '^[a-z]+ [a-z]+$') {
            return $username
        }

        Write-Host "Invalid input must be in either format: 'first.last', 'first last'" -ForegroundColor Red
    }
}

function Get-ValidADUser {
    while ($true) {
        $username = Read-Username

        if ($username -match '^[a-z]+\.[a-z]+$') {
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