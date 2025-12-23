function Invoke-ADPasswordReset {
    Show-MenuHeader -Title 'Reset AD Account Password'
    Write-Host @'
This script takes an Active Directory account username as input and resets their password.
The script will prompt for confirmation before prompting for a new password.
The password will be read as a SecureString
'@ -ForegroundColor Yellow

    $userAccount = Get-ValidADUser
    $username = $userAccount.SamAccountName

    Write-Host "Ensure you verify the user's identity via security questions or manager approval." -ForegroundColor Yellow
    $action = "Reset password for $username"
    if (Confirm-UserChoice -Action $action) {
        try {
            $newPassword = (Read-Password)
            Set-ADAccountPassword -Identity $username -Reset -NewPassword $newPassword -ErrorAction Stop
            Unlock-ADAccount -Identity $username -ErrorAction SilentlyContinue
            Write-Host "Password successfully reset for $username" -ForegroundColor Green
        }
        catch {
            Write-Host "Failed to reset password: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}