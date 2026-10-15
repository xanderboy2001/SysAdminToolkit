function Show-ADAccountUnlock {
    <#
    .SYNOPSIS
    Menu action: asks for a username and unlocks the account if it is locked.

    .DESCRIPTION
    Interactive wrapper around Invoke-ADAccountUnlock for the toolkit menu. Asks for the account with
    Get-ValidADUser (which also shows the resolved account and warns about protected accounts), reminds the
    operator to verify the caller's identity, then calls Invoke-ADAccountUnlock, which asks for confirmation.

    .NOTES
    Author: Alexander Christian
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '',
        Justification = 'Interactive prompt; output is for the operator, not the pipeline.')]
    param()

    Show-MenuHeader -Title 'Unlock Active Directory Account'
    Write-Host 'Enter a username. If the account is locked, you will be asked to confirm the unlock.' `
        -ForegroundColor Yellow

    $user = Get-ValidADUser
    $samAccountName = $user.SamAccountName

    $isLocked = (Get-ADUser -Identity $samAccountName -Properties 'LockedOut' -ErrorAction Stop).LockedOut
    if (-not $isLocked) {
        Write-Warning "$samAccountName is not locked."
        return
    }

    Write-Host "Ensure you verify the user's identity via security questions or manager approval." `
        -ForegroundColor Yellow

    # Get-ValidADUser has already shown the protected-account warning, so it is not repeated here.
    $result = Invoke-ADAccountUnlock -Identity $samAccountName -WarningAction SilentlyContinue
    if ($result -and $result.Result -eq 'Unlocked') {
        Write-Host "$samAccountName has been unlocked." -ForegroundColor Green
    }
}
