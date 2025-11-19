function Show-MenuOptions {
    param(
        [String[]]$Options
    )
    foreach ($option in $Options) {
        $option_index = $Options.IndexOf($option)
        $option_index++
        Write-Host "${option_index}. ${option}"
    }
}

function Show-MenuHeader {
    param(
        [String]$Title
    )

    Write-Host "=== $Title ===" -ForegroundColor Cyan
}

function Read-MenuSelection {
    param(
        [String[]]$Options,
        [String[]]$QuitOptions,
        [String[]]$BackOptions,
        [String]$Prompt = "Please enter the corresponding number to select the item.`nYou may also enter $($QuitOptions -join ', ') to quit the application."
    )

    if ($BackOptions) {
        $Prompt += "`nYou may also enter $($BackOptions -join ', ') to return to the main menu."
    }
    Write-Host $Prompt -ForegroundColor White
    $choice = Read-Host

    # Quit
    if ($choice -in $QuitOptions) {
        return @{ Quit = $true; Back = $false; Choice = $choice; Index = $null }
    }

    # Back
    if ($choice -in $BackOptions) {
        return @{ Quit = $false; Back = $true; Choice = $choice; Index = $null }
    }

    # Numeric menu choice
    if ($choice -match '^\d+$') {
        $i = [int]$choice
        if ($i -ge 1 -and $i -le $Options.Count) {
            return @{ Quit = $false; Back = $false; Choice = $choice; Index = $i - 1 }
        }
    }

    # Invalid input
    Write-Host 'Invalid input' -ForegroundColor Red
    return @{Quit = $false; Back = $false; Choice = $choice; Index = $null }
}

function Show-Menu {
    param(
        [String]$Title,
        [String[]]$Options,
        [String[]]$QuitOptions = @('Q', 'Quit', 'E', 'Exit', 'C', 'Cancel'),
        [String[]]$BackOptions = @('B', 'Back')
    )

    Show-MenuHeader -Title $Title
    Show-MenuOptions -Options $Options

    return Read-MenuSelection -Options $Options -QuitOptions $QuitOptions -BackOptions $BackOptions
}

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
        0 { Write-Host $menuOptions[0] }
        1 { Write-Host $menuOptions[1] }
        2 { Write-Host $menuOptions[2] }
    }
}

function Show-ClientMenu {
    Write-Host 'You have chosen client' -ForegroundColor Cyan
}

Show-MainMenu