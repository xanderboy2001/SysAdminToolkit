@{
    # Script module or binary module file associated with this manifest
    RootModule        = 'SysAdminToolkit.psm1'

    # Version number of this module
    ModuleVersion     = '0.0.1'

    # ID used to uniquely identify this module
    GUID              = 'eee1e706-1766-4fa3-bad2-12b00447d27a'

    Author            = 'Alexander Christian'

    Description       = 'A SysAdmin Toolkit for managing server and client menus.'

    PowerShellVersion = '5.1'

    FunctionsToExport = @('Show-MainMenu')

    CmdletsToExport   = @()

    VariablesToExport = @()

    AliasesToExport   = @()

    RequiredModules   = @()

    FileList          = @()

    PrivateData       = @{
        PSData = @{
            Tags         = @('SysAdmin', 'Toolkit', 'Menu')
            LicenseUri   = 'https://github.com/xanderboy2001/SysAdminToolkit/blob/main/LICENSE.md'
            ProjectUri   = 'https://github.com/xanderboy2001/sysadmintoolkit'
            ReleaseNotes = 'Initial version.'
        }
    }
}