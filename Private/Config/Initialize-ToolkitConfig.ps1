function Initialize-ToolkitConfig {
    <#
    .SYNOPSIS
    Loads the machine-wide toolkit configuration, merging in default values for missing keys.

    .DESCRIPTION
    The configuration lives in one machine-wide file (by default C:\ProgramData\SysAdminToolkit\Config\config.psd1)
    shared by every administrator on the server. Because it controls which executable Stop-FileLock runs and
    which servers the toolkit reboots, it is only loaded when Test-ToolkitConfigTrust confirms that only
    administrators can change the folder and the file.

    - Folder missing, elevated session: the folder is created with administrator-only write access.
    - Folder missing, not elevated: defaults are used for this session; nothing is created.
    - Folder or file not protected: defaults are used for this session and saving is blocked.
    - File missing: defaults are used and saved (saving requires an elevated session).
    - File present: loaded; missing keys are filled from defaults and saved when possible.
    - File not a valid .psd1: defaults are used, the file is left untouched, and an error is thrown.

    In every case $script:ToolkitConfig is set, so commands never see a missing configuration.
    $script:ConfigWriteBlockedReason explains why Save-ToolkitConfig will refuse to write, or is $null.

    .NOTES
    Author: Alexander Christian
    Called once during module import in SysAdminToolkit.psm1
    #>
    [CmdletBinding()]
    param()

    $defaults = @{}
    (Import-PowerShellDataFile -LiteralPath $script:DefaultConfigPath -ErrorAction Stop).GetEnumerator() |
        ForEach-Object {
            $defaults[$_.Key] = $_.Value
        }

    # Fail safe: until a trusted file has been loaded, run on defaults and do not write anything.
    $Script:ToolkitConfig = $defaults.Clone()
    $Script:ConfigWriteBlockedReason = $null

    $configDir = Split-Path -Path $Script:ConfigPath -Parent
    if (-not (Test-Path -LiteralPath $configDir)) {
        if (-not (Test-AdministratorSession)) {
            $Script:ConfigWriteBlockedReason = "The configuration folder '$configDir' does not exist yet. " +
            "Import the module once from an elevated session (Run as administrator) to create it."
            Write-Warning "SysAdminToolkit: $Script:ConfigWriteBlockedReason Using default settings."
            return
        }
        Protect-ToolkitConfigDirectory -Path $configDir -Confirm:$false
    }

    $untrusted = foreach ($path in @($configDir, $Script:ConfigPath)) {
        if (Test-Path -LiteralPath $path) {
            $trust = Test-ToolkitConfigTrust -Path $path
            if (-not $trust.IsTrusted) {
                "'$path' ($($trust.Reasons -join '; '))"
            }
        }
    }
    if ($untrusted) {
        $Script:ConfigWriteBlockedReason = "Non-administrators can change the configuration: " +
        ($untrusted -join ', ') + ". See 'Securing the configuration' in README.md"
        Write-Warning "SysAdminToolkit: $Script:ConfigWriteBlockedReason The file was NOT loaded; using defaults."
        return
    }

    if (-not (Test-Path -LiteralPath $Script:ConfigPath)) {
        try {
            Save-ToolkitConfig -Config $defaults
        } catch {
            Write-Warning ("SysAdminToolkit: using default settings; they could not be saved: " +
                $_.Exception.Message)
        }
        return
    }

    try {
        $saved = Import-PowerShellDataFile -LiteralPath $Script:ConfigPath -ErrorAction Stop
    } catch {
        $errorParams = @{
            Message        = "The configuration file '$script:ConfigPath' is not a valid .psd1 file. " +
            "Fix it, or delete it to recreate it from defaults. Parser error: $($_.Exception.Message)"
            InnerException = $_.Exception
            ErrorId        = 'ConfigFileInvalid'
            Category       = 'InvalidData'
            TargetObject   = $script:ConfigPath
        }
        $PSCmdlet.ThrowTerminatingError((New-ToolkitErrorRecord @errorParams))
    }

    $existing = @{}
    $saved.GetEnumerator() | ForEach-Object { $existing[$_.Key] = $_.Value }
    $missingKeys = @($defaults.Keys | Where-Object { -not $existing.ContainsKey($_) } | Sort-Object)
    foreach ($key in $missingKeys) {
        $existing[$key] = $defaults[$key]
    }
    $Script:ToolkitConfig = $existing

    if ($missingKeys.Count -gt 0) {
        try {
            Save-ToolkitConfig -Config $existing
        } catch {
            # The new keys still work for this session; they are saved the next time an elevated session imports.
            Write-Warning ("SysAdminToolkit: new settings ($($missingKeys -join ', ')) use their defaults but " +
                "could not be saved: $($_.Exception.Message)")
        }
    }
}
