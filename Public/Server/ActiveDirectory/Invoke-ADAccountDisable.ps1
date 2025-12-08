function Invoke-ADAccountDisable {
    Show-MenuHeader -Title 'Disable AD Account'
    Write-Host 'This script takes an Active Directory account username as input and disables the account.' -ForegroundColor Yellow

    $userAccount = Get-ValidADUser
    $username = $userAccount.SamAccountName

    try {
        Disable-ADAccount -Identity $username -ErrorAction Stop
        Write-Host "Disabled AD account for $username ($($userAccount.Name))"
    }
    catch {
        Write-Host "Failed to disable AD account for $username ($($userAccount.Name)): $($_.Exception.Message)" -ForegroundColor Red
    }
}