function Get-ToolkitConfig {
    <#
    .SYNOPSIS
    Returns the current in-memory toolkit configuration hashtable.

    .DESCRIPTION
    Returns the $script:ToolkitConfig hashtable that was populated by Initialize-ToolkitConfig during module
    load. Other functions use this to read configuration values.

    .EXAMPLE
    $config = Get-ToolkitConfig
    $config.ADConnectServer
    # Returns the configured AD Connect server name.

    .OUTPUTS
    System.Collections.Hashtable. The current toolkit configuration.

    .NOTES
    Author: Alexander Christian
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()
    if ($null -eq $script:ToolkitConfig) {
        return $null
    }
    return $script:ToolkitConfig.Clone()
}
