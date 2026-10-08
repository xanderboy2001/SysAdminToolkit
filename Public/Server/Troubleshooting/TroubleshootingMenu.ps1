function Show-TroubleshootingMenu {
    <#
    .SYNOPSIS
        Displays the Server Troubleshooting submenu in the SysAdmin Toolkit

    .DESCRIPTION
        Shows Server Troubleshooting-related options such as Query Server Disk Type. Handles user input and
        executes the corresponding action or returns to the Server menu if requested.

    .EXAMPLE
        Show-TroubleShootingMenu
        # Displays the Server Troubleshooting menu and waits for user selection.

    .NOTES
        Author: Alexander Christian
    #>
    [CmdletBinding()]
    param()
    $menuOptions = @(
        'Query Server Disk Type'
    )

    $result = Show-Menu -Title 'Server Troubleshooting Menu' -Options $menuOptions

    if ($result.Quit) {
        return
    }
    if ($result.Back) {
        Show-ServerMenu
        return
    }
    switch ($result.Index) {
        0 {
            # Get-ServerDiskType is referenced here but is not defined anywhere in the module yet.
            if (Get-Command -Name 'Get-ServerDiskType' -ErrorAction SilentlyContinue) {
                Get-ServerDiskType
            } else {
                Write-Warning "'Query Server Disk Type' is not implemented yet."
            }
        }
    }
}
