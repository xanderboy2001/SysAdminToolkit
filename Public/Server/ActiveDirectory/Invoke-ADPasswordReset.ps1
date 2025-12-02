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
        $prompt = 'New password'
        Set-ADAccountPassword -Identity $username -Reset -NewPassword (Read-Host -Prompt $prompt -AsSecureString)
        Write-Host "$username"
    }
}