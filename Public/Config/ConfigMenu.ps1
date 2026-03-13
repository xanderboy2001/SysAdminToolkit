function Show-ConfigMenu {
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
    show-MenuHeader -Title 'Current Configuration'

    $config = Get-ToolkitConfig
    $maxKeyLength = ($config.Keys | Measure-Object -Maximum Length).Maximum

    foreach ($key in ($config.Keys | Sort-Object)) {
        $paddedKey = $key.PadRight($maxKeyLength)
        Write-Host "$paddedKey : $($config[$key])"
    }

    Write-Host "Enter Q, Quit, E, Exit, C, or Cancel to quit the application." -ForegroundColor Yellow
    Write-Host "Enter B, or Back to return to the previous menu." -ForegroundColor Yellow
    do {
        $result = Read-Host

        if ($result -match '^([Qq]|[Qq]uit|[Ee]|[Ee]xit|[Cc]|[Cc]ancel)$') {
            return
        }
        if ($result -match '^([Bb]|[Bb]ack)$') {
            Show-ConfigMenu
            return
        }
    } while ($true)
}

function Invoke-EditConfig {
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
    Show-MenuHeader -Title 'Reset Configuration to Defaults'

    if (Confirm-UserChoice -Action 'reset the configuration to defaults') {
        $defaults = @{}
        (Import-PowerShellDataFile -Path $script:DefaultConfigPath).GetEnumerator() |
            ForEach-Object { $defaults[$_.Key] = $_.Value }

        Save-ToolkitConfig -Config $defaults
        Write-Host "Configuration has been reset to defaults." -ForegroundColor Green
    }
}
