function Show-ConfigMenu {
    <#
    .SYNOPSIS
    Displays the Configuration menu in the SysAdmin Toolkit.

    .DESCRIPTION
    Shows a menu with options to view, edit, or reset the toolkit configuration. Handles user input and navigates
    to the appropriate function or returns to the main menu if a back command is entered.

    .EXAMPLE
    Show-ConfigMenu
    # Displays the Configuration menu and waits for the user to select an option.

    .NOTES
    Author: Alexander Christian
    #>
    [CmdletBinding()]
    param()
    $menuOptions = @(
        'View Config'
        'Edit Config'
        'Reset Config to Defaults'
    )

    $result = Show-Menu -Title 'Configuration' -Options $menuOptions

    if ($result.Quit) {
        return 
    }
    if ($result.Back) {
        Start-ToolkitMenu 
    }

    switch ($result.Index) {
        0 {
            Invoke-ViewConfig 
        }
        1 {
            Invoke-EditConfig 
        }
        2 {
            Invoke-ResetConfig 
        }
    }
}

function Invoke-ViewConfig {
    <#
    .SYNOPSIS
    Displays the current toolkit configuration values.

    .DESCRIPTION
    Reads the current configuration via Get-ToolkitConfig and prints all key-value pairs in aligned columns.
    Keys are padded to the length of the longest key for readability.

    .EXAMPLE
    Invoke-ViewConfig
    # Prints all current configuration key-value pairs.

    .NOTES
    Author: Alexander Christian
    #>
    [CmdletBinding()]
    param()
    Show-MenuHeader -Title 'Current Configuration'

    $config = Get-ToolkitConfig
    $maxKeyLength = ($config.Keys | Measure-Object -Maximum Length).Maximum

    foreach ($key in ($config.Keys | Sort-Object)) {
        $paddedKey = $key.PadRight($maxKeyLength)
        Write-Host "$paddedKey : $($config[$key])"
    }
    Show-ConfigMenu
}

function Invoke-EditConfig {
    <#
    .SYNOPSIS
    Interactively edits individual toolkit configuration values.

    .DESCRIPTION
    Presents all current configuration keys and their values as a selectable menu. After selecting a key,
    the user is prompted to enter a new value. Integer keys require a valid integer input. Changes are saved
    immediately via Save-ToolkitConfig.

    .EXAMPLE
    Invoke-EditConfig
    # Displays a menu of configuration keys and allows the user to update values one at a time.

    .NOTES
    Author: Alexander Christian
    #>
    [CmdletBinding()]
    param()
    do {
        $config = Get-ToolkitConfig
        $keys = [string[]]($config.Keys | Sort-Object)
        $options = $keys | ForEach-Object {
            $value = if ($config[$_] -eq '') {
                '(not set)' 
            }
            else {
                $config[$_] 
            }
            "$_ : $value"
        }

        $result = Show-Menu -Title 'Edit Configuration' -Options $options

        if ($result.Quit) {
            return 
        }
        if ($result.Back) {
            Show-ConfigMenu
            return
        }

        $key = $keys[$result.Index]
        $currentValue = $config[$key]
        $displayValue = if ($currentValue -eq '') {
            '(not set)' 
        }
        else {
            $currentValue 
        }

        $newValue = Read-Host "New value for '$key' (current: $displayValue, leave blank to cancel)"

        if ($newValue -eq '') {
            continue 
        }

        if ($currentValue -is [int]) {
            if ($newValue -match '^\d+$') {
                $config[$key] = [int]$newValue
            }
            else {
                Write-Host "'$key' requires an integer value." -ForegroundColor Red
                continue
            }
        }
        else {
            $config[$key] = $newValue
        }

        Save-ToolkitConfig -Config $config
        Write-Host "'$key' updated successfully." -ForegroundColor Green
    } while ($true)
}

function Invoke-ResetConfig {
    <#
    .SYNOPSIS
    Resets the toolkit configuration to its default values after user confirmation.

    .DESCRIPTION
    Prompts the user to confirm the reset action via Confirm-UserChoice. If confirmed, loads all default values
    from config.defaults.psd1 and overwrites the current configuration by calling Save-ToolkitConfig.

    .EXAMPLE
    Invoke-ResetConfig
    # Prompts for confirmation, then resets the toolkit configuration to defaults.

    .NOTES
    Author: Alexander Christian
    #>
    [CmdletBinding()]
    param()
    Show-MenuHeader -Title 'Reset Configuration to Defaults'

    if (Confirm-UserChoice -Action 'reset the configuration to defaults') {
        $defaults = @{}
        (Import-PowerShellDataFile -Path $script:DefaultConfigPath).GetEnumerator() |
            ForEach-Object { $defaults[$_.Key] = $_.Value }

        Save-ToolkitConfig -Config $defaults
        Write-Host "Configuration has been reset to defaults." -ForegroundColor Green
    }
}
