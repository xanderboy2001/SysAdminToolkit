function Get-ValidADUser {
    <#
    .SYNOPSIS
    Prompts for a username and returns a validated Active Directory user object.

    .DESCRIPTION
    Repeatedly prompts for a username via Read-Username and attempts to locate the corresponding user in
    Active Directory. Accepts two lookup strategies depending on the format of the username:

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
    [CmdletBinding()]
    [OutputType([Microsoft.ActiveDirectory.Management.ADUser])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '',
        Justification = 'Interactive prompt; output is for the operator, not the pipeline.')]
    param()
    $adProperties = @("DisplayName", "adminCount")
    while ($true) {
        $username = Read-Username

        if ($username -match '^[a-z]+\.[a-z]+$' -or $username -match '^[a-z]+$') {
            try {
                $userAccount = Get-ADUser -Identity $username -Properties $adProperties -ErrorAction Stop
                Write-ProtectedAccountWarning -User $userAccount
                return $userAccount
            } catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
                Write-Warning "No Active Directory user found with username '$username'."
                Write-Host 'Please try again.' -ForegroundColor Yellow
            }
        }

        if ($username -match '^[a-z]+ [a-z]+$') {
            # Safe to interpolate only because Read-Username restricts this branch to '^[a-z]+ [a-z]+$'.
            # If that validation is ever loosened, escape single quotes before building the filter.

            $userAccount = @(Get-ADUser -Filter "Name -eq '$username'" -Properties $adProperties -ErrorAction Stop)

            if ($userAccount.Count -eq 0) {
                Write-Host "No Active Directory user found with name '$username'." -ForegroundColor Red
                Write-Host "Please try again." -ForegroundColor Yellow
                continue
            }

            if ($userAccount.Count -gt 1) {
                Write-Host "Multiple users found matching '$username':" -ForegroundColor Yellow
                $userAccount | Select-Object -ExpandProperty DisplayName | Sort-Object | ForEach-Object {
                    Write-Host " - $_" -ForegroundColor Cyan
                }
                Write-Host "Please refine your input." -ForegroundColor Yellow
                continue
            }

            Write-ProtectedAccountWarning -User $userAccount[0]
            return $userAccount[0]
        }
    }
}
