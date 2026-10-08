function Show-ReachabilityMenu {
    <#
    .SYNOPSIS
    Displays the Reachability menu for testing connectivity to devices.

    .DESCRIPTION
    Allows the user to choose between testing individual targets,
    device name ranges, or IP address ranges. Uses the core menu system.

    .EXAMPLE
    Show-ReachabilityMenu
    # Opens the reachability submenu.

    .NOTES
    Author: Alexander Christian
    #>
    [CmdletBinding()]
    param()

    $menuOptions = @(
        "Test list of computer names / IPs",
        "Test device naming range",
        "Test IP address range"
    )

    $result = Show-Menu -Title 'Reachability Menu' -Options $menuOptions

    if ($result.Quit) {
        return
    }

    if ($result.Back) {
        Show-ClientMenu
        return
    }

    switch ($result.Index) {
        0 {
            $rawTargets = Read-Host "Enter computer names or IPs (comma separated)"

            if ([string]::IsNullOrWhiteSpace($rawTargets)) {
                Write-Warning "No input provided"
                return
            }

            $targets = $rawTargets -split ','

            Write-Host "`nRunning test..." -ForegroundColor Cyan
            Test-ComputerReachability -ComputerName $targets | Format-Table

            Read-Host "Press Enter to continue"
        }

        1 {
            $start = Read-Host 'Enter starting name (e.g., PC-1200)'
            $end = Read-Host 'Enter ending name (e.g., PC-1250)'

            if (-not $start -or -not $end) {
                Write-Host 'Both values are required.' -ForegroundColor Yellow
                return
            }

            Write-Host "`nRunning test..." -ForegroundColor Cyan
            Test-ComputerReachability -StartName $start -EndName $end | Format-Table

            Read-Host "Press Enter to continue"
        }

        # --- IP range ---
        2 {
            $start = Read-Host 'Enter starting IP address'
            $end = Read-Host 'Enter ending IP address'

            if (-not $start -or -not $end) {
                Write-Host 'Both values are required.' -ForegroundColor Yellow
                return
            }

            Write-Host "`nRunning test..." -ForegroundColor Cyan
            Test-ComputerReachability -StartIPAddress $start -EndIPAddress $end | Format-Table

            Read-Host "Press Enter to continue"
        }
    }

    # Return to this menu after action
    Show-ReachabilityMenu
}
