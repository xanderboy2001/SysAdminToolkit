function Show-ReachabilityMenu {
    <#
    .SYNOPSIS
    Displays the Reachability menu for testing connectivity to devices.

    .DESCRIPTION
    Allows the user to choose between testing individual targets, device name ranges, or IP address ranges.
    The menu is shown again after each test. Back or Quit returns to the caller (or to the Client menu when
    opened from Start-ToolkitMenu).

    .EXAMPLE
    Show-ReachabilityMenu
    # Opens the reachability submenu.

    .NOTES
    Author: Alexander Christian
    #>
    [CmdletBinding()]
    param()

    Invoke-ToolkitMenu -MenuName 'Reachability'
}
