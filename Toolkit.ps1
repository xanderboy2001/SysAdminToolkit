function Show-MainMenu {
    $quitOptions = @('Q', 'Quit', 'E', 'Exit')

    Write-Host '=== SysAdmin Toolkit ===' -ForegroundColor Cyan

    do {
        Write-Host 'Are you working on a Windows Server or Client?'
        Write-Host "Please enter the corresponding number to select the item. You may also enter $($quitOptions -join ', ') to quit the application."
        Write-Host '1. Server'
        Write-Host '2. Client'

        $userChoice = Read-Host -Prompt 'Please enter your choice'
        switch -Regex ($userChoice) {
            ($quitOptions -join '|') {
                if ($userChoice -in $quitOptions) {
                    Write-Host 'Exiting SysAdmin Toolkit...' -ForegroundColor Yellow
                }
                else {
                    Write-Host 'Invalid Input' -ForegroundColor Red
                }
            }
            '1' { Show-ServerMenu; return }
            '2' { Show-ClientMenu; return }
            default { Write-Host 'Invalid Input' -ForegroundColor Red }
        }
    } while ($userChoice -notin $quitOptions)
}

function Show-ServerMenu {
    Write-Host 'You have chosen server' -ForegroundColor Cyan
}

function Show-ClientMenu {

}

Show-MainMenu