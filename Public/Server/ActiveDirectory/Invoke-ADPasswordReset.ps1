function Invoke-ADPasswordReset {
    <#
    .SYNOPSIS
    Resets the password for an Active Directory user account.

    .DESCRIPTION
    Prompts for an Active Directory user, asks for confirmation, then prompts twice for the new password and
    resets it. The password is read as a SecureString. The account is also unlocked after a successful reset, in
    case it was locked by failed sign-in attempts.

    Confirmation uses the standard PowerShell prompt (ConfirmImpact High). Use -Force to skip it, or -WhatIf to
    see which account would be changed.

    .PARAMETER Force
    Skips the confirmation prompt unless -Confirm is also specified.

    .EXAMPLE
    Invoke-ADPasswordReset
    # Prompts for a username, asks for confirmation, then resets the account password.

    .EXAMPLE
    Invoke-ADPasswordReset -WhatIf
    # Shows which account would be reset without changing it.

    .NOTES
    Author: Alexander Christian
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '',
        Justification = 'Interactive wizard; to be split into core command + UI. See issue #1 (F-21).')]
    param(
        [switch]$Force
    )
    process {
        if ($Force -and -not $PSBoundParameters.ContainsKey('Confirm')) {
            $ConfirmPreference = 'None'
        }
        Show-MenuHeader -Title 'Reset AD Account Password'
        Write-Host @'
This script takes an Active Directory account username as input and resets their password.
You will be asked to confirm before entering the new password.
The password will be read as a SecureString
'@ -ForegroundColor Yellow

        $userAccount = Get-ValidADUser
        $username = $userAccount.SamAccountName

        $msg = "Ensure you verify the user's identity via security questions or manager approval."
        Write-Host $msg -ForegroundColor Yellow
        if (-not $PSCmdlet.ShouldProcess($username, 'Reset AD account password')) {
            return
        }
        try {
            $newPassword = Read-Password
            Set-ADAccountPassword -Identity $username -Reset -NewPassword $newPassword -ErrorAction Stop
            Unlock-ADAccount -Identity $username -ErrorAction SilentlyContinue
            Write-Host "Password successfully reset for $username" -ForegroundColor Green
        } catch {
            Write-Error "Failed to reset password: $($_.Exception.Message)"
        }
    }
}
