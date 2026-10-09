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
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '',
        Justification = 'Interactive prompt; output is for the operator, not the pipeline.')]
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
