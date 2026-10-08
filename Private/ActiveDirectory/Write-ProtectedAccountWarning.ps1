function Write-ProtectedAccountWarning {
    <#
    .SYNOPSIS
    Shows the resolved account and warns when it is an AD protected (adminCount = 1) account.

    .NOTES
    Author: Alexander Christian
    adminCount can remain 1 after an account leaves a protected group, so treat the warning as a prompt to
    double-check, not as an authoritative privilege check.
    #>
    param(
        [Parameter(Mandatory)]
        $User
    )

    Write-Host "Resolved account: $($User.DisplayName) <$($User.SamAccountName)>" -ForegroundColor Cyan
    Write-Host "  $($User.DistinguishedName)" -ForegroundColor DarkGray
    if ($User.adminCount -eq 1) {
        Write-Warning ("'$($User.SamAccountName)' is or was a member of a protected administrative group " +
            '(adminCount = 1). Confirm this is really the intended account.')
    }
}
