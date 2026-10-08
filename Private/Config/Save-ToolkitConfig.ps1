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
        [Parameter(Mandatory, HelpMessage = "The configuration hashtable to serialize and write to disk")]
        [hashtable]$Config
    )

    $builder = [System.Text.StringBuilder]::new()
    $null = $builder.AppendLine('@{')
    foreach ($key in ($Config.Keys | Sort-Object)) {
        if ($key -notmatch '^[A-Za-z_][A-Za-z0-9_]*$') {
            throw "Configuration key '$key' is not a valid bare .psd1 key."
        }
        $value = $Config[$key]
        if ($value -is [int]) {
            $null = $builder.AppendLine("    $key = $value")
        } else {
            $escaped = [System.Management.Automation.Language.CodeGeneration]::EscapeSingleQuotedStringContent(
                [string]$value
            )
            $null = $builder.AppendLine("    $key = '$escaped'")
        }
    }
    $null = $builder.Append("}")

    if ($PSCmdlet.ShouldProcess($script:ConfigPath, 'Write toolkit configuration')) {
        Set-Content -LiteralPath $script:ConfigPath -Value $builder.ToString() -Encoding utf8 -ErrorAction Stop
        $script:ToolkitConfig = $Config
    }
}
