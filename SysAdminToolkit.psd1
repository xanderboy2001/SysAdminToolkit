@{
    # Script module file associated with this manifest
    RootModule           = 'SysAdminToolkit.psm1'

    # Versioning
    ModuleVersion        = '0.1.0'
    CompatiblePSEditions = @('Core')

    # General Metadata
    GUID                 = 'eee1e706-1766-4fa3-bad2-12b00447d27a'
    Author               = 'Alexander Christian'
    Description          = 'A SysAdmin Toolkit for managing server and client menus.'

    # Exports
    FunctionsToExport    = @(
        'Start-ToolkitMenu'
        'Show-ReachabilityMenu'
        'Get-BatteryReport'
        'Open-PrinterWebInterface'
        'Stop-FileLock'
        'Test-ComputerReachability'
        'Get-ADDisabledUsers'
        'Invoke-ADAccountDisable'
        'Invoke-ADAccountUnlock'
        'Invoke-ADPasswordReset'
        'Invoke-ADSync'
        'Get-RDConnectedUsers'
        'Set-RDSessionHostMode'
        'Restart-RDSBroker'
    )
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()

    # Requirements
    PowerShellVersion    = '7.4'

    # Dependencies (if needed later)
    RequiredModules      = @('ActiveDirectory')

    # File listings (optional)
    FileList             = @(
        'SysAdminToolkit.psm1'
    )

    # Private data
    PrivateData          = @{
        PSData = @{
            Tags         = @('SysAdmin', 'Toolkit', 'Menu', 'ActiveDirectory', 'Automation', 'Client', 'Server')
            LicenseUri   = 'https://github.com/xanderboy2001/SysAdminToolkit/blob/main/LICENSE.md'
            ProjectUri   = 'https://github.com/xanderboy2001/sysadmintoolkit'
            ReleaseNotes = 'Initial version.'
        }
    }
}
