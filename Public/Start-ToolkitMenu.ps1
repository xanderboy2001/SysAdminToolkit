function Start-ToolkitMenu {
    <#
    .SYNOPSIS
    Displays the main menu for the SysAdmin Toolkit.

    .DESCRIPTION
    Shows the main menu with options for Server, Client, and Config menus. Back returns to the previous menu,
    Quit exits from any menu, and every menu is shown again after its action finishes. Menus are defined in
    Get-ToolkitMenu and run by Invoke-ToolkitMenu.

    .EXAMPLE
    Start-ToolkitMenu
    # Displays the main menu and waits for the user to select an option.

    .NOTES
    Author: Alexander Christian
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Start-ToolkitMenu only opens an interactive menu; it changes no system state.')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '',
        Justification = 'Interactive prompt; output is for the operator, not the pipeline.')]
    param()

    Invoke-ToolkitMenu -MenuName 'Main' -NoBackAtRoot
    Write-Host 'Exiting SysAdmin Toolkit...' -ForegroundColor Yellow
}
