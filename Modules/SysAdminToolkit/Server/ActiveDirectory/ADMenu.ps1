function Show-ADMenu {
    $menuOptions = @(
        'Reset Password'
        'Unlock Account'
        'Disable User'
        'Create User'
    )

    $result = Show-Menu -Title 'Active Directory Menu' -Options $menuOptions

    if ($result.Quit) { return }
    if ($result.Back) { Show-ServerMenu }

    switch ($result.Index) {
        0 { Write-Host 'Reset Password (placeholder)' -ForegroundColor Cyan }
        1 { Write-Host 'Unlock Account (placeholder)' -ForegroundColor Cyan }
        2 { Write-Host 'Disable User (placeholder)' -ForegroundColor Cyan }
        3 { Write-Host 'Create-User (placeholder)' -ForegroundColor Cyan }
    }
}