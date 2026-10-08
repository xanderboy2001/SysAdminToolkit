function Initialize-ToolkitConfig {
    <#
    .SYNOPSIS
    Initializes the toolkit configuration, merging defaults with any existing saved values.

    .DESCRIPTION
    Loads the default configuration from config.defaults.psd1. If a config.psd1 file already exists, it is loaded
    and any missing keys are backfilled with their default values. If no config.psd1 exists, the config directory
    is created if needed and the defaults are used as the initial configuration. The file is only written when it
    is new or keys were backfilled. The resulting configuration is saved to disk and stored in
    $script:ToolkitConfig.

    .EXAMPLE
    Initialize-ToolkitConfig
    # Called automatically during module import to setup $script:ToolkitConfig.

    .NOTES
    Author: Alexander Christian
    This function is called once during module load in SysAdminToolkit.psm1.
    #>
    [CmdletBinding()]
    param()
    $defaults = @{}
    (Import-PowerShellDataFile -LiteralPath $script:DefaultConfigPath -ErrorAction Stop).GetEnumerator() |
        ForEach-Object {
            $defaults[$_.Key] = $_.Value
        }

    $needsSave = $false
    if (Test-Path -LiteralPath $script:ConfigPath) {
        $existing = @{}
        try {
            $saved = Import-PowerShellDataFile -LiteralPath $script:ConfigPath -ErrorAction Stop
        } catch {
            throw "The configuration file '$script:ConfigPath' is not a valid .psd1 file. " +
            "Fix it, or delete it to recreate it from defaults. Parser error: $($_.Exception.Message)"
        }
        $saved.GetEnumerator() | ForEach-Object { $existing[$_.Key] = $_.Value }

        foreach ($key in $defaults.Keys) {
            if (-not $existing.ContainsKey($key)) {
                $existing[$key] = $defaults[$key]
                $needsSave = $true
            }
        }
        $script:ToolkitConfig = $existing
    } else {
        $configDir = Split-Path -Path $script:ConfigPath -Parent
        if (-not (Test-Path -LiteralPath $configDir)) {
            $null = New-Item -ItemType Directory -Path $configDir -ErrorAction Stop
        }
        $script:ToolkitConfig = $defaults
        $needsSave = $true
    }

    if ($needsSave) {
        Save-ToolkitConfig -Config $script:ToolkitConfig
    }
}
