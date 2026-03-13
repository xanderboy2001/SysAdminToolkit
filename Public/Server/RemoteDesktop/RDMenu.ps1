function Show-RDMenu {
    $menuOptions = @(
        'Reboot Connection Brokers',
        'Toggle New Connections on Server'
    )

    $result = Show-Menu -Title 'Remote Desktop Menu' -Options $menuOptions

    if ($result.Quit) {
        return 
    }
    if ($result.Back) {
        Show-ServerMenu 
    }

    switch ($result.Index) {
        0 {
            Restart-RDS-Brokers
        }
        1 {
            Set-RDSessionHostMode
        }
    }
}
