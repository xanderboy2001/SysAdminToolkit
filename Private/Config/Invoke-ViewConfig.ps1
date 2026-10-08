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
