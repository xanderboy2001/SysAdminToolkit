$script:ConfigPath = Join-Path $script:ModuleRoot 'Config' 'config.psd1'
$script:DefaultConfigPath = Join-Path $script:ModuleRoot 'Config' 'config.defaults.psd1'

function Initialize-ToolkitConfig {
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
    return $script:ToolkitConfig
}

function Save-ToolkitConfig {
    [CmdletBinding()]
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

    Set-Content -Path $script:ConfigPath -Value $lines -Encoding UTF8
    $script:ToolkitConfig = $Config
}
