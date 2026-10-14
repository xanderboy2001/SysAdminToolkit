function Invoke-ADAccountUnlock {
    <#
    .SYNOPSIS
    Prompts for an Active Directory username and unlocks the account if it is locked.

    .DESCRIPTION
    This function guides the user through unlocking a locked Active Directory account.
    It prompts for a valid AD username, checks whether the account is locked, and if so,
    asks for confirmation before performing the unlock. The function provides guidance
    to verify the user's identity prior to unlocking.

    Confirmation uses the standard PowerShell prompt (ConfirmImpact High). Use -Force to skip it, or -WhatIf to
    see which account would be unlocked.

    .PARAMETER Force
    Skips the confirmation prompt unless -Confirm is also specified.

    .EXAMPLE
    Invoke-ADAccountUnlock
    # Prompts for an AD username, checks the account's lock status, and unlocks it if confirmed.

    .EXAMPLE
    Invoke-ADAccountUnlock -Force
    # Unlocks the chosen account without asking for confirmation.

    .NOTES
    Author: Alexander Christian
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '',
        Justification = 'Interactive wizard; to be split into core command + UI. See issue #1 (F-21).')]
    param(
        [switch]$Force
    )

    if ($Force -and -not $PSBoundParameters.ContainsKey('Confirm')) {
        $ConfirmPreference = 'None'
    }

    Show-MenuHeader -Title 'Unlock Active Directory Account'
    Write-Host @'
This script takes an Active Directory account username as input and checks if it is locked.
If locked, the script will prompt for confirmation before unlocking the account.
'@ -ForegroundColor Yellow

    $userAccount = Get-ValidADUser
    $username = $userAccount.SamAccountName

    $isLocked = (Get-ADUser -Identity $userAccount.SamAccountName -Properties 'LockedOut').LockedOut

    if ($isLocked) {
        Write-Verbose "$username is locked"
        $msg = "Ensure you verify the user's identity via security questions or manager approval."
        Write-Host $msg -ForegroundColor Yellow
        if ($PSCmdlet.ShouldProcess($username, 'Unlock AD account')) {
            try {
                Unlock-ADAccount -Identity $username -ErrorAction Stop
                Write-Host "$username has been unlocked" -ForegroundColor Green
            } catch {
                Write-Error "Failed to unlock ${username}: $($_.Exception.Message)"
            }
        }
    } else {
        Write-Warning "$username is not locked"
    }
}
