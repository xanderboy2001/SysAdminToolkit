function Invoke-ADAccountUnlock {
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