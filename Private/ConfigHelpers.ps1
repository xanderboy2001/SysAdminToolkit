$script:ConfigPath = Join-Path -Path "C:\ProgramData" -ChildPath "SysAdminToolkit\Config\config.psd1"
$script:DefaultConfigPath = Join-Path $script:ModuleRoot "Config\config.defaults.psd1"

function Initialize-ToolkitConfig {
    <#
    .SYNOPSIS
    Initializes the toolkit configuration, merging defaults with any existing saved values.

    .DESCRIPTION
    Loads the defualt configuration from config.defaults.psd1. If a config.psd1 file already exists, it is loaded
    and any missing keys are backfilled with their default values. If no config.psd1 exists, the config directory
    is created if needed and the defaults are used as the initial configuration. The resulting configuration is
    saved to disk and stored in $script:ToolkitConfig.

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
    (Import-PowerShellDataFile -Path $script:DefaultConfigPath).GetEnumerator() |
        ForEach-Object { $defaults[$_.Key] = $_.Value }

    if (Test-Path $script:ConfigPath) {
        $existing = @{}
        (Import-PowerShellDataFile -Path $script:ConfigPath).GetEnumerator() |
            ForEach-Object { $existing[$_.Key] = $_.Value }

        foreach ($key in $defaults.Keys) {
            if (-not $existing.ContainsKey($key)) {
                $existing[$key] = $defaults[$key]
            }
        }
        $script:ToolkitConfig = $existing
    }
    else {
        $configDir = Split-Path $script:ConfigPath
        if (-not (Test-Path $configDir)) {
            New-Item -ItemType Directory -Path $configDir | Out-Null
        }
        $script:ToolkitConfig = $defaults
    }

    Save-ToolkitConfig -Config $script:ToolkitConfig
}

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
    return $script:ToolkitConfig
}

function Save-ToolkitConfig {
    <#
    .SYNOPSIS
    Serializes and writes a configuration hashtable to the config.psd1 file.

    .DESCRIPTION
    Accepts a hashtable and writes it to the toolkit config file at $script:ConfigPath in PowerShell data file
    (.psd1) format. Integer values are written without quotes; all other variables are written as single-quoted
    strings with single quotes escaped. Keys are written in alphabetical order. Updates $script:ToolkitConfig to
    reflect the saved state.

    .PARAMETER Config
    The hashtable to serialize and save to disk.

    .EXAMPLE
    $config = Get-ToolkitConfig
    $config['ADConnectServer'] = 'adconnect02'
    Save-ToolkitConfig -Config $config
    # Updates the ADConnectServer value and writes the config to disk.

    .NOTES
    Author: Alexander Christian
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config
    )

    $lines = "@{`n"
    foreach ($key in ($Config.Keys | Sort-Object)) {
        $value = $Config[$key]
        if ($value -is [int]) {
            $lines += "`t$key = $value`n"
        }
        else {
            $escaped = ($value -as [string]) -replace "'", "''"
            $lines += "`t$key = '$escaped'`n"
        }
    }
    $lines += '}'
    
    if ($PSCmdlet.ShouldProcess($script:ConfigPath, 'Write toolkit configuration')) {
        Set-Content -Path $script:ConfigPath -Value $lines -Encoding UTF8
        $script:ToolkitConfig = $Config
    }
}
