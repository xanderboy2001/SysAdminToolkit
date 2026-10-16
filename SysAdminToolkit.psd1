@{
    # Script module file associated with this manifest
    RootModule           = 'SysAdminToolkit.psm1'

    # Versioning
    ModuleVersion        = '0.5.0'
    CompatiblePSEditions = @('Core')

    # General Metadata
    GUID                 = 'eee1e706-1766-4fa3-bad2-12b00447d27a'
    Author               = 'Alexander Christian'
    # One literal string: manifests are data files and cannot concatenate strings.
    Description          = 'Menu-driven toolkit for Active Directory, Entra Connect, RDS, and Windows clients.'

    # Exports
    FunctionsToExport    = @(
        'Start-ToolkitMenu'
        'Show-ReachabilityMenu'
        'Get-BatteryReport'
        'Open-PrinterWebInterface'
        'Stop-FileLock'
        'Test-ComputerReachability'
        'Get-ADDisabledUser'
        'Invoke-ADAccountDisable'
        'Invoke-ADAccountUnlock'
        'Invoke-ADPasswordReset'
        'Invoke-ADSync'
        'Get-RDConnectedUser'
        'Set-RDSessionHostMode'
        'Restart-RDSBroker'
    )
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @(
        'Get-ADDisabledUsers'
        'Get-RDConnectedUsers'
    )

    # Requirements
    PowerShellVersion    = '7.4'

    # Dependencies. The RemoteDesktop module is also needed for the RDS commands but is loaded on demand.
    RequiredModules      = @('ActiveDirectory')

    # Private data
    PrivateData          = @{
        PSData = @{
            Tags         = @(
                'SysAdmin', 'Toolkit', 'Menu', 'ActiveDirectory', 'RemoteDesktop', 'Automation', 'Windows'
            )
            LicenseUri   = 'https://github.com/xanderboy2001/SysAdminToolkit/blob/main/LICENSE.md'
            ProjectUri   = 'https://github.com/xanderboy2001/SysAdminToolkit'
            ReleaseNotes = 'See https://github.com/xanderboy2001/SysAdminToolkit/blob/main/CHANGELOG.md'
        }
    }
}
