function Invoke-ADAccountUnlock {
    <#
    .SYNOPSIS
    Prompts for an Active Directory username and unlocks the account if it is locked.

    .DESCRIPTION
    This function guides the user through unlocking a locked Active Directory account.
    It prompts for a valid AD username, checks whether the account is locked, and if so,
    requests confirmation before performing the unlock. The function provides guidance
    to verify the user's identity prior to unlocking.

    .EXAMPLE
    Invoke-ADAccountUnlock
    # Prompts for an AD username, checks the account's lock status, and unlocks it if confirmed.

    .NOTES
    Author: Alexander Christian
    #>

    Show-MenuHeader -Title 'Unlock Active Directory Account'
    Write-Host @'
This script takes an Active Directory account username as input and checks if it is locked.
If locked, the script will prompt for confirmation before unlocking the account.
'@ -ForegroundColor Yellow

    $userAccount = Get-ValidADUser
    $username = $userAccount.SamAccountName

    $isLocked = (Get-ADUser -Identity $userAccount.SamAccountName -Properties 'LockedOut').LockedOut

    if ($isLocked) {
        Write-Host "$username is locked" -ForegroundColor Yellow
        Write-Host "Ensure you verify the user's identity via security questions or manager approval." -ForegroundColor Yellow
        $action = "Unlock AD account for $username"
        if (Confirm-UserChoice -Action $action) {
            Unlock-ADAccount -Identity $username
            Write-Host "$username has been unlocked" -ForegroundColor Green
        }
    }
    else {
        Write-Host "$username is not locked" -ForegroundColor Yellow
    }
}