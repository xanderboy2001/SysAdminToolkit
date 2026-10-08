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
            $value = if ([string]::IsNullOrEmpty([string]$config[$_])) {
                '(not set)'
            } else {
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
        $displayValue = if ([string]::IsNullOrEmpty([string]$currentValue)) {
            '(not set)'
        } else {
            $currentValue
        }

        $newValue = Read-Host "New value for '$key' (current: $displayValue, leave blank to cancel)"

        if ($newValue -eq '') {
            continue
        }

        if ($currentValue -is [int]) {
            if ($newValue -match '^\d+$') {
                $config[$key] = [int]$newValue
            } else {
                Write-Host "'$key' requires an integer value." -ForegroundColor Red
                continue
            }
        } else {
            $config[$key] = $newValue
        }

        try {
            Save-ToolkitConfig -Config $config
            Write-Host "'$key' updated successfully." -ForegroundColor Green
        } catch {
            Write-Error "Failed to save '$key': $($_.Exception.Message)"
        }
    } while ($true)
}
