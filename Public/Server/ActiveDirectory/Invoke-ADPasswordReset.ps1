function Invoke-ADPasswordReset {
    <#
    .SYNOPSIS
    Resets the password for an Active Directory user account.

    .DESCRIPTION
    Prompts for a valid Active Directory username and resets the account password after confirmation.
    The new password is read as a SecureString via Read-Password to avoid storing credentials in plaintext.
    The account is also unlocked after a successful password reset in case it was locked due to failed attempts.

    .EXAMPLE
    Invoke-ADPasswordReset
    # Prompts for a username, requests confirmation, then resets the account password.
    
    .NOTES
    Author: Alexander Christian
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param()
    process {
        Show-MenuHeader -Title 'Reset AD Account Password'
        Write-Host @'
This script takes an Active Directory account username as input and resets their password.
The script will prompt for confirmation before prompting for a new password.
The password will be read as a SecureString
'@ -ForegroundColor Yellow

        $userAccount = Get-ValidADUser
        $username = $userAccount.SamAccountName

        $msg = "Ensure you verify the user's identity via security questions or manager approval."
        Write-Host $msg -ForegroundColor Yellow
        $action = "Reset password for $username"
        if (Confirm-UserChoice -Action $action) {
            try {
                if ($PSCmdlet.ShouldProcess($username, 'Reset AD account password')) {
                    $newPassword = (Read-Password)
                    Set-ADAccountPassword -Identity $username -Reset -NewPassword $newPassword -ErrorAction Stop
                    Unlock-ADAccount -Identity $username -ErrorAction SilentlyContinue
                    Write-Host "Password successfully reset for $username" -ForegroundColor Green
                }
            }
            catch {
                Write-Host "Failed to reset password: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }
}
