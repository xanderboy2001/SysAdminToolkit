function Show-MenuOptions {
    param(
        [String[]]$Options
    )

    # Determine max width of option numbers (for padding)
    $maxIndexLength = ($Options.Count).ToString().Length

    # Determine max length of option text (optional, for nice spacing)
    $maxOptionLength = ($Options | Measure-Object -Maximum Length).Maximum

    for ($i = 0; $i -lt $Options.Count; $i++) {
        $IndexStr = ($i + 1).ToString().PadLeft($maxIndexLength)
        $optionStr = $Options[$i].PadRight($maxOptionLength)
        Write-Host "$IndexStr. $OptionStr" -ForegroundColor Green
    }
}

function Show-MenuHeader {
    param(
        [String]$Title,
        [int]$MenuWidth = 72 # default width; can be adjusted
    )

    # Ensure total width is at least the length of the title + padding
    if ($MenuWidth -lt ($Title.Length + 4)) {
        $MenuWidth = $Title.Length + 4
    }

    # Center the title
    $padding = ($MenuWidth - $Title.Length - 2) / 2
    $titleLine = '=' * [math]::Floor($padding) + " $Title " + '=' * [math]::Ceiling($padding)

    # Output
    Write-Host $titleLine -ForegroundColor Cyan
}

function Show-MenuInstructions {
    param(
        [String[]]$QuitOptions,
        [String[]]$BackOptions
    )

    Write-Host 'Please enter the corresponding number to select the item.' -ForegroundColor White

    if ($QuitOptions) {
        Write-Host "You may also enter $($QuitOptions -join ', ') to quit the application." -ForegroundColor Yellow
    }

    if ($BackOptions) {
        Write-Host "You may also enter $($BackOptions -join ', ') to return to the main menu." -ForegroundColor Yellow
    }
}

function Read-MenuSelection {
    param(
        [String[]]$Options,
        [String[]]$QuitOptions,
        [String[]]$BackOptions
    )

    Show-MenuInstructions -QuitOptions $QuitOptions -BackOptions $BackOptions
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