function Show-MainMenu {
    $menuOptions = @('Server', 'Client')

    # Write-Host '=== SysAdmin Toolkit ===' -ForegroundColor Cyan

    do {
        $result = Show-Menu -Title 'SysAdmin Toolkit' -Options $menuOptions -BackOptions @()
        if ($result.Quit) {
            Write-Host 'Exiting SysAdmin Toolkit...' -ForegroundColor Yellow
            return
        }

        switch ($result.Index) {
            0 { Show-ServerMenu; return }
            1 { Show-ClientMenu; return }
        }
    } while ($true)
}