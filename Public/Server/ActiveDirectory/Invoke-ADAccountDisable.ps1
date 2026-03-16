function Invoke-ADAccountDisable {
    <#
    .SYNOPSIS
    Disables an Active Directory user account.
    
    .DESCRIPTION
    Prompts for a valid Active Directory username and disables the corresponding account.
    Uses Get-ValidADUser to resolve and validate the account before calling Disable-ADAccount.
    Displays a success or failure message depending on the outcome.

    .EXAMPLE
    Invoke-ADAccountDisable
    # Prompts for a username and disables the corresponding Active Directory account.

    .NOTES
    Author: Alexander Christian
    #>
    Show-MenuHeader -Title 'Disable AD Account'
    Write-Host 'This script takes an Active Directory account username as input and disables the account.' `
        -ForegroundColor Yellow

    $userAccount = Get-ValidADUser
    $username = $userAccount.SamAccountName

    try {
        Disable-ADAccount -Identity $username -ErrorAction Stop
        Write-Host "Disabled AD account for $username ($($userAccount.Name))"
    }
    catch {
        Write-Host "Failed to disable AD account for $username ($($userAccount.Name)): $($_.Exception.Message)" `
            -ForegroundColor Red
    }
}
