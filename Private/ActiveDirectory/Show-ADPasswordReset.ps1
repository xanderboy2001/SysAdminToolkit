function Show-ADPasswordReset {
    <#
    .SYNOPSIS
    Menu action: asks for a username, options, and a new password, then resets the password.

    .DESCRIPTION
    Interactive wrapper around Invoke-ADPasswordReset for the toolkit menu:
    1. Asks for the account with Get-ValidADUser, which shows the resolved account and warns about protected
       accounts.
    2. Reminds the operator to verify the caller's identity.
    3. If the account is locked, asks whether to unlock it.
    4. Asks whether to require a password change at the next sign-in.
    5. Asks for the new password twice (Read-Password).
    6. Calls Invoke-ADPasswordReset, which asks for confirmation and lists what will change.

    .NOTES
    Author: Alexander Christian
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '',
        Justification = 'Interactive prompt; output is for the operator, not the pipeline.')]
    param()

    Show-MenuHeader -Title 'Reset AD Account Password'
    Write-Host 'Enter a username. You will be asked a few questions and for the new password before the reset.' `
        -ForegroundColor Yellow

    $user = Get-ValidADUser
    $samAccountName = $user.SamAccountName

    Write-Host "Ensure you verify the user's identity via security questions or manager approval." `
        -ForegroundColor Yellow

    $isLocked = [bool](Get-ADUser -Identity $samAccountName -Properties 'LockedOut' -ErrorAction Stop).LockedOut
    $unlock = $false
    if ($isLocked) {
        Write-Host "$samAccountName is locked out." -ForegroundColor Yellow
        $unlock = Read-YesNo -Question 'Unlock the account after the reset'
    }
    $changeAtLogon = Read-YesNo -Question 'Require the user to change the password at the next sign-in'

    $newPassword = Read-Password
    try {
        $resetParams = @{
            Identity              = $samAccountName
            NewPassword           = $newPassword
            Unlock                = $unlock
            ChangePasswordAtLogon = $changeAtLogon
            # Get-ValidADUser has already shown the protected-account warning.
            WarningAction         = 'SilentlyContinue'
        }
        $result = Invoke-ADPasswordReset @resetParams
    } finally {
        $newPassword.Dispose()
    }

    if (-not $result) {
        return
    }
    Write-Host "Password reset for $samAccountName." -ForegroundColor Green
    if ($result.ChangePasswordAtLogon) {
        Write-Host 'The user must change the password at the next sign-in.' -ForegroundColor Green
    }
    if ($result.Unlocked) {
        Write-Host 'The account was unlocked.' -ForegroundColor Green
    } elseif ($result.WasLocked) {
        Write-Warning "$samAccountName is still locked."
    }
}
