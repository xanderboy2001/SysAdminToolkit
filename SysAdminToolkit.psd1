@{
    # Script module file associated with this manifest
    RootModule             = 'SysAdminToolkit.psm1'

    # Versioning
    ModuleVersion          = '0.0.1'
    CompatiblePSEditions   = @('Desktop', 'Core')

    # General Metadata
    GUID                   = 'eee1e706-1766-4fa3-bad2-12b00447d27a'
    Author                 = 'Alexander Christian'
    Description            = 'A SysAdmin Toolkit for managing server and client menus.'

    # Exports (handled by psm1 automatic exports)
    FunctionsToExport      = '*'
    CmdletsToExport        = '*'
    VariablesToExport      = '*'
    AliasesToExport        = '*'

    # Requirements
    PowerShellVersion      = '5.1'
    DotNetFrameworkVersion = '4.0'

    # Dependencies (if needed later)
    RequiredModules        = @()

    # File listings (optional)
    FileList               = @(
        'SysAdminToolkit.psm1'
    )

    # Private data
    PrivateData            = @{
        PSData = @{
            Tags         = @('SysAdmin', 'Toolkit', 'Menu', 'ActiveDirectory', 'Automation', 'Client', 'Server')
            LicenseUri   = 'https://github.com/xanderboy2001/SysAdminToolkit/blob/main/LICENSE.md'
            ProjectUri   = 'https://github.com/xanderboy2001/sysadmintoolkit'
            ReleaseNotes = 'Initial version.'
        }
    }
}