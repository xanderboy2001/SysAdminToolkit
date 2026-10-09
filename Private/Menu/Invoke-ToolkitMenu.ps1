function Invoke-ToolkitMenu {
    <#
    .SYNOPSIS
    Runs the interactive menu loop, starting at the named menu.

    .DESCRIPTION
    Navigation is a stack of menu names instead of functions calling each other, so:
    - Back returns to the previous menu (or leaves the loop when already at the starting menu).
    - Quit leaves the loop from any depth.
    - Invalid input shows the same menu again.
    - After an action finishes, the same menu is shown again.
    - An action that throws reports its error and the menu is shown again; the toolkit keeps running.
    The call stack never grows, however long the session.

    .PARAMETER MenuName
    The menu to start at (a key returned by Get-ToolkitMenu).

    .PARAMETER NoBackAtRoot
    Hides the Back option on the starting menu (used by the main menu).

    .NOTES
    Author: Alexander Christian
    Action output is sent to Out-Host so tables appear before the next prompt instead of after the loop.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$MenuName,

        [switch]$NoBackAtRoot
    )

    $menus = Get-ToolkitMenu
    if (-not $menus.ContainsKey($MenuName)) {
        throw "Unknown menu '$MenuName'."
    }

    $stack = [System.Collections.Generic.Stack[string]]::new()
    $stack.Push($MenuName)

    while ($stack.Count -gt 0) {
        $menu = $menus[$stack.Peek()]
        $labels = @($menu.Items | ForEach-Object { $_.Label })
        $backOptions = if ($stack.Count -eq 1 -and $NoBackAtRoot) { @() } else { @('B', 'Back') }

        $result = Show-Menu -Title $menu.Title -Options $labels -BackOptions $backOptions

        if ($result.Quit) {
            return
        }
        if ($result.Back) {
            $null = $stack.Pop()
            continue
        }
        if ($null -eq $result.Index) {
            # Read-MenuSelection already reported the invalid input.
            continue
        }

        $item = $menu.Items[$result.Index]
        if ($item.ContainsKey('Menu')) {
            if (-not $menus.ContainsKey($item.Menu)) {
                throw "Menu item '$($item.Label)' points to unknown menu '$($item.Menu)'."
            }
            $stack.Push($item.Menu)
            continue
        }

        try {
            & $item.Action | Out-Host
        } catch {
            # Report the failure and keep the toolkit running. WriteError honours the caller's -ErrorAction.
            $PSCmdlet.WriteError($_)
        }
    }
}
