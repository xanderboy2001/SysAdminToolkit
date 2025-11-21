function Show-ServerMenu {
    $menuOptions = @(
        'Active Directory'
        'Microsoft Graph'
        'Troubleshooting'
    )
    $result = Show-Menu -Title 'Server Menu' -Options $menuOptions

    if ($result.Quit) { return }
    if ($result.Back) { Show-MainMenu }

    switch ($result.Index) {
        0 { Show-ADMenu }
        1 { Write-Host 'Microsoft Graph menu not yet implemented' -ForegroundColor Cyan }
        2 { Write-Host 'Troubleshooting menu not yet implemented' -ForegroundColor Cyan }
    }
}